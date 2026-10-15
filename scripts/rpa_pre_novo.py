#!/usr/bin/env python3
"""Migrate selected legacy PostgreSQL data into the current Ouros schema."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Callable, Iterator, Mapping, Sequence

import psycopg2
from dotenv import load_dotenv
from psycopg2 import sql
from psycopg2.extras import RealDictCursor


SOURCE_COLUMNS: dict[str, tuple[str, ...]] = {
    "endereco_empresa": ("id", "cep", "numero", "municipio", "estado", "pais", "logradouro", "id_empresa"),
    "endereco_granja": ("id", "cep", "numero", "municipio", "estado", "pais", "logradouro", "id_granja"),
    "endereco_proprietario": ("id", "cep", "numero", "municipio", "estado", "pais", "logradouro", "id_proprietario"),
    "empresa": ("id", "nome", "email_corporativo", "cnpj", "telefone_corporativo"),
    "granja": ("id", "nome", "regiao", "area_propriedade", "id_empresa"),
    "lote": ("id", "galinhas_recebidas", "galinhas_entregadas", "dt_entrega", "id_granja"),
    "funcionario": ("id", "nome", "cpf", "email", "senha", "id_empresa"),
    "telefone_funcionario": ("id", "id_funcionario", "telefone"),
    "dica": ("id", "titulo", "id_granja"),
    "avaliacao": ("id", "comentario", "nota", "id_dica"),
    "meta": ("id", "is_individual", "titulo", "descricao", "status", "valor_alvo", "tipo_meta", "id_granja", "regiao"),
    "proprietario_granja": ("id", "nome", "cpf", "senha", "email", "id_granja"),
    "telefone_proprietario": ("id", "id_proprietario", "telefone"),
    "registro_agua": ("id", "dt_registro", "hidrometro_inicio", "hidrometro_final", "id_lote"),
    "registro_energia": ("id", "dt_registro", "consumo", "id_lote"),
}

TARGET_COLUMNS: dict[str, tuple[str, ...]] = {
    "addresses": ("id", "zip_code", "state", "city", "number", "country"),
    "enterprises": ("id", "name", "email", "document_number", "telephone", "id_address"),
    "farms": ("id", "name", "area_property", "region", "chickens_now", "id_address", "id_enterprise"),
    "company_employees": ("id", "name", "document_number", "email", "telephone", "password", "id_enterprise"),
    "farm_owners": ("id", "name", "document_number", "password", "email", "telephone", "first_access", "foto_url", "id_farm"),
    "tips": ("id", "tip"),
    "farms_tips": ("id", "id_farm", "id_tip"),
    "reviews": ("id", "comment", "rating", "id_tip"),
    "lots": ("id", "received_chickens", "delivered_chickens", "delivery_date", "losts", "cost", "id_enterprise", "id_farm"),
    "water_registries": ("id", "registration_date", "start_hydrometer", "end_hydrometer", "id_farm"),
    "energy_registries": ("id", "registration_date", "energy_consumption", "id_farm"),
    "individual_goals": ("id", "description", "type", "status", "target_value", "title", "id_farm"),
    "state_goals": ("id", "description", "type", "target_value", "title"),
    "farm_goals": ("id", "id_farm", "id_goal", "status"),
    "regions_goals": ("id", "region", "id_goal"),
    "state_goal_regions": ("id", "id_goal", "id_region"),
}

MAP_TABLE = "rpa_migration_id_map"
TARGET_TABLES = frozenset(TARGET_COLUMNS)
ADDRESS_SOURCES = (
    ("endereco_empresa", "id_empresa"),
    ("endereco_granja", "id_granja"),
    ("endereco_proprietario", "id_proprietario"),
)
REPORT_DETAIL_LIMIT = 10000


class RPAError(RuntimeError):
    """Raised when execution cannot safely continue."""


class PendingData(ValueError):
    """A source row that needs correction or a human decision."""

    def __init__(self, reason: str, target_table: str | None = None) -> None:
        super().__init__(reason)
        self.reason = reason
        self.target_table = target_table


@dataclass(frozen=True)
class DatabaseConfig:
    host: str
    port: int
    database: str
    user: str
    password: str
    schema: str = "public"

    @classmethod
    def from_env(cls, prefix: str, schema_name: str) -> "DatabaseConfig":
        required = ("HOST", "DB", "USER", "PASSWORD")
        values = {key: os.getenv(f"{prefix}_{key}") for key in required}
        missing = [f"{prefix}_{key}" for key, value in values.items() if not value]
        if missing:
            raise RPAError(f"Variáveis de conexão ausentes: {', '.join(missing)}")
        try:
            port = int(os.getenv(f"{prefix}_PORT", "5432"))
        except ValueError as exc:
            raise RPAError(f"{prefix}_PORT precisa ser um inteiro") from exc
        schema = os.getenv(schema_name, "public")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", schema):
            raise RPAError(f"Nome de schema inválido em {schema_name}")
        return cls(
            host=str(values["HOST"]),
            port=port,
            database=str(values["DB"]),
            user=str(values["USER"]),
            password=str(values["PASSWORD"]),
            schema=schema,
        )

    def connect(self, application_name: str) -> psycopg2.extensions.connection:
        return psycopg2.connect(
            host=self.host,
            port=self.port,
            dbname=self.database,
            user=self.user,
            password=self.password,
            application_name=application_name,
            connect_timeout=15,
        )


@dataclass
class MapEntry:
    target_id: int | None
    status: str
    reason: str | None = None


@dataclass
class MigrationReport:
    mode: str
    source_system: str
    source_database: str
    target_database: str
    started_at: datetime

    def __post_init__(self) -> None:
        self.counts: Counter[tuple[str, str, str]] = Counter()
        self.pending: list[dict[str, Any]] = []
        self.pending_truncated = False
        self.notes: list[str] = []
        self.finished_at: datetime | None = None

    def add(
        self,
        status: str,
        source_table: str,
        source_id: int | None,
        target_table: str,
        reason: str | None = None,
        sqlstate: str | None = None,
        constraint: str | None = None,
    ) -> None:
        self.counts[(status, source_table, target_table)] += 1
        if status != "pending":
            return
        if len(self.pending) >= REPORT_DETAIL_LIMIT:
            self.pending_truncated = True
            return
        item: dict[str, Any] = {
            "source_table": source_table,
            "source_id": source_id,
            "target_table": target_table,
            "reason": reason or "pending_review",
        }
        if sqlstate:
            item["sqlstate"] = sqlstate
        if constraint:
            item["constraint"] = constraint
        self.pending.append(item)

    def finish(self) -> None:
        self.finished_at = datetime.now(timezone.utc)

    def as_dict(self) -> dict[str, Any]:
        totals: Counter[str] = Counter()
        by_table: dict[str, dict[str, int]] = defaultdict(dict)
        for (status, source_table, target_table), count in self.counts.items():
            totals[status] += count
            key = f"{source_table} -> {target_table}"
            by_table[key][status] = count
        return {
            "mode": self.mode,
            "source_system": self.source_system,
            "source_database": self.source_database,
            "target_database": self.target_database,
            "started_at": self.started_at.isoformat(),
            "finished_at": self.finished_at.isoformat() if self.finished_at else None,
            "totals": dict(totals),
            "by_table": dict(by_table),
            "pending_count": totals.get("pending", 0),
            "pending_details": self.pending,
            "pending_details_truncated": self.pending_truncated,
            "notes": self.notes,
        }


def normalize_key(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", text.strip().casefold())


STATE_CODES = {
    "acre": "AC", "alagoas": "AL", "amapa": "AP", "amazonas": "AM",
    "bahia": "BA", "ceara": "CE", "distrito federal": "DF", "espirito santo": "ES",
    "goias": "GO", "maranhao": "MA", "mato grosso": "MT", "mato grosso do sul": "MS",
    "minas gerais": "MG", "para": "PA", "paraiba": "PB", "parana": "PR",
    "pernambuco": "PE", "piaui": "PI", "rio de janeiro": "RJ",
    "rio grande do norte": "RN", "rio grande do sul": "RS", "rondonia": "RO",
    "roraima": "RR", "santa catarina": "SC", "sao paulo": "SP", "sergipe": "SE",
    "tocantins": "TO",
}
VALID_STATE_CODES = frozenset(STATE_CODES.values())
COUNTRY_CODES = {
    "brasil": "BR", "brazil": "BR", "br": "BR", "bra": "BR",
    "estados unidos": "US", "estados unidos da america": "US", "united states": "US",
    "united states of america": "US", "usa": "US", "eua": "US", "us": "US",
    "portugal": "PT", "pt": "PT", "prt": "PT",
    "argentina": "AR", "ar": "AR", "arg": "AR",
    "uruguai": "UY", "uruguay": "UY", "uy": "UY",
    "paraguai": "PY", "paraguay": "PY", "py": "PY",
    "chile": "CL", "cl": "CL", "colombia": "CO", "co": "CO",
    "mexico": "MX", "mx": "MX", "espanha": "ES", "spain": "ES", "es": "ES",
    "italia": "IT", "italy": "IT", "it": "IT", "franca": "FR", "france": "FR", "fr": "FR",
    "alemanha": "DE", "germany": "DE", "de": "DE", "canada": "CA", "ca": "CA",
    "japao": "JP", "japan": "JP", "jp": "JP",
}
GOAL_STATUSES = {
    "nao iniciada": "Pendente",
    "em andamento": "Em andamento",
    "finalizada": "Concluída",
    "pendente": "Pendente",
    "concluida": "Concluída",
}


def state_code(value: Any) -> str:
    if value is None:
        raise PendingData("missing_state")
    normalized = normalize_key(value)
    code = normalized.upper()
    if code in VALID_STATE_CODES:
        return code
    if normalized in STATE_CODES:
        return STATE_CODES[normalized]
    for separator in ("/", "-", ","):
        if separator in normalized:
            for token in (part.strip() for part in normalized.split(separator)):
                if token in STATE_CODES:
                    return STATE_CODES[token]
                if re.fullmatch(r"[a-z]{2}", token):
                    return token.upper()
    raise PendingData("unsupported_state")


def country_code(value: Any) -> str:
    if value is None:
        return "BR"
    normalized = normalize_key(value)
    if not normalized:
        return "BR"
    code = normalized.upper()
    if re.fullmatch(r"[A-Z]{2}", code):
        return code
    if normalized in COUNTRY_CODES:
        return COUNTRY_CODES[normalized]
    raise PendingData("unsupported_country")


def goal_status(value: Any) -> str:
    if value is None:
        raise PendingData("missing_goal_status")
    normalized = normalize_key(value).replace("_", " ")
    if normalized in GOAL_STATUSES:
        return GOAL_STATUSES[normalized]
    raise PendingData("unknown_goal_status")


def timestamp_value(value: Any) -> datetime:
    if value is None:
        raise PendingData("missing_registration_date")
    if isinstance(value, datetime):
        if value.tzinfo is not None and value.utcoffset() is not None:
            raise PendingData("source_timestamp_has_timezone")
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min)
    raise PendingData("invalid_registration_date")


def text_value(value: Any) -> str | None:
    if value is None:
        return None
    return value if isinstance(value, str) else str(value)


def digits_only_value(value: Any) -> str | None:
    text = text_value(value)
    if text is None:
        return None
    digits = re.sub(r"\D", "", text)
    return digits or text


def positive_numeric_value(value: Any) -> Decimal:
    if value is None:
        raise PendingData("missing_goal_target_value")
    try:
        number = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError) as exc:
        raise PendingData("invalid_goal_target_value") from exc
    if not number.is_finite():
        raise PendingData("invalid_goal_target_value")
    if number <= 0:
        raise PendingData("non_positive_goal_target_value")
    return number


def json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return str(value)


def qualified(schema_name: str, table_name: str) -> sql.Composed:
    return sql.SQL("{}.{}").format(sql.Identifier(schema_name), sql.Identifier(table_name))


def stream_query(
    connection: psycopg2.extensions.connection,
    query: sql.Composable,
    params: Sequence[Any] | None = None,
    fetch_size: int = 1000,
) -> Iterator[dict[str, Any]]:
    cursor_name = f"rpa_{uuid.uuid4().hex}"
    cursor = connection.cursor(name=cursor_name, cursor_factory=RealDictCursor)
    cursor.itersize = fetch_size
    try:
        cursor.execute(query, params or ())
        while True:
            rows = cursor.fetchmany(fetch_size)
            if not rows:
                break
            for row in rows:
                yield dict(row)
    finally:
        cursor.close()


def source_table_query(
    schema_name: str,
    table_name: str,
    columns: Sequence[str] | None = None,
    order_by: str | None = "id",
) -> sql.Composed:
    if columns is None:
        projection: sql.Composable = sql.SQL("*")
    else:
        projection = sql.SQL(", ").join(sql.Identifier(column) for column in columns)
    query = sql.SQL("SELECT {} FROM {}").format(projection, qualified(schema_name, table_name))
    if order_by:
        query += sql.SQL(" ORDER BY {}").format(sql.Identifier(order_by))
    return query


def validate_source_schema(
    connection: psycopg2.extensions.connection,
    schema_name: str,
) -> list[str]:
    issues: list[str] = []
    with connection.cursor() as cursor:
        for table_name, required_columns in SOURCE_COLUMNS.items():
            cursor.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_schema = %s AND table_name = %s",
                (schema_name, table_name),
            )
            present = {row[0] for row in cursor.fetchall()}
            if not present:
                issues.append(f"Tabela de origem ausente: {schema_name}.{table_name}")
                continue
            missing = sorted(set(required_columns) - present)
            if missing:
                issues.append(
                    f"Colunas ausentes em {schema_name}.{table_name}: {', '.join(missing)}"
                )
    return issues


def validate_target_schema(
    connection: psycopg2.extensions.connection,
    schema_name: str,
) -> dict[str, Any]:
    issues: list[str] = []
    columns: dict[str, dict[str, tuple[str, str]]] = defaultdict(dict)
    column_defaults: dict[str, dict[str, Any]] = defaultdict(dict)
    with connection.cursor() as cursor:
        for table_name, required_columns in TARGET_COLUMNS.items():
            cursor.execute(
                "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns "
                "WHERE table_schema = %s AND table_name = %s",
                (schema_name, table_name),
            )
            for column_name, data_type, is_nullable, column_default in cursor.fetchall():
                columns[table_name][column_name] = (data_type, is_nullable)
                column_defaults[table_name][column_name] = column_default
            if not columns.get(table_name):
                issues.append(f"Tabela de destino ausente: {schema_name}.{table_name}")
                continue
            missing = sorted(set(required_columns) - set(columns[table_name]))
            if missing:
                issues.append(
                    f"Colunas ausentes em {schema_name}.{table_name}: {', '.join(missing)}"
                )
            elif column_defaults[table_name].get("id") is None:
                issues.append(f"Migration/schema incompatível: {schema_name}.{table_name}.id precisa gerar IDs automaticamente")

        for table_name, column_name in (("lots", "delivery_date"), ("company_employees", "telephone")):
            actual = columns.get(table_name, {}).get(column_name)
            if actual and actual[1] != "YES":
                issues.append(f"Migration pendente: {schema_name}.{table_name}.{column_name} ainda é NOT NULL")

        for table_name in ("water_registries", "energy_registries"):
            actual = columns.get(table_name, {}).get("registration_date")
            if actual and actual[0] != "timestamp without time zone":
                issues.append(
                    f"Migration pendente: {schema_name}.{table_name}.registration_date "
                    f"está como {actual[0]}, esperado TIMESTAMP"
                )

        for table_name, index_name, expected_index_columns in (
            (
                "water_registries",
                "water_registries_import_natural_key",
                ("id_farm", "registration_date", "start_hydrometer", "end_hydrometer"),
            ),
            (
                "energy_registries",
                "energy_registries_import_natural_key",
                ("id_farm", "registration_date", "energy_consumption"),
            ),
        ):
            cursor.execute(
                "SELECT ix.indisunique, array_agg(a.attname ORDER BY k.ordinality) "
                "FROM pg_class idx JOIN pg_index ix ON ix.indexrelid = idx.oid "
                "CROSS JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY AS k(attnum, ordinality) "
                "JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = k.attnum "
                "WHERE idx.oid = to_regclass(%s) GROUP BY ix.indisunique",
                (f"{schema_name}.{index_name}",),
            )
            index_definition = cursor.fetchone()
            if not index_definition:
                issues.append(f"Índice necessário ausente: {schema_name}.{index_name}")
            elif not index_definition[0] or tuple(index_definition[1]) != expected_index_columns:
                issues.append(
                    f"Índice incompatível: {schema_name}.{index_name} precisa ser UNIQUE "
                    f"em {', '.join(expected_index_columns)}"
                )

        cursor.execute("SELECT to_regclass(%s)", (f"public.{MAP_TABLE}",))
        map_table_exists = cursor.fetchone()[0] is not None
        cursor.execute("SELECT has_schema_privilege(current_user, 'public', 'USAGE')")
        public_usage = bool(cursor.fetchone()[0])
        if not public_usage:
            issues.append("Permissão USAGE ausente no schema public")

        if map_table_exists:
            cursor.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_schema = 'public' AND table_name = %s",
                (MAP_TABLE,),
            )
            map_columns = {row[0] for row in cursor.fetchall()}
            required_map_columns = {
                "source_system", "source_table", "source_id", "target_table",
                "target_id", "status", "reason", "created_at", "updated_at",
            }
            if required_map_columns - map_columns:
                issues.append(
                    "Tabela de mapa incompatível; colunas ausentes: "
                    + ", ".join(sorted(required_map_columns - map_columns))
                )
            else:
                cursor.execute(
                    "SELECT array_agg(a.attname ORDER BY k.ordinality) "
                    "FROM pg_constraint c "
                    "CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ordinality) "
                    "JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum "
                    "WHERE c.conrelid = to_regclass(%s) AND c.contype = 'p' GROUP BY c.oid",
                    (f"public.{MAP_TABLE}",),
                )
                primary_key = [tuple(row[0]) for row in cursor.fetchall()]
                expected_primary_key = (
                    "source_system", "source_table", "source_id", "target_table"
                )
                if expected_primary_key not in primary_key:
                    issues.append(
                        "Tabela de mapa incompatível: chave primária precisa ser "
                        "(source_system, source_table, source_id, target_table)"
                    )
        cursor.execute("SELECT current_database()")
        target_database = cursor.fetchone()[0]
        cursor.execute(
            "SELECT c.relname, t.tgname "
            "FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid "
            "JOIN pg_namespace n ON n.oid = c.relnamespace "
            "WHERE n.nspname = %s AND NOT t.tgisinternal AND (t.tgtype & 4) = 4 "
            "AND c.relname = ANY(%s) ORDER BY c.relname, t.tgname",
            (schema_name, ["addresses", "enterprises", "farms", "company_employees", "farm_owners",
                           "tips", "farms_tips", "reviews", "lots", "water_registries",
                           "energy_registries", "individual_goals", "state_goals",
                           "regions_goals", "state_goal_regions"]),
        )
        insert_triggers = [tuple(row) for row in cursor.fetchall()]

        cursor.execute("SELECT has_schema_privilege(current_user, %s, 'USAGE')", (schema_name,))
        if not cursor.fetchone()[0]:
            issues.append(f"Permissão USAGE ausente no schema de destino {schema_name}")
        for table_name in TARGET_COLUMNS:
            if not columns.get(table_name):
                continue
            for privilege in ("SELECT", "INSERT"):
                cursor.execute(
                    "SELECT has_table_privilege(current_user, to_regclass(%s), %s)",
                    (f"{schema_name}.{table_name}", privilege),
                )
                if not cursor.fetchone()[0]:
                    issues.append(
                        f"Permissão {privilege} ausente em {schema_name}.{table_name}"
                    )
            cursor.execute(
                "SELECT pg_get_serial_sequence(%s, 'id')",
                (f"{schema_name}.{table_name}",),
            )
            sequence_name = cursor.fetchone()[0]
            if sequence_name:
                cursor.execute(
                    "SELECT has_sequence_privilege(current_user, %s, 'USAGE')",
                    (sequence_name,),
                )
                if not cursor.fetchone()[0]:
                    issues.append(f"Permissão USAGE ausente na sequence {sequence_name}")

        if map_table_exists:
            for privilege in ("SELECT", "INSERT", "UPDATE"):
                cursor.execute(
                    "SELECT has_table_privilege(current_user, to_regclass(%s), %s)",
                    (f"public.{MAP_TABLE}", privilege),
                )
                if not cursor.fetchone()[0]:
                    issues.append(f"Permissão {privilege} ausente em public.{MAP_TABLE}")
        else:
            cursor.execute("SELECT has_schema_privilege(current_user, 'public', 'CREATE')")
            public_create = cursor.fetchone()[0]
            if not public_create:
                issues.append(
                    f"Tabela public.{MAP_TABLE} não existe e falta permissão CREATE no schema public"
                )

    known_simulation_triggers = {
        ("farms", "farms_trigger_log"),
        ("lots", "lots_trigger_log"),
    }
    unsafe_simulation_triggers = [
        item for item in insert_triggers if item not in known_simulation_triggers
    ]
    return {
        "database": target_database,
        "issues": issues,
        "id_map_table_exists": map_table_exists,
        "insert_triggers": insert_triggers,
        "unsafe_simulation_triggers": unsafe_simulation_triggers,
        "ready": not issues,
    }


def count_source_rows(
    connection: psycopg2.extensions.connection,
    schema_name: str,
) -> dict[str, int]:
    result: dict[str, int] = {}
    with connection.cursor() as cursor:
        for table_name in SOURCE_COLUMNS:
            cursor.execute(
                sql.SQL("SELECT COUNT(*) FROM {}").format(qualified(schema_name, table_name))
            )
            result[table_name] = int(cursor.fetchone()[0])
    return result


def address_ambiguities(
    connection: psycopg2.extensions.connection,
    schema_name: str,
) -> dict[str, int]:
    result: dict[str, int] = {}
    with connection.cursor() as cursor:
        for table_name, relation_column in ADDRESS_SOURCES[:2]:
            cursor.execute(
                sql.SQL(
                    "SELECT COUNT(*) FROM (SELECT {} FROM {} "
                    "WHERE {} IS NOT NULL GROUP BY {} HAVING COUNT(*) > 1) ambiguous"
                ).format(
                    sql.Identifier(relation_column),
                    qualified(schema_name, table_name),
                    sql.Identifier(relation_column),
                    sql.Identifier(relation_column),
                )
            )
            result[table_name] = int(cursor.fetchone()[0])
    return result


def duplicate_resource_ids(
    connection: psycopg2.extensions.connection,
    schema_name: str,
    resource_table: str,
) -> set[int]:
    if resource_table == "registro_agua":
        key_names = ("dt_registro", "hidrometro_inicio", "hidrometro_final")
    elif resource_table == "registro_energia":
        key_names = ("dt_registro", "consumo")
    else:
        raise ValueError(f"Tabela de recurso desconhecida: {resource_table}")

    source_resource = qualified(schema_name, resource_table)
    source_lot = qualified(schema_name, "lote")
    selected_keys = [sql.Identifier(name) for name in key_names]
    duplicate_keys = sql.SQL(
        "SELECT l2.id_granja, {keys} FROM {resource} r2 "
        "JOIN {lot} l2 ON l2.id = r2.id_lote "
        "GROUP BY l2.id_granja, {keys} HAVING COUNT(*) > 1"
    ).format(
        keys=sql.SQL(", ").join(sql.SQL("r2.{}").format(column) for column in selected_keys),
        resource=source_resource,
        lot=source_lot,
    )
    join_conditions = [
        sql.SQL("l.id_granja IS NOT DISTINCT FROM d.id_granja")
    ]
    join_conditions.extend(
        sql.SQL("r.{} IS NOT DISTINCT FROM d.{}").format(column, column)
        for column in selected_keys
    )
    query = sql.SQL(
        "WITH duplicate_keys AS ({duplicate_keys}) "
        "SELECT r.id FROM {resource} r "
        "JOIN {lot} l ON l.id = r.id_lote "
        "JOIN duplicate_keys d ON {conditions} ORDER BY r.id"
    ).format(
        duplicate_keys=duplicate_keys,
        resource=source_resource,
        lot=source_lot,
        conditions=sql.SQL(" AND ").join(join_conditions),
    )
    with connection.cursor() as cursor:
        cursor.execute(query)
        return {int(row[0]) for row in cursor.fetchall()}


class IdAllocator:
    """Allocate temporary negative IDs during simulation without advancing SERIALs."""

    def __init__(self, connection: psycopg2.extensions.connection, schema_name: str) -> None:
        self.connection = connection
        self.schema_name = schema_name
        self.next_ids: dict[str, int] = {}

    def next(self, table_name: str) -> int:
        if table_name not in TARGET_TABLES:
            raise RPAError(f"Tabela de destino não permitida: {table_name}")
        if table_name not in self.next_ids:
            with self.connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL("SELECT MIN(id) FROM {}").format(
                        qualified(self.schema_name, table_name)
                    )
                )
                lowest = cursor.fetchone()[0]
            candidate = -1 if lowest is None or int(lowest) >= 0 else int(lowest) - 1
            if candidate < -(2**31):
                raise RPAError(f"Sem IDs temporários disponíveis para simular {table_name}")
            self.next_ids[table_name] = candidate
        result = self.next_ids[table_name]
        self.next_ids[table_name] -= 1
        return result


class TargetStore:
    def __init__(
        self,
        connection: psycopg2.extensions.connection,
        schema_name: str,
        source_system: str,
        simulate: bool,
    ) -> None:
        self.connection = connection
        self.schema_name = schema_name
        self.source_system = source_system
        self.simulate = simulate
        self.maps: dict[tuple[str, int, str], MapEntry] = {}
        self.allocator = IdAllocator(connection, schema_name) if simulate else None

    @staticmethod
    def key(source_table: str, source_id: int, target_table: str) -> tuple[str, int, str]:
        return source_table, int(source_id), target_table

    def map_table_exists(self) -> bool:
        with self.connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass(%s)", (f"public.{MAP_TABLE}",))
            return cursor.fetchone()[0] is not None

    def lock_migration(self) -> None:
        """Serialize RPA runs so two processes cannot create duplicate target rows."""
        with self.connection.cursor() as cursor:
            cursor.execute(
                "SELECT pg_advisory_xact_lock(hashtext(%s), hashtext(%s))",
                ("rpa-pre-novo", "destination-migration"),
            )

    def ensure_map_table(self) -> None:
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "CREATE TABLE IF NOT EXISTS public.{} ("
                    "source_system TEXT NOT NULL, "
                    "source_table TEXT NOT NULL, "
                    "source_id BIGINT NOT NULL, "
                    "target_table TEXT NOT NULL, "
                    "target_id BIGINT, "
                    "status TEXT NOT NULL CHECK (status IN ('loaded', 'pending')), "
                    "reason TEXT, "
                    "created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(), "
                    "updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(), "
                    "PRIMARY KEY (source_system, source_table, source_id, target_table), "
                    "CHECK ((status = 'loaded' AND target_id IS NOT NULL AND reason IS NULL) "
                    "OR (status = 'pending' AND target_id IS NULL))"
                    ")"
                ).format(sql.Identifier(MAP_TABLE))
            )

    def load_maps(self) -> None:
        if not self.map_table_exists():
            return
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "SELECT source_table, source_id, target_table, target_id, status, reason "
                    "FROM public.{} WHERE source_system = %s"
                ).format(sql.Identifier(MAP_TABLE)),
                (self.source_system,),
            )
            for source_table, source_id, target_table, target_id, status, reason in cursor.fetchall():
                self.maps[(source_table, int(source_id), target_table)] = MapEntry(
                    int(target_id) if target_id is not None else None,
                    status,
                    reason,
                )

    def target_row_exists(self, table_name: str, target_id: int) -> bool:
        if table_name not in TARGET_TABLES:
            raise RPAError(f"Tabela de destino não permitida no mapa: {table_name}")
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT EXISTS (SELECT 1 FROM {} WHERE id = %s)").format(
                    qualified(self.schema_name, table_name)
                ),
                (target_id,),
            )
            return bool(cursor.fetchone()[0])

    def mapped_id(self, source_table: str, source_id: Any, target_table: str) -> int:
        if source_id is None:
            raise PendingData("missing_source_relation")
        key = self.key(source_table, int(source_id), target_table)
        entry = self.maps.get(key)
        if entry is None or entry.status != "loaded" or entry.target_id is None:
            raise PendingData(f"dependency_not_migrated:{source_table}")
        if not self.target_row_exists(target_table, entry.target_id):
            raise PendingData(f"mapped_target_missing:{target_table}")
        return entry.target_id

    def insert(self, table_name: str, values: Mapping[str, Any]) -> int:
        if table_name not in TARGET_TABLES:
            raise RPAError(f"Tabela de destino não permitida: {table_name}")
        invalid_columns = set(values) - set(TARGET_COLUMNS[table_name])
        if invalid_columns:
            raise RPAError(f"Colunas não permitidas em {table_name}: {sorted(invalid_columns)}")
        insert_values = dict(values)
        if self.simulate:
            assert self.allocator is not None
            insert_values = {"id": self.allocator.next(table_name), **insert_values}
        columns = list(insert_values)
        placeholders = sql.SQL(", ").join(sql.Placeholder() for _ in columns)
        query = sql.SQL("INSERT INTO {} ({}) VALUES ({}) RETURNING id").format(
            qualified(self.schema_name, table_name),
            sql.SQL(", ").join(sql.Identifier(column) for column in columns),
            placeholders,
        )
        with self.connection.cursor() as cursor:
            cursor.execute(query, tuple(insert_values[column] for column in columns))
            return int(cursor.fetchone()[0])

    def insert_farm_tip_if_missing(self, farm_id: int, tip_id: int) -> None:
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "SELECT 1 FROM {} WHERE id_farm = %s AND id_tip = %s LIMIT 1"
                ).format(qualified(self.schema_name, "farms_tips")),
                (farm_id, tip_id),
            )
            if cursor.fetchone():
                return
        values = {"id_farm": farm_id, "id_tip": tip_id}
        if self.simulate:
            assert self.allocator is not None
            values = {"id": self.allocator.next("farms_tips"), **values}
        columns = list(values)
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("INSERT INTO {} ({}) VALUES ({}) ON CONFLICT (id_farm, id_tip) DO NOTHING").format(
                    qualified(self.schema_name, "farms_tips"),
                    sql.SQL(", ").join(sql.Identifier(column) for column in columns),
                    sql.SQL(", ").join(sql.Placeholder() for _ in columns),
                ),
                tuple(values[column] for column in columns),
            )

    def insert_state_goal_region_if_missing(self, goal_id: int, region: str, source_id: int) -> None:
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT id FROM {} WHERE id_goal = %s AND region = %s ORDER BY id").format(
                    qualified(self.schema_name, "regions_goals")
                ),
                (goal_id, region),
            )
            region_ids = [int(row[0]) for row in cursor.fetchall()]
        if len(region_ids) > 1:
            raise PendingData("duplicate_destination_goal_regions", "regions_goals")
        if region_ids:
            region_id = region_ids[0]
        else:
            region_id = self.insert("regions_goals", {"region": region, "id_goal": goal_id})

        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "SELECT id FROM {} WHERE id_goal = %s AND id_region = %s ORDER BY id"
                ).format(qualified(self.schema_name, "state_goal_regions")),
                (goal_id, region_id),
            )
            links = cursor.fetchall()
        if not links:
            values = {"id_goal": goal_id, "id_region": region_id}
            if self.simulate:
                assert self.allocator is not None
                values = {"id": self.allocator.next("state_goal_regions"), **values}
            columns = list(values)
            with self.connection.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        "INSERT INTO {} ({}) VALUES ({}) "
                        "ON CONFLICT (id_goal, id_region) DO NOTHING"
                    ).format(
                        qualified(self.schema_name, "state_goal_regions"),
                        sql.SQL(", ").join(sql.Identifier(column) for column in columns),
                        sql.SQL(", ").join(sql.Placeholder() for _ in columns),
                    ),
                    tuple(values[column] for column in columns),
                )

        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "SELECT rg.id_goal, rg.region, sgr.id_goal "
                    "FROM {} rg JOIN {} sgr ON sgr.id_region = rg.id "
                    "WHERE rg.id = %s AND sgr.id_goal = %s"
                ).format(
                    qualified(self.schema_name, "regions_goals"),
                    qualified(self.schema_name, "state_goal_regions"),
                ),
                (region_id, goal_id),
            )
            verified = cursor.fetchone()
        if not verified or verified[0] != goal_id or verified[2] != goal_id or verified[1] != region:
            raise PendingData("goal_region_link_verification_failed", "state_goal_regions")

    def store_loaded_map(
        self,
        source_table: str,
        source_id: int,
        target_table: str,
        target_id: int,
    ) -> None:
        key = self.key(source_table, source_id, target_table)
        if self.simulate:
            self.maps[key] = MapEntry(target_id, "loaded")
            return
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "INSERT INTO public.{} "
                    "(source_system, source_table, source_id, target_table, target_id, status, reason) "
                    "VALUES (%s, %s, %s, %s, %s, 'loaded', NULL) "
                    "ON CONFLICT (source_system, source_table, source_id, target_table) "
                    "DO UPDATE SET target_id = EXCLUDED.target_id, status = 'loaded', "
                    "reason = NULL, updated_at = clock_timestamp()"
                ).format(sql.Identifier(MAP_TABLE)),
                (self.source_system, source_table, int(source_id), target_table, int(target_id)),
            )
        self.maps[key] = MapEntry(int(target_id), "loaded")

    def store_pending_map(
        self,
        source_table: str,
        source_id: int,
        target_table: str,
        reason: str,
    ) -> None:
        key = self.key(source_table, source_id, target_table)
        existing = self.maps.get(key)
        if existing and existing.status == "loaded":
            return
        if self.simulate:
            self.maps[key] = MapEntry(None, "pending", reason)
            return
        with self.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL(
                    "INSERT INTO public.{} AS current_map "
                    "(source_system, source_table, source_id, target_table, target_id, status, reason) "
                    "VALUES (%s, %s, %s, %s, NULL, 'pending', %s) "
                    "ON CONFLICT (source_system, source_table, source_id, target_table) "
                    "DO UPDATE SET target_id = NULL, status = 'pending', reason = EXCLUDED.reason, "
                    "updated_at = clock_timestamp() "
                    "WHERE current_map.status <> 'loaded'"
                ).format(sql.Identifier(MAP_TABLE)),
                (self.source_system, source_table, int(source_id), target_table, reason),
            )
        self.maps[key] = MapEntry(None, "pending", reason)

    def process_mapped_row(
        self,
        report: MigrationReport,
        source_table: str,
        source_id: Any,
        target_table: str,
        operation: Callable[[int | None], int],
        relationship_target_table: str | None = None,
    ) -> None:
        if source_id is None:
            report.add("pending", source_table, None, target_table, "missing_source_id")
            return
        source_id = int(source_id)
        key = self.key(source_table, source_id, target_table)
        entry = self.maps.get(key)
        was_loaded = bool(entry and entry.status == "loaded" and entry.target_id is not None)
        with self.connection.cursor() as cursor:
            cursor.execute("SAVEPOINT rpa_source_row")
        try:
            mapped_target_id: int | None = None
            if was_loaded:
                assert entry is not None and entry.target_id is not None
                if not self.target_row_exists(target_table, entry.target_id):
                    raise PendingData(f"mapped_target_missing:{target_table}")
                mapped_target_id = entry.target_id
            returned_id = operation(mapped_target_id)
            if not was_loaded:
                self.store_loaded_map(source_table, source_id, target_table, returned_id)
            with self.connection.cursor() as cursor:
                cursor.execute("RELEASE SAVEPOINT rpa_source_row")
            report.add("reused" if was_loaded else "loaded", source_table, source_id, target_table)
        except PendingData as exc:
            with self.connection.cursor() as cursor:
                cursor.execute("ROLLBACK TO SAVEPOINT rpa_source_row")
                cursor.execute("RELEASE SAVEPOINT rpa_source_row")
            pending_target = (
                relationship_target_table if was_loaded and relationship_target_table else
                exc.target_table or target_table
            )
            if not was_loaded:
                self.store_pending_map(source_table, source_id, target_table, exc.reason)
            report.add("pending", source_table, source_id, pending_target, exc.reason)
        except psycopg2.Error as exc:
            with self.connection.cursor() as cursor:
                cursor.execute("ROLLBACK TO SAVEPOINT rpa_source_row")
                cursor.execute("RELEASE SAVEPOINT rpa_source_row")
            state = getattr(exc, "pgcode", None)
            if not state or not state.startswith(("22", "23")):
                raise
            pending_target = relationship_target_table if was_loaded and relationship_target_table else target_table
            if not was_loaded:
                self.store_pending_map(source_table, source_id, target_table, "target_rejected_data")
            constraint = getattr(getattr(exc, "diag", None), "constraint_name", None)
            report.add(
                "pending",
                source_table,
                source_id,
                pending_target,
                "target_rejected_data",
                sqlstate=state,
                constraint=constraint,
            )


class MigrationRunner:
    def __init__(
        self,
        source_connection: psycopg2.extensions.connection,
        target_store: TargetStore,
        report: MigrationReport,
        source_schema: str,
        fetch_size: int = 1000,
    ) -> None:
        self.source = source_connection
        self.target = target_store
        self.report = report
        self.source_schema = source_schema
        self.fetch_size = fetch_size
        self.addresses_by_company = self._address_links("endereco_empresa", "id_empresa")
        self.addresses_by_farm = self._address_links("endereco_granja", "id_granja")
        self.company_by_farm = self._farm_enterprises()
        self.chickens_by_farm = self._farm_chicken_balances()

    def _rows(self, table_name: str, columns: Sequence[str] | None = None) -> Iterator[dict[str, Any]]:
        return stream_query(
            self.source,
            source_table_query(self.source_schema, table_name, columns),
            fetch_size=self.fetch_size,
        )

    def _address_links(self, table_name: str, relation_column: str) -> dict[int, list[int]]:
        result: dict[int, list[int]] = defaultdict(list)
        query = sql.SQL("SELECT id, {} FROM {} ORDER BY id").format(
            sql.Identifier(relation_column), qualified(self.source_schema, table_name)
        )
        for row in stream_query(self.source, query, fetch_size=self.fetch_size):
            relation_id = row[relation_column]
            if relation_id is not None:
                result[int(relation_id)].append(int(row["id"]))
        return result

    def _farm_enterprises(self) -> dict[int, int | None]:
        result: dict[int, int | None] = {}
        query = source_table_query(
            self.source_schema,
            "granja",
            ("id", "id_empresa"),
        )
        for row in stream_query(self.source, query, fetch_size=self.fetch_size):
            result[int(row["id"])] = int(row["id_empresa"]) if row["id_empresa"] is not None else None
        return result

    def _farm_chicken_balances(self) -> dict[int, int]:
        query = sql.SQL(
            "SELECT g.id AS legacy_farm_id, "
            "COALESCE(SUM(l.galinhas_recebidas), 0) "
            "- COALESCE(SUM(l.galinhas_entregadas), 0) AS chickens_now "
            "FROM {} g LEFT JOIN {} l ON l.id_granja = g.id "
            "GROUP BY g.id ORDER BY g.id"
        ).format(
            qualified(self.source_schema, "granja"),
            qualified(self.source_schema, "lote"),
        )
        return {
            int(row["legacy_farm_id"]): int(row["chickens_now"])
            for row in stream_query(self.source, query, fetch_size=self.fetch_size)
        }

    def _single_address_id(
        self,
        relation_map: Mapping[int, list[int]],
        relation_table: str,
        entity_id: int,
    ) -> int:
        address_ids = relation_map.get(entity_id, [])
        if not address_ids:
            raise PendingData("missing_address")
        if len(address_ids) > 1:
            raise PendingData("multiple_addresses_need_selection")
        return self.target.mapped_id(relation_table, address_ids[0], "addresses")

    def _simple_row(
        self,
        source_table: str,
        source_id: Any,
        target_table: str,
        make_values: Callable[[], Mapping[str, Any]],
        relation_target_table: str | None = None,
    ) -> None:
        def operation(mapped_target_id: int | None) -> int:
            if mapped_target_id is not None:
                return mapped_target_id
            return self.target.insert(target_table, make_values())

        self.target.process_mapped_row(
            self.report,
            source_table,
            source_id,
            target_table,
            operation,
            relationship_target_table=relation_target_table,
        )

    def _import_addresses(self) -> None:
        for table_name, _relation_column in ADDRESS_SOURCES:
            for row in self._rows(table_name):
                source_id = row["id"]

                def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                    if current["municipio"] is None:
                        raise PendingData("missing_city")
                    if current["cep"] is None:
                        raise PendingData("missing_zip_code")
                    if current["numero"] is None:
                        raise PendingData("missing_address_number")
                    return {
                        "zip_code": text_value(current["cep"]),
                        "state": state_code(current["estado"]),
                        "city": text_value(current["municipio"]),
                        "number": str(current["numero"]),
                        "country": country_code(current["pais"]),
                    }

                self._simple_row(table_name, source_id, "addresses", values)

    def _import_enterprises(self) -> None:
        for row in self._rows("empresa"):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                address_id = self._single_address_id(
                    self.addresses_by_company, "endereco_empresa", int(current["id"])
                )
                return {
                    "name": text_value(current["nome"]),
                    "email": text_value(current["email_corporativo"]),
                    "document_number": digits_only_value(current["cnpj"]),
                    "telephone": digits_only_value(current["telefone_corporativo"]),
                    "id_address": address_id,
                }

            self._simple_row("empresa", source_id, "enterprises", values)

    def _import_farms(self) -> None:
        for row in self._rows("granja"):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                farm_id = int(current["id"])
                address_id = self._single_address_id(
                    self.addresses_by_farm, "endereco_granja", farm_id
                )
                enterprise_source_id = self.company_by_farm.get(farm_id)
                enterprise_id = self.target.mapped_id("empresa", enterprise_source_id, "enterprises")
                area = current["area_propriedade"]
                if area is None:
                    raise PendingData("missing_property_area")
                if not isinstance(area, Decimal):
                    try:
                        area = Decimal(str(area))
                    except Exception as exc:
                        raise PendingData("invalid_property_area") from exc
                if current["regiao"] is None:
                    raise PendingData("missing_farm_region")
                return {
                    "name": text_value(current["nome"]),
                    "region": text_value(current["regiao"]),
                    "area_property": area,
                    "chickens_now": self.chickens_by_farm.get(farm_id, 0),
                    "id_address": address_id,
                    "id_enterprise": enterprise_id,
                }

            self._simple_row("granja", source_id, "farms", values)

    def _employee_query(self) -> sql.Composed:
        return sql.SQL(
            "SELECT e.*, phone.telefone AS rpa_latest_telephone "
            "FROM {} e LEFT JOIN LATERAL ("
            "SELECT t.telefone FROM {} t WHERE t.id_funcionario = e.id "
            "ORDER BY t.id DESC LIMIT 1"
            ") phone ON TRUE ORDER BY e.id"
        ).format(
            qualified(self.source_schema, "funcionario"),
            qualified(self.source_schema, "telefone_funcionario"),
        )

    def _owner_query(self) -> sql.Composed:
        return sql.SQL(
            "SELECT o.*, phone.telefone AS rpa_latest_telephone "
            "FROM {} o LEFT JOIN LATERAL ("
            "SELECT t.telefone FROM {} t WHERE t.id_proprietario = o.id "
            "ORDER BY t.id DESC LIMIT 1"
            ") phone ON TRUE ORDER BY o.id"
        ).format(
            qualified(self.source_schema, "proprietario_granja"),
            qualified(self.source_schema, "telefone_proprietario"),
        )

    def _import_employees(self) -> None:
        for row in stream_query(self.source, self._employee_query(), fetch_size=self.fetch_size):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                enterprise_id = self.target.mapped_id("empresa", current["id_empresa"], "enterprises")
                return {
                    "name": text_value(current["nome"]),
                    "document_number": digits_only_value(current["cpf"]),
                    "email": text_value(current["email"]),
                    "telephone": digits_only_value(current["rpa_latest_telephone"]),
                    "password": text_value(current["senha"]),
                    "id_enterprise": enterprise_id,
                }

            self._simple_row("funcionario", source_id, "company_employees", values)

    def _import_owners(self) -> None:
        for row in stream_query(self.source, self._owner_query(), fetch_size=self.fetch_size):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                farm_id = self.target.mapped_id("granja", current["id_granja"], "farms")
                return {
                    "name": text_value(current["nome"]),
                    "document_number": digits_only_value(current["cpf"]),
                    "password": text_value(current["senha"]),
                    "email": text_value(current["email"]),
                    "telephone": digits_only_value(current["rpa_latest_telephone"]),
                    "first_access": False,
                    "foto_url": None,
                    "id_farm": farm_id,
                }

            self._simple_row("proprietario_granja", source_id, "farm_owners", values)

    def _import_tips(self) -> None:
        for row in self._rows("dica"):
            source_id = row["id"]

            def operation(mapped_target_id: int | None, current: dict[str, Any] = row) -> int:
                tip_id = (
                    mapped_target_id
                    if mapped_target_id is not None
                    else self.target.insert("tips", {"tip": text_value(current["titulo"])})
                )
                farm_id = self.target.mapped_id("granja", current["id_granja"], "farms")
                self.target.insert_farm_tip_if_missing(farm_id, tip_id)
                return tip_id

            self.target.process_mapped_row(
                self.report,
                "dica",
                source_id,
                "tips",
                operation,
                relationship_target_table="farms_tips",
            )

    def _import_reviews(self) -> None:
        for row in self._rows("avaliacao"):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                tip_id = self.target.mapped_id("dica", current["id_dica"], "tips")
                return {
                    "comment": text_value(current["comentario"]),
                    "rating": current["nota"],
                    "id_tip": tip_id,
                }

            self._simple_row("avaliacao", source_id, "reviews", values)

    def _import_lots(self) -> None:
        for row in self._rows("lote"):
            source_id = row["id"]

            def values(current: dict[str, Any] = row) -> Mapping[str, Any]:
                farm_source_id = current["id_granja"]
                farm_id = self.target.mapped_id("granja", farm_source_id, "farms")
                enterprise_source_id = self.company_by_farm.get(int(farm_source_id)) if farm_source_id is not None else None
                enterprise_id = self.target.mapped_id("empresa", enterprise_source_id, "enterprises")
                received = current["galinhas_recebidas"]
                delivered = current["galinhas_entregadas"]
                if received is None or delivered is None:
                    raise PendingData("missing_lot_chicken_count")
                received = int(received)
                delivered = int(delivered)
                delivery_date = current["dt_entrega"]
                if isinstance(delivery_date, datetime):
                    delivery_date = delivery_date.date()
                elif delivery_date is not None and not isinstance(delivery_date, date):
                    raise PendingData("invalid_delivery_date")
                return {
                    "received_chickens": received,
                    "delivered_chickens": delivered,
                    "delivery_date": delivery_date,
                    "losts": received - delivered,
                    "cost": float(delivered * 50),
                    "id_enterprise": enterprise_id,
                    "id_farm": farm_id,
                }

            self._simple_row("lote", source_id, "lots", values)

    def _resource_query(self, resource_table: str) -> sql.Composed:
        return sql.SQL(
            "SELECT r.*, l.id_granja AS rpa_legacy_farm_id "
            "FROM {} r LEFT JOIN {} l ON l.id = r.id_lote ORDER BY r.id"
        ).format(
            qualified(self.source_schema, resource_table),
            qualified(self.source_schema, "lote"),
        )

    def _resource_target_conflict(
        self,
        target_table: str,
        farm_id: int,
        registration_date: datetime,
        source_values: Sequence[Any],
    ) -> bool:
        if target_table == "water_registries":
            columns = ("start_hydrometer", "end_hydrometer")
        else:
            columns = ("energy_consumption",)
        conditions = [sql.SQL("id_farm = %s"), sql.SQL("registration_date IS NOT DISTINCT FROM %s")]
        conditions.extend(sql.SQL("{} IS NOT DISTINCT FROM %s").format(sql.Identifier(column)) for column in columns)
        with self.target.connection.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT EXISTS (SELECT 1 FROM {} WHERE {})").format(
                    qualified(self.target.schema_name, target_table),
                    sql.SQL(" AND ").join(conditions),
                ),
                (farm_id, registration_date, *source_values),
            )
            return bool(cursor.fetchone()[0])

    def _import_resources(self, source_table: str, target_table: str) -> None:
        duplicated_ids = duplicate_resource_ids(self.source, self.source_schema, source_table)
        for row in stream_query(self.source, self._resource_query(source_table), fetch_size=self.fetch_size):
            source_id = int(row["id"])
            map_entry = self.target.maps.get(self.target.key(source_table, source_id, target_table))
            if source_id in duplicated_ids and not (map_entry and map_entry.status == "loaded"):
                reason = "duplicate_source_natural_key"
                self.target.store_pending_map(source_table, source_id, target_table, reason)
                self.report.add("pending", source_table, source_id, target_table, reason)
                continue

            def operation(mapped_target_id: int | None, current: dict[str, Any] = row) -> int:
                if mapped_target_id is not None:
                    return mapped_target_id
                farm_id = self.target.mapped_id(
                    "granja", current["rpa_legacy_farm_id"], "farms"
                )
                registration_date = timestamp_value(current["dt_registro"])
                if target_table == "water_registries":
                    hydrometer_values = (
                        current["hidrometro_inicio"],
                        current["hidrometro_final"],
                    )
                    if self._resource_target_conflict(
                        target_table, farm_id, registration_date, hydrometer_values
                    ):
                        raise PendingData("destination_natural_key_collision")
                    return self.target.insert(
                        target_table,
                        {
                            "registration_date": registration_date,
                            "start_hydrometer": current["hidrometro_inicio"],
                            "end_hydrometer": current["hidrometro_final"],
                            "id_farm": farm_id,
                        },
                    )

                consumption = current["consumo"]
                if self._resource_target_conflict(
                    target_table, farm_id, registration_date, (consumption,)
                ):
                    raise PendingData("destination_natural_key_collision")
                return self.target.insert(
                    target_table,
                    {
                        "registration_date": registration_date,
                        "energy_consumption": consumption,
                        "id_farm": farm_id,
                    },
                )

            self.target.process_mapped_row(
                self.report,
                source_table,
                source_id,
                target_table,
                operation,
            )

    def _import_goals(self) -> None:
        for row in self._rows("meta"):
            source_id = row["id"]
            individual = row["is_individual"]
            if not isinstance(individual, bool):
                reason = "invalid_goal_branch_flag"
                target_table = "individual_goals"
                self.target.store_pending_map("meta", int(source_id), target_table, reason)
                self.report.add("pending", "meta", int(source_id), target_table, reason)
                continue
            target_table = "individual_goals" if individual else "state_goals"
            collective_status_reason: str | None = None
            if not individual:
                try:
                    goal_status(row["status"])
                except PendingData as exc:
                    collective_status_reason = exc.reason
                else:
                    collective_status_reason = "collective_goal_status_requires_farm_association"

            def operation(mapped_target_id: int | None, current: dict[str, Any] = row) -> int:
                goal_id = mapped_target_id
                if goal_id is None:
                    common = {
                        "description": text_value(current["descricao"]),
                        "type": text_value(current["tipo_meta"]),
                        "target_value": positive_numeric_value(current["valor_alvo"]),
                        "title": text_value(current["titulo"]),
                    }
                    if current["is_individual"]:
                        common["status"] = goal_status(current["status"])
                        farm_id = self.target.mapped_id("granja", current["id_granja"], "farms")
                        common["id_farm"] = farm_id
                        goal_id = self.target.insert("individual_goals", common)
                    else:
                        goal_id = self.target.insert("state_goals", common)
                if not current["is_individual"] and current["regiao"] is not None:
                    self.target.insert_state_goal_region_if_missing(
                        goal_id,
                        text_value(current["regiao"]),
                        int(current["id"]),
                    )
                assert goal_id is not None
                return goal_id

            self.target.process_mapped_row(
                self.report,
                "meta",
                source_id,
                target_table,
                operation,
                relationship_target_table="state_goal_regions" if not individual else None,
            )
            if not individual and collective_status_reason:
                goal_entry = self.target.maps.get(
                    self.target.key("meta", int(source_id), "state_goals")
                )
                status_entry = self.target.maps.get(
                    self.target.key("meta", int(source_id), "farm_goals")
                )
                if (
                    goal_entry
                    and goal_entry.status == "loaded"
                    and not (status_entry and status_entry.status == "loaded")
                ):
                    self.target.store_pending_map(
                        "meta", int(source_id), "farm_goals", collective_status_reason
                    )
                    self.report.add(
                        "pending", "meta", int(source_id), "farm_goals", collective_status_reason
                    )

    def run_pipeline(self) -> None:
        self._import_addresses()
        self._import_enterprises()
        self._import_farms()
        self._import_employees()
        self._import_owners()
        self._import_tips()
        self._import_reviews()
        self._import_lots()
        self._import_resources("registro_agua", "water_registries")
        self._import_resources("registro_energia", "energy_registries")
        self._import_goals()


def _database_name(connection: psycopg2.extensions.connection) -> str:
    with connection.cursor() as cursor:
        cursor.execute("SELECT current_database()")
        return str(cursor.fetchone()[0])


def _source_goal_status_counts(
    connection: psycopg2.extensions.connection,
    schema_name: str,
) -> dict[str, int]:
    query = sql.SQL(
        "SELECT status, COUNT(*) FROM {} GROUP BY status ORDER BY status NULLS FIRST"
    ).format(qualified(schema_name, "meta"))
    counts: dict[str, int] = {}
    with connection.cursor() as cursor:
        cursor.execute(query)
        rows = cursor.fetchall()
    for value, count in rows:
        label = "<NULL>" if value is None else str(value)
        counts[label] = int(count)
    return counts


def diagnose(
    source: psycopg2.extensions.connection,
    target: psycopg2.extensions.connection,
    source_schema: str,
    target_schema: str,
    source_system: str,
) -> dict[str, Any]:
    source_database = _database_name(source)
    target_schema_report = validate_target_schema(target, target_schema)
    source_issues = validate_source_schema(source, source_schema)
    counts = count_source_rows(source, source_schema) if not source_issues else {}
    ambiguities = address_ambiguities(source, source_schema) if not source_issues else {}
    duplicate_resources: dict[str, int] = {}
    goal_status_counts: dict[str, int] = {}
    unknown_goal_statuses: dict[str, int] = {}
    if not source_issues:
        for table_name in ("registro_agua", "registro_energia"):
            duplicate_resources[table_name] = len(
                duplicate_resource_ids(source, source_schema, table_name)
            )
        goal_status_counts = _source_goal_status_counts(source, source_schema)
        unknown_goal_statuses = {
            status: count
            for status, count in goal_status_counts.items()
            if status == "<NULL>" or normalize_key(status).replace("_", " ") not in GOAL_STATUSES
        }
    safe_to_simulate = not target_schema_report["unsafe_simulation_triggers"]
    ready = (
        not source_issues
        and target_schema_report["ready"]
        and safe_to_simulate
    )
    return {
        "kind": "diagnostic",
        "source_system": source_system,
        "source_database": source_database,
        "target_database": target_schema_report["database"],
        "source_schema": source_schema,
        "target_schema_name": target_schema,
        "ready": ready,
        "source_schema_issues": source_issues,
        "target_schema": target_schema_report,
        "source_row_counts": counts,
        "ambiguous_addresses": ambiguities,
        "duplicate_resource_rows": duplicate_resources,
        "goal_status_counts": goal_status_counts,
        "unknown_goal_status_counts": unknown_goal_statuses,
        "notes": [
            "O diagnóstico não altera dados.",
            "Conflitos e linhas pendentes devem ser analisados no relatório de simulação.",
            "País de endereço nulo ou vazio será assumido como BR.",
            "Telefones, CPFs e CNPJs serão armazenados somente com dígitos, sem separadores de formatação.",
            "Status de metas coletivas sem vínculo de fazenda serão sinalizados como pendentes na simulação.",
        ],
    }


class Reconciliation:
    """Validate persisted ID mappings and important foreign-key relationships."""

    def __init__(
        self,
        source: psycopg2.extensions.connection,
        target: psycopg2.extensions.connection,
        target_store: TargetStore,
        source_schema: str,
        target_schema: str,
        fetch_size: int,
    ) -> None:
        self.source = source
        self.target = target
        self.store = target_store
        self.source_schema = source_schema
        self.target_schema = target_schema
        self.fetch_size = fetch_size
        self.checked: Counter[str] = Counter()
        self.issues: list[dict[str, Any]] = []
        self.truncated = False

    def _issue(self, source_table: str, source_id: int, relation: str, reason: str) -> None:
        if len(self.issues) >= REPORT_DETAIL_LIMIT:
            self.truncated = True
            return
        self.issues.append({
            "source_table": source_table,
            "source_id": int(source_id),
            "relationship": relation,
            "reason": reason,
        })

    def _mapped(self, source_table: str, source_id: Any, target_table: str) -> int | None:
        if source_id is None:
            return None
        entry = self.store.maps.get(self.store.key(source_table, int(source_id), target_table))
        if entry is None or entry.status != "loaded" or entry.target_id is None:
            return None
        return entry.target_id

    def _target_relation_matches(
        self,
        target_table: str,
        target_id: int,
        relation_columns: Mapping[str, int],
    ) -> bool:
        conditions = [sql.SQL("id = %s")]
        conditions.extend(
            sql.SQL("{} IS NOT DISTINCT FROM %s").format(sql.Identifier(column))
            for column in relation_columns
        )
        with self.target.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT EXISTS (SELECT 1 FROM {} WHERE {})").format(
                    qualified(self.target_schema, target_table),
                    sql.SQL(" AND ").join(conditions),
                ),
                (target_id, *relation_columns.values()),
            )
            return bool(cursor.fetchone()[0])

    def _target_values_match(
        self,
        target_table: str,
        target_id: int,
        expected_values: Mapping[str, Any],
    ) -> bool:
        conditions = [sql.SQL("id = %s")]
        conditions.extend(
            sql.SQL("{} IS NOT DISTINCT FROM %s").format(sql.Identifier(column))
            for column in expected_values
        )
        with self.target.cursor() as cursor:
            cursor.execute(
                sql.SQL("SELECT EXISTS (SELECT 1 FROM {} WHERE {})").format(
                    qualified(self.target_schema, target_table),
                    sql.SQL(" AND ").join(conditions),
                ),
                (target_id, *expected_values.values()),
            )
            return bool(cursor.fetchone()[0])

    def _check_parent(
        self,
        source_table: str,
        target_table: str,
        row: Mapping[str, Any],
        source_column: str,
        target_column: str,
        parent_source_table: str,
        parent_target_table: str,
        relation: str,
    ) -> None:
        source_id = row["id"]
        target_id = self._mapped(source_table, source_id, target_table)
        parent_id = self._mapped(parent_source_table, row[source_column], parent_target_table)
        if target_id is None or parent_id is None:
            return
        self.checked[relation] += 1
        if not self._target_relation_matches(target_table, target_id, {target_column: parent_id}):
            self._issue(source_table, int(source_id), relation, "target_foreign_key_mismatch")

    def run(self) -> dict[str, Any]:
        # Simulation already has temporary mappings for inserts in this transaction.
        # Loading the persistent table again would overwrite successful retries of
        # previously pending rows with their stale persisted "pending" entries.
        if not self.store.maps:
            self.store.load_maps()
        loaded_map_count = 0
        for (source_table, source_id, target_table), entry in list(self.store.maps.items()):
            if entry.status != "loaded" or entry.target_id is None:
                continue
            loaded_map_count += 1
            if not self.store.target_row_exists(target_table, entry.target_id):
                self._issue(source_table, source_id, "id_map", f"mapped_target_missing:{target_table}")
        self.checked["loaded_id_maps"] = loaded_map_count

        for row in stream_query(
            self.source,
            source_table_query(self.source_schema, "empresa", ("id",)),
            fetch_size=self.fetch_size,
        ):
            source_id = int(row["id"])
            target_id = self._mapped("empresa", source_id, "enterprises")
            address_ids = self._source_address_ids("endereco_empresa", "id_empresa", source_id)
            if target_id is None or len(address_ids) != 1:
                continue
            address_id = self._mapped("endereco_empresa", address_ids[0], "addresses")
            if address_id is None:
                continue
            self.checked["enterprise_address"] += 1
            if not self._target_relation_matches("enterprises", target_id, {"id_address": address_id}):
                self._issue("empresa", source_id, "enterprise_address", "target_foreign_key_mismatch")

        for row in stream_query(
            self.source,
            source_table_query(self.source_schema, "granja", ("id", "id_empresa")),
            fetch_size=self.fetch_size,
        ):
            farm_id = int(row["id"])
            target_id = self._mapped("granja", farm_id, "farms")
            address_ids = self._source_address_ids("endereco_granja", "id_granja", farm_id)
            address_id = self._mapped("endereco_granja", address_ids[0], "addresses") if len(address_ids) == 1 else None
            enterprise_id = self._mapped("empresa", row["id_empresa"], "enterprises")
            if target_id is None:
                continue
            if address_id is not None:
                self.checked["farm_address"] += 1
                if not self._target_relation_matches("farms", target_id, {"id_address": address_id}):
                    self._issue("granja", farm_id, "farm_address", "target_foreign_key_mismatch")
            if enterprise_id is not None:
                self.checked["farm_enterprise"] += 1
                if not self._target_relation_matches("farms", target_id, {"id_enterprise": enterprise_id}):
                    self._issue("granja", farm_id, "farm_enterprise", "target_foreign_key_mismatch")

        lot_enterprise_query = sql.SQL(
            "SELECT l.id, g.id_empresa FROM {} l LEFT JOIN {} g ON g.id = l.id_granja ORDER BY l.id"
        ).format(qualified(self.source_schema, "lote"), qualified(self.source_schema, "granja"))
        for row in stream_query(self.source, lot_enterprise_query, fetch_size=self.fetch_size):
            lot_id = self._mapped("lote", row["id"], "lots")
            enterprise_id = self._mapped("empresa", row["id_empresa"], "enterprises")
            if lot_id is None or enterprise_id is None:
                continue
            self.checked["lot_enterprise"] += 1
            if not self._target_relation_matches("lots", lot_id, {"id_enterprise": enterprise_id}):
                self._issue("lote", int(row["id"]), "lot_enterprise", "target_foreign_key_mismatch")

        relationship_specs = (
            ("funcionario", "company_employees", "id_empresa", "id_enterprise", "empresa", "enterprises", "employee_enterprise"),
            ("proprietario_granja", "farm_owners", "id_granja", "id_farm", "granja", "farms", "owner_farm"),
            ("avaliacao", "reviews", "id_dica", "id_tip", "dica", "tips", "review_tip"),
            ("lote", "lots", "id_granja", "id_farm", "granja", "farms", "lot_farm"),
            ("meta", "individual_goals", "id_granja", "id_farm", "granja", "farms", "individual_goal_farm"),
        )
        for source_table, target_table, source_column, target_column, parent_source, parent_target, relation in relationship_specs:
            columns = ("id", source_column)
            query = source_table_query(self.source_schema, source_table, columns)
            for row in stream_query(self.source, query, fetch_size=self.fetch_size):
                self._check_parent(
                    source_table, target_table, row, source_column, target_column,
                    parent_source, parent_target, relation,
                )

        for row in self._rows_with_join(
            "dica",
            "SELECT d.id, d.id_granja FROM {} d ORDER BY d.id",
            ("dica",),
        ):
            tip_id = self._mapped("dica", row["id"], "tips")
            farm_id = self._mapped("granja", row["id_granja"], "farms")
            if tip_id is None or farm_id is None:
                continue
            self.checked["tip_farm"] += 1
            with self.target.cursor() as cursor:
                cursor.execute(
                    sql.SQL("SELECT EXISTS (SELECT 1 FROM {} WHERE id_tip = %s AND id_farm = %s)").format(
                        qualified(self.target_schema, "farms_tips")
                    ),
                    (tip_id, farm_id),
                )
                if not cursor.fetchone()[0]:
                    self._issue("dica", int(row["id"]), "tip_farm", "target_link_missing")

        for source_table, target_table in (("registro_agua", "water_registries"), ("registro_energia", "energy_registries")):
            query = sql.SQL(
                "SELECT r.id, r.dt_registro, l.id_granja, "
                + ("r.hidrometro_inicio, r.hidrometro_final " if source_table == "registro_agua" else "r.consumo ")
                + "FROM {} r LEFT JOIN {} l ON l.id = r.id_lote ORDER BY r.id"
            ).format(qualified(self.source_schema, source_table), qualified(self.source_schema, "lote"))
            for row in stream_query(self.source, query, fetch_size=self.fetch_size):
                target_id = self._mapped(source_table, row["id"], target_table)
                farm_id = self._mapped("granja", row["id_granja"], "farms")
                if target_id is None or farm_id is None:
                    continue
                relation = f"{target_table}_farm"
                self.checked[relation] += 1
                try:
                    registration_date = timestamp_value(row["dt_registro"])
                except PendingData as exc:
                    self._issue(source_table, int(row["id"]), relation, exc.reason)
                    continue
                expected = {"id_farm": farm_id, "registration_date": registration_date}
                if source_table == "registro_agua":
                    expected.update({
                        "start_hydrometer": row["hidrometro_inicio"],
                        "end_hydrometer": row["hidrometro_final"],
                    })
                else:
                    expected["energy_consumption"] = row["consumo"]
                if not self._target_values_match(target_table, target_id, expected):
                    self._issue(source_table, int(row["id"]), relation, "target_farm_timestamp_or_reading_mismatch")

        for row in stream_query(
            self.source,
            source_table_query(self.source_schema, "meta", ("id", "is_individual", "regiao")),
            fetch_size=self.fetch_size,
        ):
            if row["is_individual"] is True or row["regiao"] is None:
                continue
            goal_id = self._mapped("meta", row["id"], "state_goals")
            if goal_id is None:
                continue
            region = text_value(row["regiao"])
            with self.target.cursor() as cursor:
                cursor.execute(
                    sql.SQL(
                        "SELECT EXISTS (SELECT 1 FROM {} rg JOIN {} sgr ON sgr.id_region = rg.id "
                        "WHERE rg.id_goal = %s AND rg.region = %s AND sgr.id_goal = %s)"
                    ).format(
                        qualified(self.target_schema, "regions_goals"),
                        qualified(self.target_schema, "state_goal_regions"),
                    ),
                    (goal_id, region, goal_id),
                )
                self.checked["state_goal_region"] += 1
                if not cursor.fetchone()[0]:
                    self._issue("meta", int(row["id"]), "state_goal_region", "target_link_or_region_text_mismatch")

        return {
            "checked": dict(self.checked),
            "issue_count": len(self.issues),
            "issues": self.issues,
            "issues_truncated": self.truncated,
            "ready": not self.issues,
        }

    def _source_address_ids(self, table: str, relation_column: str, entity_id: int) -> list[int]:
        query = sql.SQL("SELECT id FROM {} WHERE {} = %s ORDER BY id").format(
            qualified(self.source_schema, table), sql.Identifier(relation_column)
        )
        with self.source.cursor() as cursor:
            cursor.execute(query, (entity_id,))
            return [int(row[0]) for row in cursor.fetchall()]

    def _rows_with_join(self, _table_name: str, query_template: str, tables: Sequence[str]) -> Iterator[dict[str, Any]]:
        query = sql.SQL(query_template).format(
            *(qualified(self.source_schema, table_name) for table_name in tables)
        )
        return stream_query(self.source, query, fetch_size=self.fetch_size)


def write_json_report(path: str | None, report: Mapping[str, Any]) -> None:
    if not path:
        return
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, default=json_default) + "\n",
        encoding="utf-8",
    )


def connection_context(config: DatabaseConfig) -> dict[str, Any]:
    return {
        "host": config.host.strip().casefold(),
        "port": config.port,
        "database": config.database,
        "schema": config.schema,
    }


def read_report(path: str, expected_kind: str) -> dict[str, Any]:
    try:
        with Path(path).open("r", encoding="utf-8") as stream:
            report = json.load(stream)
    except (OSError, json.JSONDecodeError) as exc:
        raise RPAError(f"Não foi possível ler o relatório {path}: {exc}") from exc
    if not isinstance(report, dict) or report.get("kind") != expected_kind:
        raise RPAError(f"Relatório inválido: {path}; esperado kind={expected_kind}")
    return report


def validate_load_preflight(
    diagnostic_path: str,
    simulation_path: str,
    reconciliation_path: str,
    source_database: str,
    target_database: str,
    source_system: str,
    source_config: DatabaseConfig,
    target_config: DatabaseConfig,
) -> None:
    reports = (
        read_report(diagnostic_path, "diagnostic"),
        read_report(simulation_path, "simulation"),
        read_report(reconciliation_path, "reconciliation"),
    )
    for report in reports:
        if report.get("source_database") != source_database:
            raise RPAError("Relatórios de pré-carga foram gerados para outro banco de origem")
        if report.get("target_database") != target_database:
            raise RPAError("Relatórios de pré-carga foram gerados para outro banco de destino")
        if report.get("source_system") != source_system:
            raise RPAError("Relatórios de pré-carga foram gerados para outro sistema de origem")
        if report.get("source_connection") != connection_context(source_config):
            raise RPAError("Relatórios de pré-carga foram gerados por outra conexão ou schema de origem")
        if report.get("target_connection") != connection_context(target_config):
            raise RPAError("Relatórios de pré-carga foram gerados por outra conexão ou schema de destino")
        if not report.get("ready"):
            raise RPAError("Pré-carga reprovada: revise os relatórios antes de carregar")
    simulation = reports[1]
    reconciliation = reports[2]
    if simulation.get("rolled_back") is not True or not simulation.get("reconciliation", {}).get("ready"):
        raise RPAError("Relatório de simulação sem confirmação de rollback e reconciliação concluída")
    if reconciliation.get("phase") != "pre_load":
        raise RPAError("Use o relatório de reconciliação pré-carga antes de iniciar a carga")


def _connections() -> tuple[DatabaseConfig, DatabaseConfig, str, str, str, int]:
    load_dotenv()
    source_config = DatabaseConfig.from_env("RPA_SOURCE", "RPA_SOURCE_SCHEMA")
    target_config = DatabaseConfig.from_env("RPA_TARGET", "RPA_TARGET_SCHEMA")
    source_system = os.getenv("RPA_SOURCE_SYSTEM", "").strip()
    if not source_system:
        raise RPAError("Configure RPA_SOURCE_SYSTEM com um identificador estável para o banco legado")
    try:
        fetch_size = int(os.getenv("RPA_FETCH_SIZE", "1000"))
    except ValueError as exc:
        raise RPAError("RPA_FETCH_SIZE precisa ser um inteiro") from exc
    if not 1 <= fetch_size <= 100000:
        raise RPAError("RPA_FETCH_SIZE deve estar entre 1 e 100000")
    return source_config, target_config, source_config.schema, target_config.schema, source_system, fetch_size


def _same_database_endpoint(left: DatabaseConfig, right: DatabaseConfig) -> bool:
    return (
        left.host.strip().casefold(), left.port, left.database
    ) == (
        right.host.strip().casefold(), right.port, right.database
    )


def _same_connected_database(
    source: psycopg2.extensions.connection,
    target: psycopg2.extensions.connection,
    source_config: DatabaseConfig,
    target_config: DatabaseConfig,
) -> bool:
    def identity(connection: psycopg2.extensions.connection) -> tuple[Any, Any, Any]:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT current_database(), inet_server_addr()::text, inet_server_port()"
            )
            return tuple(cursor.fetchone())

    source_identity = identity(source)
    target_identity = identity(target)
    if source_identity[0] != target_identity[0]:
        return False
    if source_identity[1] is not None and target_identity[1] is not None:
        return source_identity[1:] == target_identity[1:]
    return _same_database_endpoint(source_config, target_config)


def _read_only(connection: psycopg2.extensions.connection) -> None:
    connection.set_session(isolation_level="REPEATABLE READ", readonly=True, autocommit=False)


def _command_diagnose(args: argparse.Namespace) -> int:
    source_cfg, target_cfg, source_schema, target_schema, source_system, _fetch_size = _connections()
    source = source_cfg.connect("rpa-pre-novo-diagnose-source")
    target = target_cfg.connect("rpa-pre-novo-diagnose-target")
    try:
        _read_only(source)
        _read_only(target)
        report = diagnose(source, target, source_schema, target_schema, source_system)
        report["source_connection"] = connection_context(source_cfg)
        report["target_connection"] = connection_context(target_cfg)
        if _same_connected_database(source, target, source_cfg, target_cfg):
            report["ready"] = False
            report["source_schema_issues"].append(
                "Origem e destino apontam para a mesma instância e banco PostgreSQL"
            )
        write_json_report(args.report, report)
        print(json.dumps(report, ensure_ascii=False, indent=2, default=json_default))
        return 0 if report["ready"] else 2
    finally:
        source.rollback()
        target.rollback()
        source.close()
        target.close()


def _command_simulate(args: argparse.Namespace) -> int:
    source_cfg, target_cfg, source_schema, target_schema, source_system, fetch_size = _connections()
    source = source_cfg.connect("rpa-pre-novo-simulate-source")
    target = target_cfg.connect("rpa-pre-novo-simulate-target")
    try:
        _read_only(source)
        if _same_connected_database(source, target, source_cfg, target_cfg):
            raise RPAError("Simulação bloqueada: origem e destino apontam para a mesma instância e banco")
        source_issues = validate_source_schema(source, source_schema)
        target_report = validate_target_schema(target, target_schema)
        if source_issues or not target_report["ready"]:
            raise RPAError("Schema incompatível; rode diagnose e corrija as migrations antes da simulação")
        if target_report["unsafe_simulation_triggers"]:
            raise RPAError(
                "Simulação bloqueada por triggers não validados: "
                + repr(target_report["unsafe_simulation_triggers"])
            )
        source_database = _database_name(source)
        target_database = target_report["database"]
        report = MigrationReport("simulate", source_system, source_database, target_database, datetime.now(timezone.utc))
        store = TargetStore(target, target_schema, source_system, simulate=True)
        store.lock_migration()
        store.load_maps()
        try:
            MigrationRunner(source, store, report, source_schema, fetch_size).run_pipeline()
            reconciliation = Reconciliation(
                source, target, store, source_schema, target_schema, fetch_size
            ).run()
            report.finish()
            result = report.as_dict()
            result.update({
                "kind": "simulation",
                "source_connection": connection_context(source_cfg),
                "target_connection": connection_context(target_cfg),
                "ready": reconciliation["ready"],
                "reconciliation": reconciliation,
                "rolled_back": True,
                "notes": [
                    "Todas as escritas da simulação foram revertidas.",
                    "IDs temporários negativos foram usados; sequences não foram avançadas.",
                    "Linhas pendentes são registradas sem incluir dados pessoais nos detalhes.",
                ],
            })
        finally:
            target.rollback()
        write_json_report(args.report, result)
        print(json.dumps(result, ensure_ascii=False, indent=2, default=json_default))
        return 0 if result["ready"] else 2
    finally:
        source.rollback()
        target.rollback()
        source.close()
        target.close()


def _command_reconcile(args: argparse.Namespace) -> int:
    source_cfg, target_cfg, source_schema, target_schema, source_system, fetch_size = _connections()
    source = source_cfg.connect("rpa-pre-novo-reconcile-source")
    target = target_cfg.connect("rpa-pre-novo-reconcile-target")
    try:
        _read_only(source)
        _read_only(target)
        if _same_connected_database(source, target, source_cfg, target_cfg):
            raise RPAError("Reconciliação bloqueada: origem e destino apontam para a mesma instância e banco")
        source_database = _database_name(source)
        target_database = _database_name(target)
        if args.before_load:
            if not args.simulation_report:
                raise RPAError("Use --simulation-report para reconciliar a simulação antes da carga")
            simulation = read_report(args.simulation_report, "simulation")
            if simulation.get("source_database") != source_database or simulation.get("target_database") != target_database:
                raise RPAError("Relatório de simulação pertence a bancos diferentes dos configurados")
            if simulation.get("source_system") != source_system:
                raise RPAError("Relatório de simulação pertence a outro sistema de origem")
            simulated_checks = simulation.get("reconciliation", {})
            report = {
                "kind": "reconciliation",
                "phase": "pre_load",
                "source_system": source_system,
                "source_database": source_database,
                "target_database": target_database,
                "source_connection": connection_context(source_cfg),
                "target_connection": connection_context(target_cfg),
                "ready": bool(simulation.get("ready") and simulated_checks.get("ready")),
                "checked": simulated_checks.get("checked", {}),
                "issue_count": simulated_checks.get("issue_count", 0),
                "issues": simulated_checks.get("issues", []),
                "issues_truncated": simulated_checks.get("issues_truncated", False),
            }
        else:
            schema_report = validate_target_schema(target, target_schema)
            if not schema_report["ready"]:
                raise RPAError("Schema do destino não corresponde ao aprovado; reconciliação interrompida")
            store = TargetStore(target, target_schema, source_system, simulate=False)
            if not store.map_table_exists():
                raise RPAError("Mapa de IDs ainda não existe; use --before-load com o relatório da simulação")
            report = Reconciliation(
                source, target, store, source_schema, target_schema, fetch_size
            ).run()
            report.update({
                "kind": "reconciliation",
                "phase": "post_load",
                "source_system": source_system,
                "source_database": source_database,
                "target_database": target_database,
                "source_connection": connection_context(source_cfg),
                "target_connection": connection_context(target_cfg),
            })
        write_json_report(args.report, report)
        print(json.dumps(report, ensure_ascii=False, indent=2, default=json_default))
        return 0 if report["ready"] else 2
    finally:
        source.rollback()
        target.rollback()
        source.close()
        target.close()


def _command_load(args: argparse.Namespace) -> int:
    if not args.confirm_load:
        raise RPAError("Carga bloqueada: informe --confirm-load após revisar os relatórios de pré-carga")
    if not args.expected_target_db:
        raise RPAError("Carga bloqueada: --expected-target-db é obrigatório")
    required_reports = (args.diagnostic_report, args.simulation_report, args.reconciliation_report)
    if not all(required_reports):
        raise RPAError(
            "Carga bloqueada: informe --diagnostic-report, --simulation-report e "
            "--reconciliation-report gerados antes da carga"
        )
    source_cfg, target_cfg, source_schema, target_schema, source_system, fetch_size = _connections()
    if target_cfg.database != args.expected_target_db:
        raise RPAError(
            f"Carga bloqueada: banco configurado é {target_cfg.database!r}, "
            f"mas --expected-target-db foi {args.expected_target_db!r}"
        )
    source = source_cfg.connect("rpa-pre-novo-load-source")
    target = target_cfg.connect("rpa-pre-novo-load-target")
    try:
        _read_only(source)
        if _same_connected_database(source, target, source_cfg, target_cfg):
            raise RPAError("Carga bloqueada: origem e destino apontam para a mesma instância e banco")
        target_database = _database_name(target)
        source_database = _database_name(source)
        validate_load_preflight(
            args.diagnostic_report,
            args.simulation_report,
            args.reconciliation_report,
            source_database,
            target_database,
            source_system,
            source_cfg,
            target_cfg,
        )
        source_issues = validate_source_schema(source, source_schema)
        target_report = validate_target_schema(target, target_schema)
        if source_issues or not target_report["ready"]:
            raise RPAError("Schema mudou desde a pré-carga; rode diagnose, simulate e reconcile novamente")
        if target_report["unsafe_simulation_triggers"]:
            raise RPAError("Carga bloqueada: há triggers de inserção que não foram validados")
        report = MigrationReport("load", source_system, source_database, target_database, datetime.now(timezone.utc))
        store = TargetStore(target, target_schema, source_system, simulate=False)
        try:
            store.lock_migration()
            store.ensure_map_table()
            store.load_maps()
            MigrationRunner(source, store, report, source_schema, fetch_size).run_pipeline()
            report.finish()
            result = report.as_dict()
            result.update({
                "kind": "load",
                "source_connection": connection_context(source_cfg),
                "target_connection": connection_context(target_cfg),
                "ready": True,
                "notes": ["Carga concluída na transação PostgreSQL; mapas de ID foram gravados junto com os dados."],
            })
            target.commit()
        except Exception:
            target.rollback()
            raise
        write_json_report(args.report, result)
        print(json.dumps(result, ensure_ascii=False, indent=2, default=json_default))
        return 0
    finally:
        source.rollback()
        source.close()
        target.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Migra dados selecionados do banco pré para o esquema novo do Ouros."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command_name, help_text in (
        ("diagnose", "Verifica esquemas e qualidade inicial sem alterar dados."),
        ("simulate", "Executa a migração em transação revertida."),
        ("reconcile", "Confere os vínculos simulados ou os mapas já persistidos."),
        ("load", "Executa a carga real após confirmação e pré-carga aprovada."),
    ):
        command = subparsers.add_parser(command_name, help=help_text)
        command.add_argument("--report", help="Caminho para salvar o relatório JSON sem dados pessoais.")
        command.set_defaults(func={
            "diagnose": _command_diagnose,
            "simulate": _command_simulate,
            "reconcile": _command_reconcile,
            "load": _command_load,
        }[command_name])
    reconcile_parser = subparsers.choices["reconcile"]
    reconcile_group = reconcile_parser.add_mutually_exclusive_group(required=True)
    reconcile_group.add_argument(
        "--before-load", action="store_true",
        help="Gera relatório pré-carga a partir da reconciliação embutida na simulação.",
    )
    reconcile_group.add_argument(
        "--after-load", action="store_true",
        help="Revalida os mapas e os relacionamentos persistidos no destino.",
    )
    reconcile_parser.add_argument("--simulation-report", help="Relatório JSON gerado por simulate.")

    load_parser = subparsers.choices["load"]
    load_parser.add_argument("--confirm-load", action="store_true", help="Confirma a execução de escritas reais.")
    load_parser.add_argument("--expected-target-db", help="Nome exato do banco de destino autorizado.")
    load_parser.add_argument("--diagnostic-report", help="Relatório JSON de diagnose.")
    load_parser.add_argument("--simulation-report", help="Relatório JSON de simulate.")
    load_parser.add_argument("--reconciliation-report", help="Relatório JSON pré-carga de reconcile.")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (RPAError, psycopg2.Error, OSError, ValueError) as exc:
        print(f"Erro: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
