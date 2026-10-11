# Escopo do RPA: banco pré para banco novo

Especificação baseada na seleção mais recente do usuário, no inventário e DDL do pré enviados na conversa e no `sql/banco_ouros_fisico.sql` presente no workspace. Este documento substitui as suposições anteriores sobre quais dados importar. Nenhuma carga ou alteração de esquema foi executada para elaborar este documento.

## Etapa inicial obrigatória: branch e PR das alterações no banco

Antes de implementar o código do RPA:

1. Criar uma branch específica para as alterações de banco, usando o prefixo `codex/`.
2. Preparar nessa branch as migrations separadas, os ajustes do DDL, da configuração de execução e das dependências necessárias descritos na seção 15.
3. Conferir as alterações de esquema e publicar a branch com uma PR que explique o que será alterado e como foi validado.
4. Aguardar o usuário validar e mergear essa PR. Não fazer o merge em nome do usuário nem iniciar a implementação do código do RPA enquanto a PR não tiver sido validada e mergeada por ele.
5. Após confirmar o merge, atualizar a base de trabalho com as alterações aprovadas e prosseguir com a implementação do RPA conforme este plano.
6. Antes da carga real, confirmar que as migrations aprovadas foram aplicadas ao banco de destino; o merge da PR sozinho não comprova a aplicação no banco.

A aprovação e o merge da PR de banco são uma condição obrigatória para prosseguir no código do RPA. Esta seção registra a ordem futura de execução; sua inclusão no plano não cria uma branch ou PR agora.

## 1. Regra de IDs e relacionamentos

Não copiar o `id` antigo como chave primária do destino. Ler os IDs antigos como referências técnicas e gerar os novos IDs com `INSERT ... RETURNING id`.

Regra reafirmada pelo usuário: inserir a entidade no novo banco, obter o ID retornado pela inserção e atribuir esse ID aos registros dependentes. Isso se aplica a todos os relacionamentos, incluindo dicas/avaliações e metas/regiões; IDs do legado não são copiados como IDs do destino.

Manter um mapa persistente por sistema de origem, tabela de origem, ID antigo e tabela de destino. Assim, `dica.id = 10` poderá corresponder a `tips.id = 82`, e uma avaliação cujo `id_dica = 10` será gravada com `id_tip = 82`. Aplicar a mesma resolução para empresas, granjas, proprietários, lotes, endereços e metas.

O mapa diferencia IDs iguais provenientes de tabelas diferentes. Em nova execução, reutilizar o vínculo existente em vez de criar outra linha. Não associar entidades apenas por nome, título ou email sem uma regra de reconciliação.

## 2. Endereços centralizados

Origem: `endereco_empresa`, `endereco_granja` e `endereco_proprietario`. Destino: `addresses`.

| Pré | Novo | Transformação |
| --- | --- | --- |
| `cep` | `zip_code` | Texto; preservar zeros à esquerda. |
| `numero` | `number` | Converter o inteiro para texto. |
| `municipio` | `city` | Validar preenchimento; obrigatório no destino. |
| `estado` | `state` | Normalizar para UF com duas letras. |
| `pais` (string, conforme informado pelo usuário) | `country` | Converter o texto para o código de duas letras do país; por exemplo, Brasil → BR. |

`logradouro` não tem coluna correspondente no esquema novo e não entra na carga de negócio deste escopo.

- Empresas: resolver `endereco_empresa.id_empresa` e gravar `enterprises.id_address`.
- Granjas: resolver `endereco_granja.id_granja` e gravar `farms.id_address`.
- Proprietários: centralizar os endereços em `addresses` sem criar vínculo com `farm_owners`, conforme decisão do usuário. `id_proprietario` não será transformado em FK ou tabela de associação no destino.

Múltiplos endereços por empresa/granja: decisão em espera. Não selecionar um principal automaticamente. Centralização não implica deduplicação automática: CEP e número iguais não comprovam que dois endereços representam o mesmo local.

## 3. Administradores fora do escopo

