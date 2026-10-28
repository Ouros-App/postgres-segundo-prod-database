#!/usr/bin/env python3
"""Sincroniza tabelas e metadados do banco de origem para o destino."""

import argparse
import os
from pathlib import Path
import re
import sys

import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values
from dotenv import load_dotenv


ROOT_DIR = Path(__file__).resolve().parents[1]
SOURCE_CONFIG = {}
TARGET_CONFIG = {}
FETCH_SIZE = 1000


def config_from_env(prefix):
    host = os.getenv(f"{prefix}_HOST", "").strip()
    port = os.getenv(f"{prefix}_PORT", "").strip()
    dbname = os.getenv(f"{prefix}_DB", "").strip()
    user = os.getenv(f"{prefix}_USER", "").strip()
    password = os.getenv(f"{prefix}_PASSWORD", "").strip()
    obrigatorios = {
        "host": host,
        "dbname": dbname,
        "user": user,
        "password": password,
    }
    faltantes = [f"{prefix}_{key.upper()}" for key, value in obrigatorios.items() if not value]
    if faltantes:
        raise ValueError("Variáveis ausentes no .env: " + ", ".join(faltantes))

    return {
        "host": host,
        "port": int(port or "5432"),
        "dbname": dbname,
        "user": user,
        "password": password,
    }


def validar_config(config, nome):
    campos = ("host", "dbname", "user", "password")
    if any(not config.get(campo) or config[campo].startswith(("HOST_", "BANCO_", "USUARIO_", "SENHA_")) for campo in campos):
        raise ValueError(f"Preencha as configurações do {nome} no início do arquivo.")


