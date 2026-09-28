-- Catálogo semântico do esquema. Os comandos COMMENT são reaplicáveis e não
-- alteram linhas de negócio. Pode ser consultado com COMMENT ON ou pelas
-- funções obj_description() e col_description() do PostgreSQL.

-- Entidades principais
COMMENT ON TABLE public.addresses IS 'Endereços de empresas e fazendas. A carga inicial contém endereços de demonstração.';
COMMENT ON COLUMN public.addresses.id IS 'Identificador interno do endereço.';
COMMENT ON COLUMN public.addresses.zip_code IS 'CEP ou código postal do endereço.';
COMMENT ON COLUMN public.addresses.state IS 'Sigla do estado ou província.';
COMMENT ON COLUMN public.addresses.city IS 'Cidade do endereço.';
COMMENT ON COLUMN public.addresses.number IS 'Número, complemento ou indicação de ausência de número.';
COMMENT ON COLUMN public.addresses.country IS 'Código de duas letras do país.';
COMMENT ON COLUMN public.addresses.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.enterprises IS 'Empresas às quais fazendas, funcionários e planos podem estar associados.';
COMMENT ON COLUMN public.enterprises.id IS 'Identificador interno da empresa.';
COMMENT ON COLUMN public.enterprises.name IS 'Nome da empresa.';
COMMENT ON COLUMN public.enterprises.email IS 'E-mail de contato cadastrado para a empresa.';
COMMENT ON COLUMN public.enterprises.document_number IS 'Documento empresarial, como CNPJ.';
COMMENT ON COLUMN public.enterprises.telephone IS 'Telefone de contato da empresa.';
COMMENT ON COLUMN public.enterprises.id_address IS 'Endereço da empresa; referencia addresses.id.';
COMMENT ON COLUMN public.enterprises.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.farms IS 'Fazendas ou granjas cadastradas e seus dados de localização e capacidade.';
COMMENT ON COLUMN public.farms.id IS 'Identificador interno da fazenda.';
COMMENT ON COLUMN public.farms.name IS 'Nome ou identificação da fazenda.';
COMMENT ON COLUMN public.farms.area_property IS 'Área total da propriedade, em unidade definida pela aplicação.';
COMMENT ON COLUMN public.farms.region IS 'Região geográfica usada pela aplicação.';
COMMENT ON COLUMN public.farms.poultry_capacity IS 'Capacidade de alojamento de aves.';
COMMENT ON COLUMN public.farms.place IS 'Localidade ou município informado para a fazenda.';
COMMENT ON COLUMN public.farms.chickens_now IS 'Quantidade atual de aves; padrão zero.';
COMMENT ON COLUMN public.farms.foto_url IS 'URL da foto da fazenda, quando disponível.';
COMMENT ON COLUMN public.farms.id_address IS 'Endereço da fazenda; referencia addresses.id.';
COMMENT ON COLUMN public.farms.id_enterprise IS 'Empresa associada; referencia enterprises.id.';
COMMENT ON COLUMN public.farms.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.farm_owners IS 'Produtores ou proprietários associados a uma fazenda.';
COMMENT ON COLUMN public.farm_owners.id IS 'Identificador interno do proprietário.';
COMMENT ON COLUMN public.farm_owners.name IS 'Nome do proprietário; pode estar ausente durante o cadastro.';
COMMENT ON COLUMN public.farm_owners.password IS 'Credencial de autenticação armazenada pela aplicação.';
COMMENT ON COLUMN public.farm_owners.email IS 'E-mail de autenticação ou contato do proprietário.';
COMMENT ON COLUMN public.farm_owners.document_number IS 'Documento pessoal do proprietário; campo opcional.';
COMMENT ON COLUMN public.farm_owners.telephone IS 'Telefone do proprietário; campo opcional.';
COMMENT ON COLUMN public.farm_owners.first_access IS 'Indica se o usuário ainda está no primeiro acesso.';
COMMENT ON COLUMN public.farm_owners.foto_url IS 'URL da foto do proprietário, quando disponível.';
COMMENT ON COLUMN public.farm_owners.id_farm IS 'Fazenda associada; referencia farms.id.';
COMMENT ON COLUMN public.farm_owners.keycloak_user_id IS 'UUID opcional que associa o proprietário a um usuário Keycloak.';