Não extrair nem migrar `administrador` do pré para `adms`, conforme orientação mais recente. A tabela e os administradores existentes no destino não serão alterados pelo RPA.

## 4. Dicas e avaliações

`dica → tips`:

- `titulo → tip`, pois o destino possui `tips.tip`, não uma coluna `title`.
- Não importar `descricao`, conforme a seleção atual.
- Resolver `dica.id_granja` pelo mapa de granjas.
- Criar `farms_tips(id_farm, id_tip)` usando os novos IDs.

`avaliacao → reviews`:

- `comentario → comment`.
- `nota → rating`.
- `id_dica → id_tip`, resolvido pelo mapa de dicas.

Inserir dicas antes de avaliações. Avaliações sem uma dica de origem migrável ficam pendentes; não associar a outra dica pelo título. Categorias não estão no escopo e não são necessárias para inserir diretamente dicas e seus vínculos com granjas.

## 5. Empresas

`empresa → enterprises`:

- `nome → name`.
- `email_corporativo → email`.
- `cnpj → document_number`.
- Endereço resolvido pela tabela `endereco_empresa → id_address`.
- `telefone_corporativo → telephone`: complemento necessário, porque o destino exige esse campo e a origem o fornece, embora tenha sido omitido da lista selecionada.

Normalizar CNPJ e telefone como texto, preservando zeros. Não criar validação específica de tamanho para emails/títulos nem truncá-los, conforme orientação do usuário. Enviar os textos integrais; as constraints existentes do destino continuam sendo aplicadas pelo próprio banco.

## 6. Funcionários

`funcionario → company_employees`:

- `nome → name`.
- `cpf → document_number`.
- `email → email`.
- `senha → password`: copiar diretamente a string armazenada, conforme confirmação do usuário. A passagem de `VARCHAR` para `TEXT` preserva o conteúdo.
- `id_empresa → id_enterprise`, pelo mapa de empresas.
- Último `telefone_funcionario.telefone → telephone`, filtrando por `id_funcionario` e ordenando `telefone_funcionario.id DESC LIMIT 1`.

Selecionar o telefone pelo ID antigo do funcionário, ordenar por `id DESC` e pegar a primeira linha, usando a mesma lógica de `telefone_proprietario`. Sem telefone, gravar `telephone = NULL`. Usar subconsulta escalar, `LEFT JOIN LATERAL` ou extração separada para não excluir funcionários sem telefone. O esquema novo precisa permitir esse `NULL` antes da carga; a alteração fica planejada, sem aplicação neste documento.

Senhas: regra confirmada de cópia direta para funcionários e proprietários. Preservar exatamente o valor de origem, sem aplicar novo hash, decodificar ou gerar outra credencial. `setor` não entra na carga selecionada.

## 7. Granjas

`granja → farms`:

- `nome → name`.
- `regiao → region`.
- `area_propriedade → area_property`.
- Endereço resolvido pela tabela `endereco_granja → id_address`.
- `id_empresa → id_enterprise`, pelo mapa de empresas.
- Quantidade calculada de aves → `chickens_now`, conforme regra confirmada abaixo.

**Capacidade:** ignorar `capacidade_aves`/`poultry_capacity`, conforme orientação mais recente do usuário. Esse campo sai do escopo de importação.

**Cálculo confirmado:** para cada granja, usar `SUM(galinhas_recebidas) - SUM(galinhas_entregadas)` sobre todos os lotes associados a ela, sem filtrar pela data de entrega. Granjas sem lotes recebem zero. Usar `COALESCE` nos agregados para representar esse caso.

```sql
SELECT
    g.id AS legacy_farm_id,
    COALESCE(SUM(l.galinhas_recebidas), 0)
      - COALESCE(SUM(l.galinhas_entregadas), 0) AS chickens_now
FROM granja g
LEFT JOIN lote l ON l.id_granja = g.id
GROUP BY g.id;
```

Aplicar o resultado antes de juntar telefones ou endereços, para que relacionamentos com várias linhas não multipliquem as quantidades somadas. Não subtrair `losts` novamente: o usuário definiu o saldo exclusivamente pelas duas somas acima.