def ler_ddl(conn):
    """Lê a estrutura da origem e monta operações idempotentes para sincronizá-la."""
    preparacao = []
    comandos = []
    donos_sequencias = []
    tabelas_dados = []
    dependencias = []
    sequencias_dados = []

    with conn.cursor() as cur:
        cur.execute("""
            SELECT n.nspname, t.typname, e.enumlabel
            FROM pg_type t
            JOIN pg_namespace n ON n.oid = t.typnamespace
            JOIN pg_enum e ON e.enumtypid = t.oid
            WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
              AND n.nspname NOT LIKE 'pg_%'
            ORDER BY n.nspname, t.typname, e.enumsortorder
        """)
        enums = {}
        for schema, nome, valor in cur.fetchall():
            enums.setdefault((schema, nome), []).append(valor)

        cur.execute("""
            SELECT n.nspname, c.relname
            FROM pg_namespace n JOIN pg_class c ON c.relnamespace = n.oid
            WHERE c.relkind = 'r' AND NOT c.relispartition
              AND n.nspname NOT IN ('pg_catalog', 'information_schema')
              AND n.nspname NOT LIKE 'pg_%'
              AND c.relname <> 'backup_execution_log'
            ORDER BY n.nspname, c.relname
        """)
        tabelas = cur.fetchall()
        esquemas = sorted({schema for schema, _ in tabelas} | {schema for schema, _ in enums})
        preparacao.extend(sql.SQL("CREATE SCHEMA IF NOT EXISTS {}").format(sql.Identifier(schema)) for schema in esquemas)

        for (schema, nome), valores in enums.items():
            criar = sql.SQL("CREATE TYPE {}.{} AS ENUM ({})").format(
                sql.Identifier(schema), sql.Identifier(nome),
                sql.SQL(", ").join(sql.Literal(valor) for valor in valores),
            )
            preparacao.append(sql.SQL(
                "DO $block$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type t "
                "JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname={} "
                "AND t.typname={}) THEN EXECUTE {}; END IF; END $block$"
            ).format(sql.Literal(schema), sql.Literal(nome), sql.Literal(criar.as_string(conn))))
            for valor in valores:
                preparacao.append(sql.SQL("ALTER TYPE {}.{} ADD VALUE IF NOT EXISTS {}").format(
                    sql.Identifier(schema), sql.Identifier(nome), sql.Literal(valor),
                ))

        cur.execute("""
            SELECT ns.nspname, seq.relname, format_type(s.seqtypid, NULL),
                   s.seqstart, s.seqincrement, s.seqmin, s.seqmax,
                   s.seqcache, s.seqcycle, tn.nspname, tbl.relname, a.attname,
                   EXISTS (SELECT 1 FROM pg_depend d
                           WHERE d.classid='pg_class'::regclass AND d.objid=seq.oid AND d.deptype='i')
            FROM pg_class seq JOIN pg_namespace ns ON ns.oid=seq.relnamespace
            JOIN pg_sequence s ON s.seqrelid=seq.oid
            LEFT JOIN pg_depend own ON own.classid='pg_class'::regclass AND own.objid=seq.oid AND own.deptype IN ('a','i')
            LEFT JOIN pg_class tbl ON tbl.oid=own.refobjid
            LEFT JOIN pg_namespace tn ON tn.oid=tbl.relnamespace
            LEFT JOIN pg_attribute a ON a.attrelid=tbl.oid AND a.attnum=own.refobjsubid
            WHERE seq.relkind='S' AND ns.nspname NOT IN ('pg_catalog','information_schema')
              AND ns.nspname NOT LIKE 'pg_%'
              AND (tbl.relname IS NULL OR tbl.relname <> 'backup_execution_log')
            ORDER BY ns.nspname, seq.relname
        """)
        for row in cur.fetchall():
            schema, nome, tipo, inicio, incremento, minimo, maximo, cache, ciclo, ts, tabela, coluna, identity = row
            if ts and tabela and coluna:
                sequencias_dados.append((schema, nome, ts, tabela, coluna, incremento))
            if identity:
                continue
            ident = sql.SQL("{}.{}").format(sql.Identifier(schema), sql.Identifier(nome))
            comandos.append(sql.SQL(
                "CREATE SEQUENCE IF NOT EXISTS {} AS {} INCREMENT BY {} MINVALUE {} "
                "MAXVALUE {} START WITH {} CACHE {} {}"
            ).format(ident, sql.SQL(tipo), sql.Literal(incremento), sql.Literal(minimo),
                     sql.Literal(maximo), sql.Literal(inicio), sql.Literal(cache),
                     sql.SQL("CYCLE" if ciclo else "NO CYCLE")))
            comandos.append(sql.SQL(
                "ALTER SEQUENCE {} AS {} INCREMENT BY {} MINVALUE {} MAXVALUE {} CACHE {} {}"
            ).format(ident, sql.SQL(tipo), sql.Literal(incremento), sql.Literal(minimo),
                     sql.Literal(maximo), sql.Literal(cache), sql.SQL("CYCLE" if ciclo else "NO CYCLE")))
            if ts and tabela and coluna:
                donos_sequencias.append(sql.SQL("ALTER SEQUENCE {} OWNED BY {}.{}.{}").format(
                    ident, sql.Identifier(ts), sql.Identifier(tabela), sql.Identifier(coluna)))

        for schema, tabela in tabelas:
            cur.execute("""
                SELECT a.attname, format_type(a.atttypid,a.atttypmod),
                       pg_get_expr(d.adbin,d.adrelid), a.attnotnull, a.attidentity, a.attgenerated
                FROM pg_attribute a
                LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
                JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=%s AND c.relname=%s AND a.attnum>0 AND NOT a.attisdropped
                ORDER BY a.attnum
            """, (schema, tabela))
            colunas = cur.fetchall()
            cur.execute("""
                SELECT a.attname
                FROM pg_constraint c
                CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ordem)
                JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.attnum
                WHERE c.contype='p' AND c.conrelid=to_regclass(%s)
                ORDER BY k.ordem
            """, (sql.SQL("{}.{}").format(sql.Identifier(schema), sql.Identifier(tabela)).as_string(conn),))
            chave_primaria = [row[0] for row in cur.fetchall()]
            tabelas_dados.append({
                "schema": schema,
                "tabela": tabela,
                "colunas": [row[0] for row in colunas if not row[5]],
                "tipos": {row[0]: row[1] for row in colunas if not row[5]},
                "chave_primaria": chave_primaria,
                "identity_always": any(row[4] == "a" for row in colunas if not row[5]),
            })
            defs = []
            for nome_coluna, tipo, padrao, not_null, identity, generated in colunas:
                definicao = sql.SQL("{} {}").format(sql.Identifier(nome_coluna), sql.SQL(tipo))
                if identity:
                    definicao += sql.SQL(" GENERATED {} AS IDENTITY").format(sql.SQL("ALWAYS" if identity == "a" else "BY DEFAULT"))
                elif generated:
                    definicao += sql.SQL(" GENERATED ALWAYS AS ({}) STORED").format(sql.SQL(padrao))
                elif padrao is not None:
                    definicao += sql.SQL(" DEFAULT {}").format(sql.SQL(padrao))
                if not_null:
                    definicao += sql.SQL(" NOT NULL")
                defs.append(definicao)

            table_id = sql.SQL("{}.{}").format(sql.Identifier(schema), sql.Identifier(tabela))
            comandos.append(sql.SQL("CREATE TABLE IF NOT EXISTS {} ({})").format(table_id, sql.SQL(", ").join(defs)))
            for nome_coluna, tipo, padrao, not_null, identity, generated in colunas:
                col_id = sql.Identifier(nome_coluna)
                definicao = sql.SQL("{} {}").format(col_id, sql.SQL(tipo))
                if identity:
                    definicao += sql.SQL(" GENERATED {} AS IDENTITY").format(sql.SQL("ALWAYS" if identity == "a" else "BY DEFAULT"))
                elif generated:
                    definicao += sql.SQL(" GENERATED ALWAYS AS ({}) STORED").format(sql.SQL(padrao))
                elif padrao is not None:
                    definicao += sql.SQL(" DEFAULT {}").format(sql.SQL(padrao))
                if not_null:
                    definicao += sql.SQL(" NOT NULL")
                comandos.append(sql.SQL("ALTER TABLE {} ADD COLUMN IF NOT EXISTS {}").format(table_id, definicao))

                if not identity and not generated:
                    catalog_filter = sql.SQL(
                        "n.nspname={} AND t.relname={} AND a.attname={}"
                    ).format(sql.Literal(schema), sql.Literal(tabela), sql.Literal(nome_coluna))
                    alter_type = sql.SQL(
                        "ALTER TABLE {} ALTER COLUMN {} TYPE {} USING {}::{}"
                    ).format(table_id, col_id, sql.SQL(tipo), col_id, sql.SQL(tipo))
                    type_condition = sql.SQL(
                        "EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid "
                        "JOIN pg_namespace n ON n.oid=t.relnamespace WHERE " + catalog_filter.as_string(conn) +
                        " AND format_type(a.atttypid,a.atttypmod) IS DISTINCT FROM {})"
                    ).format(sql.Literal(tipo))
                    comandos.append(sql.SQL("DO $block$ BEGIN IF {} THEN EXECUTE {}; END IF; END $block$").format(
                        type_condition, sql.Literal(alter_type.as_string(conn))))

                    default_condition = sql.SQL(
                        "EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid "
                        "JOIN pg_namespace n ON n.oid=t.relnamespace LEFT JOIN pg_attrdef d "
                        "ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE " + catalog_filter.as_string(conn) +
                        " AND pg_get_expr(d.adbin,d.adrelid) IS DISTINCT FROM {})"
                    ).format(sql.Literal(padrao))
                    if padrao is None:
                        alter_default = sql.SQL("ALTER TABLE {} ALTER COLUMN {} DROP DEFAULT").format(table_id, col_id)
                    else:
                        alter_default = sql.SQL("ALTER TABLE {} ALTER COLUMN {} SET DEFAULT {}").format(table_id, col_id, sql.SQL(padrao))
                    comandos.append(sql.SQL("DO $block$ BEGIN IF {} THEN EXECUTE {}; END IF; END $block$").format(
                        default_condition, sql.Literal(alter_default.as_string(conn))))

                    null_condition = sql.SQL(
                        "EXISTS (SELECT 1 FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid "
                        "JOIN pg_namespace n ON n.oid=t.relnamespace WHERE " + catalog_filter.as_string(conn) +
                        " AND a.attnotnull IS DISTINCT FROM {})"
                    ).format(sql.Literal(not_null))
                    alter_null = sql.SQL("ALTER TABLE {} ALTER COLUMN {} {}").format(
                        table_id, col_id, sql.SQL("SET NOT NULL" if not_null else "DROP NOT NULL"))
                    comandos.append(sql.SQL("DO $block$ BEGIN IF {} THEN EXECUTE {}; END IF; END $block$").format(
                        null_condition, sql.Literal(alter_null.as_string(conn))))

        cur.execute("""
            SELECT n.nspname, t.relname, con.conname, pg_get_constraintdef(con.oid)
            FROM pg_constraint con JOIN pg_class t ON t.oid=con.conrelid
            JOIN pg_namespace n ON n.oid=t.relnamespace
            WHERE con.contype IN ('p','u','f','c','x')
              AND n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_%'
              AND t.relname <> 'backup_execution_log'
            ORDER BY CASE WHEN con.contype='f' THEN 1 ELSE 0 END, n.nspname, t.relname, con.conname
        """)
        for schema, tabela, nome, definicao in cur.fetchall():
            table_id = sql.SQL("{}.{}").format(sql.Identifier(schema), sql.Identifier(tabela))
            add = sql.SQL("ALTER TABLE {} ADD CONSTRAINT {} {}").format(table_id, sql.Identifier(nome), sql.SQL(definicao))
            comandos.append(sql.SQL(
                "DO $block$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint c "
                "JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace "
                "WHERE n.nspname={} AND t.relname={} AND c.conname={}) THEN {}; END IF; END $block$"
            ).format(sql.Literal(schema), sql.Literal(tabela), sql.Literal(nome), add))

        cur.execute("""
            SELECT pg_get_indexdef(i.indexrelid)
            FROM pg_index i JOIN pg_class t ON t.oid=i.indrelid
            JOIN pg_namespace n ON n.oid=t.relnamespace
            WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_%'
              AND t.relname <> 'backup_execution_log'
              AND NOT EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conindid=i.indexrelid)
            ORDER BY n.nspname, t.relname, i.indexrelid
        """)
        for (definicao,) in cur.fetchall():
            definicao = re.sub(r"^CREATE (UNIQUE )?INDEX\b", r"CREATE \1INDEX IF NOT EXISTS", definicao, count=1)
            comandos.append(sql.SQL(definicao))
        comandos.extend(donos_sequencias)

        cur.execute("""
            SELECT child_ns.nspname, child.relname, parent_ns.nspname, parent.relname
            FROM pg_constraint c
            JOIN pg_class child ON child.oid=c.conrelid
            JOIN pg_namespace child_ns ON child_ns.oid=child.relnamespace
            JOIN pg_class parent ON parent.oid=c.confrelid
            JOIN pg_namespace parent_ns ON parent_ns.oid=parent.relnamespace
            WHERE c.contype='f'
              AND child_ns.nspname NOT IN ('pg_catalog','information_schema')
              AND child_ns.nspname NOT LIKE 'pg_%'
              AND parent_ns.nspname NOT IN ('pg_catalog','information_schema')
              AND parent_ns.nspname NOT LIKE 'pg_%'
              AND child.relname <> 'backup_execution_log'
              AND parent.relname <> 'backup_execution_log'
        """)
        dependencias = cur.fetchall()

    return preparacao, comandos, tabelas_dados, dependencias, sequencias_dados