COMMENT ON TABLE public.company_employees IS 'Funcionários vinculados a uma empresa.';
COMMENT ON COLUMN public.company_employees.id IS 'Identificador interno do funcionário.';
COMMENT ON COLUMN public.company_employees.name IS 'Nome do funcionário.';
COMMENT ON COLUMN public.company_employees.document_number IS 'Documento pessoal único do funcionário.';
COMMENT ON COLUMN public.company_employees.email IS 'E-mail de autenticação ou contato do funcionário.';
COMMENT ON COLUMN public.company_employees.telephone IS 'Telefone do funcionário.';
COMMENT ON COLUMN public.company_employees.password IS 'Credencial de autenticação armazenada pela aplicação.';
COMMENT ON COLUMN public.company_employees.id_enterprise IS 'Empresa empregadora; referencia enterprises.id.';
COMMENT ON COLUMN public.company_employees.keycloak_user_id IS 'UUID opcional que associa o funcionário a um usuário Keycloak.';

COMMENT ON TABLE public.adms IS 'Contas administrativas da aplicação.';
COMMENT ON COLUMN public.adms.id IS 'Identificador interno da conta administrativa.';
COMMENT ON COLUMN public.adms.email IS 'E-mail de autenticação ou contato do administrador.';
COMMENT ON COLUMN public.adms.password IS 'Credencial de autenticação armazenada pela aplicação.';
COMMENT ON COLUMN public.adms.keycloak_user_id IS 'UUID opcional que associa o administrador a um usuário Keycloak.';

-- Operação das fazendas
COMMENT ON TABLE public.lots IS 'Lotes de aves recebidos e entregues por empresa e fazenda.';
COMMENT ON COLUMN public.lots.id IS 'Identificador interno do lote.';
COMMENT ON COLUMN public.lots.received_chickens IS 'Quantidade de aves recebidas no lote.';
COMMENT ON COLUMN public.lots.delivered_chickens IS 'Quantidade de aves entregues no lote.';
COMMENT ON COLUMN public.lots.delivery_date IS 'Data de entrega do lote.';
COMMENT ON COLUMN public.lots.losts IS 'Quantidade de aves perdidas; padrão zero.';
COMMENT ON COLUMN public.lots.cost IS 'Custo registrado para o lote; padrão zero.';
COMMENT ON COLUMN public.lots.id_enterprise IS 'Empresa associada; referencia enterprises.id.';
COMMENT ON COLUMN public.lots.id_farm IS 'Fazenda associada; referencia farms.id.';
COMMENT ON COLUMN public.lots.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.chicken_left IS 'Registros de saídas ou perdas de aves por fazenda.';
COMMENT ON COLUMN public.chicken_left.id IS 'Identificador interno do registro.';
COMMENT ON COLUMN public.chicken_left.chickens_count IS 'Quantidade de aves que saíram.';
COMMENT ON COLUMN public.chicken_left.exit_date IS 'Data da saída das aves.';
COMMENT ON COLUMN public.chicken_left.id_farm IS 'Fazenda de origem; referencia farms.id.';

COMMENT ON TABLE public.water_registries IS 'Leituras inicial e final do hidrômetro por fazenda e data.';
COMMENT ON COLUMN public.water_registries.id IS 'Identificador interno da leitura.';
COMMENT ON COLUMN public.water_registries.registration_date IS 'Data da leitura de água.';
COMMENT ON COLUMN public.water_registries.start_hydrometer IS 'Leitura inicial cumulativa do hidrômetro.';
COMMENT ON COLUMN public.water_registries.end_hydrometer IS 'Leitura final cumulativa do hidrômetro; deve ser maior ou igual à inicial.';
COMMENT ON COLUMN public.water_registries.id_farm IS 'Fazenda da leitura; referencia farms.id.';
COMMENT ON COLUMN public.water_registries.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.energy_registries IS 'Consumo de energia registrado por fazenda e data.';
COMMENT ON COLUMN public.energy_registries.id IS 'Identificador interno do registro.';
COMMENT ON COLUMN public.energy_registries.registration_date IS 'Data do registro de energia.';
COMMENT ON COLUMN public.energy_registries.energy_consumption IS 'Consumo de energia registrado, normalmente expresso em kWh.';
COMMENT ON COLUMN public.energy_registries.id_farm IS 'Fazenda do registro; referencia farms.id.';
COMMENT ON COLUMN public.energy_registries.updated_at IS 'Data e hora da última atualização da linha.';