## 8. Lotes

`lote → lots`:

- `galinhas_entregadas → delivered_chickens`.
- `galinhas_recebidas → received_chickens`.
- `dt_entrega → delivery_date`.
- `id_granja → id_farm`, pelo mapa de granjas.
- `lote.id_granja → granja.id_empresa → id_enterprise`, pelos mapas correspondentes.
- `galinhas_entregadas * 50 → cost`, conforme regra confirmada.
- `galinhas_recebidas - galinhas_entregadas → losts`, conforme inversão confirmada pelo usuário.
- `ganho`: não é a fonte de `cost`; ver abaixo.

**Perdas:** usar `galinhas_recebidas - galinhas_entregadas` para cada lote importado, sem acrescentar filtro de lote encerrado. Exemplo: 100 recebidas e 90 entregues resultam em `losts = 10`.

**Custo:** usar `galinhas_entregadas * 50` para cada lote. Exemplo: 90 entregues resultam em `cost = 4500`. O multiplicador é o valor literal 50 informado pelo usuário, sem conversão para 0,50. Um lote com zero aves entregues terá `cost = 0`.

**Ganho:** em espera, conforme decisão do usuário. Não incluir esse campo na carga de negócio atual nem copiá-lo para `cost`, que tem cálculo próprio.

**Lotes abertos:** migrar `dt_entrega = NULL` como `delivery_date = NULL`. A remoção de `NOT NULL` está incluída na preparação do destino descrita na seção 15; sua execução permanece pendente. Não substituir a data pela de chegada ou nascimento.

`dt_nascimento` e `dt_chegada` não entram na carga de negócio selecionada.

## 9. Metas

Origem: `meta`. Usar `is_individual` para encaminhar cada registro.

Campos comuns:

- `titulo → title`.
- `descricao → description`.
- `status → status`.
- `valor_alvo → target_value`.
- `tipo_meta → type`: complemento necessário porque as tabelas de metas do destino exigem `type`, embora não tenha sido listado na seleção.

### Individuais

Para `is_individual = TRUE`, inserir em `individual_goals` e resolver `id_granja → id_farm`. O DDL do pré exige uma granja para esse ramo.

### Coletivas

Para `is_individual = FALSE`, inserir em `state_goals`. O DDL do pré exige `id_granja IS NULL` nesse ramo; não existe uma granja de origem para copiar. No DDL atual do destino, `state_goals` já não possui `id_farm`, e o vínculo de abrangência usa `farm_goals`.

Estruturar a região nesta ordem:

1. Inserir `state_goals` e obter o ID da meta.
2. Quando houver `regiao`, inserir `regions_goals(region, id_goal)`.
3. Inserir `state_goal_regions(id_goal, id_region)` com os IDs anteriores.
4. Verificar os vínculos por IDs: a meta antiga deve corresponder à nova meta registrada no mapa; `regions_goals.id_goal` deve apontar para essa meta, e `state_goal_regions.id_goal` deve coincidir com `regions_goals.id_goal` da região vinculada. Conferir também o texto da região com o valor da origem.

Resolver `id_granja` pelo mapa de granjas quando esse relacionamento existir na origem. Metas coletivas do DDL fornecido exigem `id_granja = NULL`; não criar `farm_goals` presumindo que o ID da meta representa uma granja de mesmo número. A instrução de usar IDs é aplicada aos vínculos reais entre meta, granja e região, seguida da verificação de `regions_goals`.

`date_end` pode receber `NULL` no destino atual. `date_creation` usa o default de criação no destino e não comprova uma data histórica de criação. `estado` não foi selecionado para carga.

Migrar títulos integrais sem validação específica de tamanho ou truncamento. Usar o mapeamento de status confirmado para metas individuais e coletivas:

| Status no pré, conforme DDL fornecido | Status no destino, informado pelo usuário |
| --- | --- |
| `NAO_INICIADA` | `Pendente` |
| `EM_ANDAMENTO` | `Em andamento` |
| `FINALIZADA` | `Concluída` |