def ordenar_tabelas(tabelas, dependencias):
    """Ordena tabelas referenciadas antes das tabelas que dependem delas."""
    por_nome = {(t["schema"], t["tabela"]): t for t in tabelas}
    requisitos = {nome: set() for nome in por_nome}
    for fs, filho, ps, pai in dependencias:
        filho_nome, pai_nome = (fs, filho), (ps, pai)
        if filho_nome == pai_nome:
            raise RuntimeError(f"Auto-referência em {fs}.{filho}; carga não aplicada.")
        if filho_nome in requisitos and pai_nome in por_nome:
            requisitos[filho_nome].add(pai_nome)
    ordem = []
    while requisitos:
        prontos = sorted(nome for nome, pais in requisitos.items() if not pais)
        if not prontos:
            nomes = ", ".join(f"{s}.{t}" for s, t in sorted(requisitos))
            raise RuntimeError(f"Ciclo de foreign keys entre {nomes}; carga não aplicada.")
        for nome in prontos:
            ordem.append(por_nome[nome])
            del requisitos[nome]
        for pais in requisitos.values():
            pais.difference_update(prontos)
    return ordem


def iniciar_backup():
    """Cria o histórico no destino e registra o início desta execução."""
    with psycopg2.connect(**TARGET_CONFIG) as conn:
        with conn.cursor() as cur:
            ddl_path = ROOT_DIR / "sql" / "backup_execution_log.sql"
            cur.execute(ddl_path.read_text(encoding="utf-8"))
            cur.execute(
                "INSERT INTO public.backup_execution_log "
                "(source_database, target_database, status) "
                "VALUES (%s, %s, 'running') RETURNING backup_id",
                (SOURCE_CONFIG["dbname"], TARGET_CONFIG["dbname"]),
            )
            return cur.fetchone()[0]