-- Metas, dicas e avaliações
COMMENT ON TABLE public.individual_goals IS 'Metas individuais de uma fazenda.';
COMMENT ON COLUMN public.individual_goals.id IS 'Identificador interno da meta.';
COMMENT ON COLUMN public.individual_goals.description IS 'Descrição opcional da meta.';
COMMENT ON COLUMN public.individual_goals.type IS 'Tipo ou indicador da meta.';
COMMENT ON COLUMN public.individual_goals.status IS 'Situação atual da meta.';
COMMENT ON COLUMN public.individual_goals.target_value IS 'Valor que se pretende atingir.';
COMMENT ON COLUMN public.individual_goals.title IS 'Título curto da meta.';
COMMENT ON COLUMN public.individual_goals.id_farm IS 'Fazenda responsável pela meta; referencia farms.id.';
COMMENT ON COLUMN public.individual_goals.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.state_goals IS 'Metas estaduais ou compartilhadas relacionadas a fazendas.';
COMMENT ON COLUMN public.state_goals.id IS 'Identificador interno da meta.';
COMMENT ON COLUMN public.state_goals.description IS 'Descrição opcional da meta.';
COMMENT ON COLUMN public.state_goals.type IS 'Tipo ou indicador da meta.';
COMMENT ON COLUMN public.state_goals.status IS 'Situação atual da meta.';
COMMENT ON COLUMN public.state_goals.target_value IS 'Valor que se pretende atingir.';
COMMENT ON COLUMN public.state_goals.title IS 'Título curto da meta.';
COMMENT ON COLUMN public.state_goals.date_creation IS 'Data e hora de criação; padrão no momento da inserção.';
COMMENT ON COLUMN public.state_goals.date_end IS 'Data e hora limite; não pode anteceder a criação.';
COMMENT ON COLUMN public.state_goals.id_farm IS 'Fazenda associada; referencia farms.id.';
COMMENT ON COLUMN public.state_goals.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.regions_goals IS 'Regiões associadas a metas estaduais.';
COMMENT ON COLUMN public.regions_goals.id IS 'Identificador interno da associação regional.';
COMMENT ON COLUMN public.regions_goals.region IS 'Nome da região.';
COMMENT ON COLUMN public.regions_goals.id_goal IS 'Meta associada; referencia state_goals.id.';
COMMENT ON COLUMN public.regions_goals.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.farm_goals IS 'Associação entre fazendas e metas estaduais.';
COMMENT ON COLUMN public.farm_goals.id IS 'Identificador interno da associação.';
COMMENT ON COLUMN public.farm_goals.id_farm IS 'Fazenda associada; referencia farms.id.';
COMMENT ON COLUMN public.farm_goals.id_goal IS 'Meta associada; referencia state_goals.id.';
COMMENT ON COLUMN public.farm_goals.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.state_goal_regions IS 'Associação entre metas e registros regionais.';
COMMENT ON COLUMN public.state_goal_regions.id IS 'Identificador interno da associação.';
COMMENT ON COLUMN public.state_goal_regions.id_goal IS 'Meta estadual; referencia state_goals.id.';
COMMENT ON COLUMN public.state_goal_regions.id_region IS 'Registro regional; referencia regions_goals.id.';
COMMENT ON COLUMN public.state_goal_regions.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.tips IS 'Dicas de uso e boas práticas.';
COMMENT ON COLUMN public.tips.id IS 'Identificador interno da dica.';
COMMENT ON COLUMN public.tips.tip IS 'Texto da dica.';
COMMENT ON COLUMN public.tips.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.categories IS 'Categorias usadas para organizar dicas.';
COMMENT ON COLUMN public.categories.id IS 'Identificador interno da categoria.';
COMMENT ON COLUMN public.categories.category IS 'Nome da categoria.';
COMMENT ON COLUMN public.categories.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.tip_categories IS 'Associação entre dicas e categorias; cada par é único.';
COMMENT ON COLUMN public.tip_categories.id IS 'Identificador interno da associação.';
COMMENT ON COLUMN public.tip_categories.id_tip IS 'Dica associada; referencia tips.id.';
COMMENT ON COLUMN public.tip_categories.id_category IS 'Categoria associada; referencia categories.id.';
COMMENT ON COLUMN public.tip_categories.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.farms_tips IS 'Associação entre fazendas e dicas; cada par é único.';
COMMENT ON COLUMN public.farms_tips.id IS 'Identificador interno da associação.';
COMMENT ON COLUMN public.farms_tips.id_farm IS 'Fazenda associada; referencia farms.id.';
COMMENT ON COLUMN public.farms_tips.id_tip IS 'Dica associada; referencia tips.id.';