Se a origem já contiver esses textos do destino, preservá-los. Valores diferentes dessas equivalências devem ser registrados para conferência, sem atribuir um status arbitrário.

## 10. Proprietários

`proprietario_granja → farm_owners`:

- `nome → name`.
- `cpf → document_number`.
- `senha → password`, copiando diretamente o conteúdo armazenado.
- `email → email`.
- `id_granja → id_farm`, pelo mapa de granjas.
- `telefone_proprietario.telefone → telephone`, filtrando por `id_proprietario` e ordenando `telefone_proprietario.id DESC LIMIT 1`.
- `first_access = FALSE`, conforme pedido. Esse é o nome da coluna no novo esquema.
- `foto_url = NULL`, conforme pedido.

Regra confirmada para os dois tipos de usuário: filtrar pelo ID antigo do usuário na respectiva tabela de telefone, ordenar por `id DESC` e selecionar a primeira linha (`LIMIT 1`). Para funcionário, usar `id_funcionario`; para proprietário, usar `id_proprietario`. Não buscar o telefone por email, nome ou ID gerado no banco novo. O telefone do proprietário é anulável no DDL atual; ausência pode ser representada como `NULL`.

`email_verificado` não foi selecionado e não será convertido em `first_access`.

## 11. Água e energia

`registro_agua → water_registries`:

- `dt_registro → registration_date`, preservando data e horário em `TIMESTAMP WITHOUT TIME ZONE`, como no DDL do pré.
- `hidrometro_inicio → start_hydrometer`.
- `hidrometro_final → end_hydrometer`.
- `registro_agua.id_lote → lote.id_granja → id_farm`, pelo mapa de granjas.

`registro_energia → energy_registries`:

- `dt_registro → registration_date`, preservando data e horário em `TIMESTAMP WITHOUT TIME ZONE`, como no DDL do pré.
- `consumo → energy_consumption`.
- `registro_energia.id_lote → lote.id_granja → id_farm`, pelo mapa de granjas.

A granja é obtida do lote antigo mesmo quando o lote ainda não pôde ser carregado no destino. Preservar essa procedência no controle técnico da migração.

A mudança planejada de `registration_date` para `TIMESTAMP` preserva o horário do pré e evita colisões causadas exclusivamente pela redução de data/hora para dia. Por exemplo, dois registros de energia da mesma granja e com consumo 100, um às 08:00 e outro às 18:00 do mesmo dia, continuam distintos no índice único que inclui `registration_date`.

Conferir ainda coincidências exatas nos campos dos índices únicos: para energia, granja + data/hora completa + consumo; para água, granja + data/hora completa + leitura inicial + leitura final. IDs gerados diferentes não eliminam esse conflito. Não descartar nem agregar automaticamente registros legítimos para contornar a restrição.

Não criar tratamento específico para valores zero de água/energia, conforme decisão do usuário. Enviar os valores originais, com conversão de tipo quando necessária, mantendo as constraints existentes do banco. Confirmar as unidades antes de converter os valores.

## 12. Ordem da carga

1. Todos os endereços centralizados, incluindo endereços pessoais sem vínculo com proprietários.
2. Empresas.
3. Granjas, com `chickens_now = SUM(recebidas) - SUM(entregues)` por granja.
4. Funcionários e proprietários.
5. Dicas e `farms_tips`.
6. Avaliações.
7. Lotes.
8. Registros de água e energia.
9. Metas individuais e coletivas, regiões e verificação dos vínculos por IDs.

Cada inserção e seu registro no mapa de IDs devem ocorrer na mesma transação. Repetir a carga deve reutilizar os IDs já associados. Relatar separadamente os registros carregados, reutilizados e pendentes, incluindo os dependentes de entidades bloqueadas.

## 13. Conversões de tipos

Aplicar conversões explícitas quando os tipos de origem e destino diferirem, preservando `NULL` e usando parâmetros SQL na escrita:

| Origem | Destino | Conversão |
| --- | --- | --- |
| `endereco_*.numero INT` | `addresses.number VARCHAR` | Inteiro para texto. |
| `endereco_*.pais` string | `addresses.country VARCHAR(2)` | Código textual de duas letras, usando equivalência de país quando necessário. |
| `endereco_*.estado VARCHAR(50)` | `addresses.state VARCHAR(2)` | Converter nome/sigla para UF de duas letras. |
| Senhas `VARCHAR` | Senhas `TEXT` | Preservar a string/hash; não reaplicar hash na conversão. |
| `registro_*.dt_registro TIMESTAMP` | `registration_date TIMESTAMP` | Preservar data e horário, sem conversão para `DATE` nem string com formato regional. |
| Valores `DECIMAL` | Campos `NUMERIC` | Preservar valor e precisão usando tipos decimais compatíveis. |
| `galinhas_entregadas * 50` | `lots.cost DOUBLE PRECISION` | Calcular em tipo com capacidade suficiente e converter para o tipo do destino. |
| Resultado de `SUM(INT)` | `farms.chickens_now INTEGER` | Converter o saldo agregado para inteiro; não aplicar a soma após joins que multipliquem os lotes. |
| Flags booleanas | Flags booleanas | Usar valores booleanos, por exemplo `first_access = FALSE`. |

Conversão de tipo não implica cortar emails/títulos, substituir valores zero ou fabricar dados ausentes.

## 14. Decisões em espera

- Múltiplos endereços de uma empresa/granja: seleção do endereço principal em espera.
- `ganho`: carga em espera; `cost` permanece `galinhas_entregadas * 50`.

## 15. Preparação restante da execução

As alterações de banco desta seção devem compor a branch e a PR da etapa inicial. A implementação do código do RPA começa somente após a validação e o merge dessa PR pelo usuário.

### Remover NOT NULL antes da carga

Incluir em uma migration SQL separada os comandos:

```sql
ALTER TABLE lots ALTER COLUMN delivery_date DROP NOT NULL;
ALTER TABLE company_employees ALTER COLUMN telephone DROP NOT NULL;
```

Registrar a migration no `config.yaml` com `mode: once` e alinhar as definições de bancos novos em `sql/banco_ouros_fisico.sql`, removendo `NOT NULL` desses dois campos. Aplicar antes da carga para aceitar lotes ainda não entregues e funcionários sem telefone. Este turno inclui os comandos apenas no plano; scripts SQL e banco não foram alterados.

### Preservar o horário dos registros de água e energia

Alterar `registration_date` de `DATE` para `TIMESTAMP WITHOUT TIME ZONE` nas duas tabelas, antes da carga. Registrar em migration separada:

```sql
ALTER TABLE water_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP WITHOUT TIME ZONE
    USING registration_date::TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE energy_registries
    ALTER COLUMN registration_date TYPE TIMESTAMP WITHOUT TIME ZONE
    USING registration_date::TIMESTAMP WITHOUT TIME ZONE;
```

Alinhar também o DDL de bancos novos em `sql/banco_ouros_fisico.sql` e registrar a migration no `config.yaml` com `mode: once`. Datas já armazenadas como `DATE` passam a ter horário 00:00:00; a mudança de tipo não recupera horários anteriormente descartados.

Antes da implementação, levantar as views e demais dependências de `registration_date` para preparar sua recriação quando necessária à alteração do tipo. Conferir casts, parâmetros e variáveis `DATE` dos caminhos de importação que forem utilizados, incluindo `sql/midas-resource-import.sql`, para que preservem o horário recebido. O RPA deve enviar o timestamp completo em ambas as inserções. A alteração está somente no plano; scripts SQL e banco não foram modificados.

### Conferência da carga

- Conferir vínculos pelos IDs retornados nas novas inserções, especialmente meta/região e dica/avaliação.
- Conferir coincidências exatas de data/hora e demais campos usados pelos índices únicos, preservando o timestamp completo. IDs novos não evitam colisões nessas combinações. Não descartar registros legítimos nem agregá-los automaticamente para contornar a restrição.
- Executar diagnóstico, simulação e reconciliação antes da carga final.