def registrar_falha(backup_id, error):
    """Persiste falhas após a transação de dados ser revertida."""
    with psycopg2.connect(**TARGET_CONFIG) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE public.backup_execution_log SET status='failed', "
                "finished_at=CURRENT_TIMESTAMP, error_message=%s "
                "WHERE backup_id=%s AND status='running'",
                (str(error)[:4000], backup_id),
            )


def copiar_dados(source_conn, tabelas, sequencias, backup_id):
    """Faz upsert por PK e sincroniza logs sem PK por comparação de linhas."""
    linhas_lidas = 0
    tabelas_processadas = 0
    with psycopg2.connect(**TARGET_CONFIG) as target_conn:
        with target_conn.cursor() as target_cur:
            for indice, tabela in enumerate(tabelas):
                colunas = tabela["colunas"]
                if not colunas:
                    continue
                tabelas_processadas += 1
                schema_id = sql.Identifier(tabela["schema"])
                tabela_id = sql.Identifier(tabela["tabela"])
                colunas_id = sql.SQL(", ").join(map(sql.Identifier, colunas))
                select_sql = sql.SQL("SELECT {} FROM {}.{}").format(colunas_id, schema_id, tabela_id)
                if tabela["chave_primaria"]:
                    chaves_id = sql.SQL(", ").join(map(sql.Identifier, tabela["chave_primaria"]))
                    atualizacoes = [c for c in colunas if c not in tabela["chave_primaria"]]
                    acao = (sql.SQL("DO UPDATE SET {} ").format(sql.SQL(", ").join(
                        sql.SQL("{} = EXCLUDED.{}").format(sql.Identifier(c), sql.Identifier(c)) for c in atualizacoes
                    )) if atualizacoes else sql.SQL("DO NOTHING "))
                    override = sql.SQL("OVERRIDING SYSTEM VALUE ") if tabela["identity_always"] else sql.SQL("")
                    insert_sql = sql.SQL(
                        "INSERT INTO {}.{} ({}) {}VALUES %s ON CONFLICT ({}) {}"
                    ).format(schema_id, tabela_id, colunas_id, override, chaves_id, acao).as_string(target_conn)
                    template = None
                else:
                    igualdade = sql.SQL(" AND ").join(
                        sql.SQL("dest.{} IS NOT DISTINCT FROM incoming.{}").format(sql.Identifier(c), sql.Identifier(c))
                        for c in colunas
                    )
                    insert_sql = sql.SQL(
                        "WITH incoming ({}) AS (VALUES %s), numbered AS ("
                        "SELECT *, row_number() OVER (PARTITION BY {}) AS occurrence FROM incoming) "
                        "INSERT INTO {}.{} ({}) SELECT {} FROM numbered incoming "
                        "WHERE incoming.occurrence > (SELECT count(*) FROM {}.{} dest WHERE {})"
                    ).format(
                        colunas_id, colunas_id, schema_id, tabela_id, colunas_id, colunas_id,
                        schema_id, tabela_id, igualdade,
                    ).as_string(target_conn)
                    template = "(" + ", ".join("%s::" + tabela["tipos"][c] for c in colunas) + ")"
                with source_conn.cursor(name=f"full_load_{indice}") as source_cur:
                    source_cur.itersize = FETCH_SIZE
                    source_cur.execute(select_sql)
                    while True:
                        rows = source_cur.fetchmany(FETCH_SIZE)
                        if not rows:
                            break
                        linhas_lidas += len(rows)
                        execute_values(target_cur, insert_sql, rows, template=template, page_size=min(FETCH_SIZE, 500))

            # Avança sequences sem retroceder o contador existente no destino.
            with source_conn.cursor() as source_cur:
                for seq_schema, seq_nome, tabela_schema, tabela, coluna, incremento in sequencias:
                    seq_id = sql.SQL("{}.{}").format(sql.Identifier(seq_schema), sql.Identifier(seq_nome))
                    table_id = sql.SQL("{}.{}").format(sql.Identifier(tabela_schema), sql.Identifier(tabela))
                    source_cur.execute(sql.SQL("SELECT last_value, is_called FROM {}").format(seq_id))
                    source_value, source_called = source_cur.fetchone()
                    table_ref = table_id.as_string(target_conn)
                    target_cur.execute("SELECT pg_get_serial_sequence(%s, %s)", (table_ref, coluna))
                    target_seq_name = target_cur.fetchone()[0]
                    if target_seq_name is None:
                        continue
                    target_cur.execute("SELECT to_regclass(%s)", (target_seq_name,))
                    target_seq = target_cur.fetchone()[0]
                    target_cur.execute("SELECT last_value, is_called FROM " + target_seq)
                    target_value, target_called = target_cur.fetchone()
                    target_cur.execute(sql.SQL("SELECT max({}) FROM {}").format(sql.Identifier(coluna), table_id))
                    max_value = target_cur.fetchone()[0]
                    valores = [max_value] if max_value is not None else []
                    if source_called:
                        valores.append(source_value)
                    if target_called:
                        valores.append(target_value)
                    if valores:
                        valor = max(valores) if incremento > 0 else min(valores)
                        target_cur.execute("SELECT setval(%s::regclass, %s, true)", (target_seq_name, valor))

            target_cur.execute(
                "UPDATE public.backup_execution_log SET status='success', "
                "finished_at=CURRENT_TIMESTAMP, rows_read=%s, tables_processed=%s "
                "WHERE backup_id=%s AND status='running'",
                (linhas_lidas, tabelas_processadas, backup_id),
            )