COMMENT ON TABLE public.reviews IS 'Avaliações e comentários associados a dicas.';
COMMENT ON COLUMN public.reviews.id IS 'Identificador interno da avaliação.';
COMMENT ON COLUMN public.reviews.comment IS 'Comentário da avaliação.';
COMMENT ON COLUMN public.reviews.rating IS 'Nota numérica não negativa.';
COMMENT ON COLUMN public.reviews.id_tip IS 'Dica avaliada; referencia tips.id.';
COMMENT ON COLUMN public.reviews.updated_at IS 'Data e hora da última atualização da linha.';

-- Planos e pagamentos
COMMENT ON TABLE public.plans IS 'Planos comerciais disponíveis para empresas.';
COMMENT ON COLUMN public.plans.id IS 'Identificador interno do plano.';
COMMENT ON COLUMN public.plans.title IS 'Nome único do plano.';
COMMENT ON COLUMN public.plans.duration_days IS 'Duração do plano em dias.';
COMMENT ON COLUMN public.plans.description IS 'Descrição do plano.';
COMMENT ON COLUMN public.plans.price IS 'Preço do plano.';
COMMENT ON COLUMN public.plans.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.enterprise_plans IS 'Planos contratados por empresas.';
COMMENT ON COLUMN public.enterprise_plans.id IS 'Identificador interno da contratação.';
COMMENT ON COLUMN public.enterprise_plans.id_enterprise IS 'Empresa contratante; referencia enterprises.id.';
COMMENT ON COLUMN public.enterprise_plans.id_plan IS 'Plano contratado; referencia plans.id.';
COMMENT ON COLUMN public.enterprise_plans.updated_at IS 'Data e hora da última atualização da linha.';

COMMENT ON TABLE public.payments IS 'Pagamentos vinculados a uma empresa e a um plano contratado.';
COMMENT ON COLUMN public.payments.id IS 'Identificador interno do pagamento.';
COMMENT ON COLUMN public.payments.type IS 'Tipo ou meio de pagamento.';
COMMENT ON COLUMN public.payments.value IS 'Valor pago.';
COMMENT ON COLUMN public.payments.date_creation IS 'Data e hora de criação do pagamento.';
COMMENT ON COLUMN public.payments.id_enterprise IS 'Empresa pagadora; participa da chave estrangeira composta.';
COMMENT ON COLUMN public.payments.id_enterprise_plan IS 'Contratação do plano; participa da chave estrangeira composta.';
COMMENT ON COLUMN public.payments.updated_at IS 'Data e hora da última atualização da linha.';