def copiar_estrutura(preparacao, comandos):
    """Aplica tipos primeiro e sincroniza as tabelas em uma transação."""
    with psycopg2.connect(**TARGET_CONFIG) as conn:
        with conn.cursor() as cur:
            for comando in preparacao:
                cur.execute(comando)
    with psycopg2.connect(**TARGET_CONFIG) as conn:
        with conn.cursor() as cur:
            cur.execute("SET LOCAL lock_timeout = '10s'")
            cur.execute("SET LOCAL statement_timeout = '5min'")
            for comando in comandos:
                cur.execute(comando)


def main():
    global SOURCE_CONFIG, TARGET_CONFIG, FETCH_SIZE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--confirmar-destino", action="store_true", help="Confirma o banco de destino.")
    args = parser.parse_args()
    backup_id = None
    try:
        load_dotenv(ROOT_DIR / ".env")
        SOURCE_CONFIG = config_from_env("BACKUP_SOURCE")
        TARGET_CONFIG = config_from_env("BACKUP_TARGET")
        FETCH_SIZE = int(os.getenv("BACKUP_FETCH_SIZE", "1000"))
        if FETCH_SIZE < 1:
            raise ValueError("BACKUP_FETCH_SIZE deve ser maior que zero.")
        validar_config(SOURCE_CONFIG, "banco de origem")
        validar_config(TARGET_CONFIG, "banco de destino")
        origem = (SOURCE_CONFIG["host"], SOURCE_CONFIG["port"], SOURCE_CONFIG["dbname"])
        destino = (TARGET_CONFIG["host"], TARGET_CONFIG["port"], TARGET_CONFIG["dbname"])
        if origem == destino:
            raise ValueError("Origem e destino apontam para o mesmo banco.")
        if not args.confirmar_destino:
            parser.error("Confirme o destino com --confirmar-destino antes de sincronizar estrutura e dados.")

        backup_id = iniciar_backup()
        with psycopg2.connect(**SOURCE_CONFIG) as conn:
            conn.set_session(readonly=True)
            preparacao, comandos, tabelas, dependencias, sequencias = ler_ddl(conn)
            if not comandos:
                raise RuntimeError("Nenhuma tabela foi encontrada no banco de origem.")
            ordem = ordenar_tabelas(tabelas, dependencias)
            copiar_estrutura(preparacao, comandos)
            copiar_dados(conn, ordem, sequencias, backup_id)
        print(f"Execução {backup_id}: estrutura e dados sincronizados.")
        return 0
    except (OSError, ValueError, RuntimeError, psycopg2.Error) as exc:
        if backup_id is not None:
            try:
                registrar_falha(backup_id, exc)
            except (OSError, psycopg2.Error) as log_error:
                print(f"Não foi possível registrar a falha no destino: {log_error}", file=sys.stderr)
        print(f"Erro ao sincronizar estrutura e dados: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