-- Histórico de alterações; as linhas são imagens de INSERT, UPDATE ou DELETE.
COMMENT ON TABLE public.farms_log IS 'Histórico de imagens das fazendas após inserção, atualização ou exclusão.';
COMMENT ON COLUMN public.farms_log.id IS 'ID original da fazenda, sem chave primária nesta tabela de histórico.';
COMMENT ON COLUMN public.farms_log.name IS 'Nome da fazenda no evento registrado.';
COMMENT ON COLUMN public.farms_log.area_property IS 'Área da propriedade no evento registrado.';
COMMENT ON COLUMN public.farms_log.region IS 'Região da fazenda no evento registrado.';
COMMENT ON COLUMN public.farms_log.poulty_capacity IS 'Capacidade de aves; nome legado usado nesta tabela de histórico.';
COMMENT ON COLUMN public.farms_log.place IS 'Localidade da fazenda no evento registrado.';
COMMENT ON COLUMN public.farms_log.chickens_now IS 'Quantidade atual de aves no evento registrado.';
COMMENT ON COLUMN public.farms_log.id_adress IS 'ID do endereço; nome legado usado nesta tabela de histórico.';
COMMENT ON COLUMN public.farms_log.id_enterprise IS 'ID da empresa associada no evento registrado.';

COMMENT ON TABLE public.lots_log IS 'Histórico de imagens dos lotes após inserção, atualização ou exclusão.';
COMMENT ON COLUMN public.lots_log.id IS 'ID original do lote, sem chave primária nesta tabela de histórico.';
COMMENT ON COLUMN public.lots_log.received_chickens IS 'Quantidade recebida no evento registrado.';
COMMENT ON COLUMN public.lots_log.delivered_chickens IS 'Quantidade entregue no evento registrado.';
COMMENT ON COLUMN public.lots_log.delivery_date IS 'Data de entrega no evento registrado.';
COMMENT ON COLUMN public.lots_log.losts IS 'Perdas no evento registrado.';
COMMENT ON COLUMN public.lots_log.cost IS 'Custo no evento registrado.';
COMMENT ON COLUMN public.lots_log.id_enterprise IS 'ID da empresa no evento registrado.';
COMMENT ON COLUMN public.lots_log.id_farm IS 'ID da fazenda no evento registrado.';

COMMENT ON TABLE public.payments_log IS 'Histórico de imagens dos pagamentos após inserção, atualização ou exclusão.';
COMMENT ON COLUMN public.payments_log.id IS 'ID original do pagamento, sem chave primária nesta tabela de histórico.';
COMMENT ON COLUMN public.payments_log.type IS 'Tipo do pagamento no evento registrado.';
COMMENT ON COLUMN public.payments_log.value IS 'Valor do pagamento no evento registrado.';
COMMENT ON COLUMN public.payments_log.date_creation IS 'Data de criação do pagamento no evento registrado.';
COMMENT ON COLUMN public.payments_log.id_enterprise IS 'ID da empresa no evento registrado.';

-- Controle de versão e execução dos scripts
COMMENT ON TABLE public.controle_versoes IS 'Registro de cada execução bem-sucedida do executor SQL.';
COMMENT ON COLUMN public.controle_versoes.id IS 'Identificador interno da linha de versão.';
COMMENT ON COLUMN public.controle_versoes.versao IS 'Número sequencial único da execução.';
COMMENT ON COLUMN public.controle_versoes.commit_id IS 'SHA do commit aplicado.';
COMMENT ON COLUMN public.controle_versoes.comentario_commit IS 'Mensagem do commit aplicado.';
COMMENT ON COLUMN public.controle_versoes.aplicado_em IS 'Data e hora em que a execução foi registrada.';

COMMENT ON TABLE public.controle_scripts_sql IS 'Controle por arquivo SQL, mantido pelo executor apply_sql.py.';
COMMENT ON COLUMN public.controle_scripts_sql.arquivo IS 'Caminho relativo do arquivo SQL na pasta configurada.';
COMMENT ON COLUMN public.controle_scripts_sql.checksum IS 'Checksum SHA-256 do conteúdo SQL executado.';
COMMENT ON COLUMN public.controle_scripts_sql.commit_id IS 'SHA do commit associado à execução do arquivo.';
COMMENT ON COLUMN public.controle_scripts_sql.executado_em IS 'Data e hora da execução mais recente do arquivo.';

-- Importação histórica no esquema Midas
COMMENT ON TABLE midas.resource_import_requests IS 'Recibo idempotente e resultado de cada solicitação de importação histórica.';
COMMENT ON COLUMN midas.resource_import_requests.request_id IS 'UUID da solicitação e chave de idempotência.';
COMMENT ON COLUMN midas.resource_import_requests.actor_user_type IS 'Tipo de usuário que iniciou a solicitação.';
COMMENT ON COLUMN midas.resource_import_requests.actor_user_id IS 'ID do usuário que iniciou a solicitação.';
COMMENT ON COLUMN midas.resource_import_requests.source_type IS 'Tipo da fonte dos dados importados.';
COMMENT ON COLUMN midas.resource_import_requests.source_name IS 'Nome informado para a fonte dos dados.';
COMMENT ON COLUMN midas.resource_import_requests.payload_sha256 IS 'SHA-256 hexadecimal do conteúdo recebido.';
COMMENT ON COLUMN midas.resource_import_requests.status IS 'Resultado: accepted ou rejected.';
COMMENT ON COLUMN midas.resource_import_requests.received_count IS 'Quantidade de registros recebidos.';
COMMENT ON COLUMN midas.resource_import_requests.inserted_count IS 'Quantidade de registros inseridos.';
COMMENT ON COLUMN midas.resource_import_requests.skipped_duplicates IS 'Quantidade de duplicatas ignoradas.';
COMMENT ON COLUMN midas.resource_import_requests.rejected_count IS 'Quantidade de registros rejeitados.';
COMMENT ON COLUMN midas.resource_import_requests.errors IS 'Detalhes de validação em JSON; padrão é uma lista vazia.';
COMMENT ON COLUMN midas.resource_import_requests.schema_version IS 'Versão do contrato de importação.';
COMMENT ON COLUMN midas.resource_import_requests.created_at IS 'Data e hora de recebimento da solicitação.';
COMMENT ON COLUMN midas.resource_import_requests.completed_at IS 'Data e hora de conclusão da solicitação.';

COMMENT ON TABLE midas.importer_identities IS 'Vínculo entre roles técnicos de importação e proprietários de fazendas.';
COMMENT ON COLUMN midas.importer_identities.database_role IS 'Nome do role PostgreSQL que autentica o importador.';
COMMENT ON COLUMN midas.importer_identities.farm_owner_id IS 'Proprietário associado; referencia public.farm_owners.id.';

-- Views de indicadores
COMMENT ON TABLE public.chickens_per_liter IS 'Indicador de aves atuais por unidade de água consumida no mês anterior, por fazenda.';
COMMENT ON COLUMN public.chickens_per_liter.id_farm IS 'ID da fazenda do indicador.';
COMMENT ON COLUMN public.chickens_per_liter.chickens_per_liter IS 'Razão calculada entre aves atuais e consumo de água.';
COMMENT ON TABLE public.chickens_per_kwh IS 'Indicador de aves atuais por kWh consumido no mês anterior, por fazenda.';
COMMENT ON COLUMN public.chickens_per_kwh.id_farm IS 'ID da fazenda do indicador.';
COMMENT ON COLUMN public.chickens_per_kwh.chickens_per_kwh IS 'Razão calculada entre aves atuais e consumo de energia.';
COMMENT ON TABLE public.integrated_consumption IS 'Resumo integrado de consumo de água e energia por fazenda no mês anterior.';
COMMENT ON COLUMN public.integrated_consumption.id_farm IS 'ID da fazenda do indicador integrado.';
COMMENT ON COLUMN public.integrated_consumption.cgi IS 'Índice integrado de consumo de água e energia por ave.';

COMMENT ON INDEX public.idx_farm_owners_id_password_email IS 'Índice composto solicitado para id, password e email de proprietários.';
COMMENT ON INDEX public.idx_water_registries_id_hydrometers IS 'Índice composto solicitado para id e leituras do hidrômetro.';
COMMENT ON INDEX public.idx_energy_registries_id_consumption IS 'Índice composto solicitado para id e consumo de energia.';
