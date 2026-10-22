-- ============================================================================
-- Migration: Atualizacao do Catalogo de Dicas Tecnicas e Integracao Cloudinary
-- Catalogo Oficial de 32 Dicas Tecnicas Zootecnicas (Ouros App)
-- Modo: once
-- ============================================================================

-- 1. Evolucao da estrutura da tabela tips
ALTER TABLE tips
    ADD COLUMN IF NOT EXISTS title VARCHAR(200) NOT NULL DEFAULT 'Dica Operacional'
        CHECK (btrim(title) <> ''),
    ADD COLUMN IF NOT EXISTS image_url TEXT,
    ADD COLUMN IF NOT EXISTS foto_url TEXT;

ALTER TABLE tips ALTER COLUMN title TYPE VARCHAR(200);

-- 2. Insercao idempotente de categorias
INSERT INTO categories (category)
SELECT cat FROM (
    VALUES
        ('Alertas de Consumo'),
        ('Ambiência'),
        ('Bebedouros Eficientes'),
        ('Biosseguridade'),
        ('Consumo de Energia'),
        ('Consumo de Água'),
        ('Controle de Umidade'),
        ('Dados e Validação'),
        ('Economia Financeira'),
        ('Eficiência por Ave'),
        ('Equipamentos'),
        ('Histórico de Desempenho'),
        ('Iluminação Noturna'),
        ('Leitura de Hidrômetro'),
        ('Limpeza de Galpões'),
        ('Manejo de Cama'),
        ('Manutenção de Gerador'),
        ('Mortalidade e Bem-estar'),
        ('Planejamento de Lotes'),
        ('Qualidade da Ração'),
        ('Qualidade da Água'),
        ('Sanitização de Tubulações'),
        ('Suporte Técnico'),
        ('Sustentabilidade ESG'),
        ('Temperatura Inicial'),
        ('Velocidade do Ar'),
        ('Ventilação Mínima')
) AS v(cat)
WHERE NOT EXISTS (
    SELECT 1 FROM categories c WHERE c.category = v.cat
);

-- 3. Insercao idempotente das 32 Dicas Tecnicas Oficiais com Cloudinary URLs
INSERT INTO tips (title, tip, image_url, foto_url)
SELECT v.title, v.tip, v.image_url, v.foto_url
FROM (
    VALUES
        ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', '* **Diagnóstico Zootécnico:** Linhas de bebedouros posicionadas em altura incorreta causam graves prejuízos. Se estiverem baixas demais, as aves batem as asas e o dorso nos pinos ao se movimentarem, provocando gotejamento constante, umedecimento da cama e desperdício de milhares de litros de água tratada. Se estiverem altas demais, provocam restrição hídrica involuntária, desidratando o lote e derrubando o ganho de peso.
* **Procedimento Operacional Padrão (POP):**
  1. Nos primeiros 2 dias de vida, os bicos devem estar ligeiramente acima da altura dos olhos das pintainhas.
  2. Do 3º dia em diante, eleve as linhas diariamente para que o bico da ave forme um ângulo de **45°** com o corpo ereto.
  3. A partir dos 14 dias até o abate, o ângulo deve ser de **50° a 60°**, forçando o frango a esticar o pescoço suavemente para cima ao acionar o pino metálico.
  4. Calibre a coluna de pressão d''água no tubo de respiro: inicie com 10 a 15 cm de coluna nos primeiros dias e avance gradualmente para 25 a 35 cm nas aves adultas (vazão de 60 a 90 ml/min).
* **Impacto no Bolso e no Ranking Ouros:** Evita até 18% de desperdício invisível no hidrômetro. Cama seca reduz calos de pata e condenações em abatedouro, garantindo melhor pontuação rumo à Liga Ouro.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669251/ouros/tips/tip_01.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669251/ouros/tips/tip_01.webp'),
        ('Purgamento e Flushing Estruturado das Tubulações de Água', '* **Diagnóstico Zootécnico:** Ao longo do ciclo produtivo, a baixa velocidade da água e a passagem contínua de suplementos, vitaminas e vacinas geram um biofilme espesso nas paredes internas dos canos. Esse biofilme abriga colônias de bactérias patogênicas (*Salmonella* e *E. coli*) e trava as microesferas dos nipples, gerando entupimentos ou vazamentos contínuos.
* **Procedimento Operacional Padrão (POP):**
  1. No intervalo entre lotes (vazio sanitário), introduza solução desincrustante e sanitizante (peróxido de hidrogênio a 2%-3% ou cloro ativo) por toda a tubulação, deixando agir por 12 a 24 horas.
  2. Abra as válvulas e registros terminais de purga em cada linha e realize o *flushing* sob alta pressão (1,5 a 2,0 bar) até que a água saia totalmente cristalina e sem resíduos orgânicos.
  3. Durante o lote, faça descargas rápidas diárias de 1 a 2 minutos nas horas mais quentes da tarde para renovar a água parada e resfriá-la.
* **Impacto no Bolso e no Ranking Ouros:** Garante a vazão milimétrica e uniforme em todos os bicos do aviário, elimina surtos de diarreia bacteriana e zera perdas ocultas por goteiras.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669961/ouros/tips/tip_02.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669961/ouros/tips/tip_02.webp'),
        ('Monitoramento Contínuo e Correção do pH da Água de Bebida', '* **Diagnóstico Zootécnico:** A água de poço com pH alcalino (acima de 7.5) inativa a ação germicida do cloro (o ácido hipocloroso livre se dissocia em íon hipoclorito, cuja eficácia germicida é 80 vezes menor). Por outro lado, pH ácido demais (abaixo de 5.5) corrói vedações de bebedouros, agride a mucosa digestiva e reduz a palatabilidade da água.
* **Procedimento Operacional Padrão (POP):**
  1. Utilize peagômetro digital calibrado ou fitas reagentes para medir a água no ponto de entrada do galpão e na última saída da linha diariamente.
  2. Mantenha o pH estritamente entre **6.0 e 6.8**.
  3. Caso o pH esteja alcalino, adicione acidificantes orgânicos (como ácido cítrico ou fórmico) via bomba dosadora tipo dosatron.
  4. Mantenha o residual de cloro livre entre **2.0 e 4.0 ppm** no primeiro bebedouro e no mínimo **1.5 ppm** no final da linha.
* **Impacto no Bolso e no Ranking Ouros:** Água no pH ideal maximiza a absorção intestinal dos nutrientes da ração, melhora a Conversão Alimentar em até 4 pontos e preserva a integridade sanitária do lote.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669963/ouros/tips/tip_03.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669963/ouros/tips/tip_03.webp'),
        ('Auditoria Diária de Hidrômetro e Teste de Estática Noturna', '* **Diagnóstico Zootécnico:** Rompimentos subterrâneos em conexões de PVC ou boias desreguladas em caixas elevadas podem desperdiçar de 5.000 a 20.000 litros de água por semana sem gerar poças visíveis na superfície. O hidrômetro é a principal ferramenta de diagnóstico financeiro do produtor.
* **Procedimento Operacional Padrão (POP):**
  1. Registre o valor do hidrômetro no App Ouros no mesmo horário todos os dias (ex.: às 07:00 da manhã).
  2. Realize o teste da estática noturna: durante o programa de escuro total (quando todas as aves estão dormindo e sem ingerir água), observe o ponteiro de vazão mínima do hidrômetro por 15 minutos ininterruptos.
  3. Se houver qualquer giro no mostrador durante o repouso absoluto, há vazamento físico nas tubulações subterrâneas, flanges ou válvulas.
  4. Localize e repare a avaria imediatamente para estancar a perda.
* **Impacto no Bolso e no Ranking Ouros:** Reduz diretamente a métrica de Litros/Ave consumida (CAA), impulsionando a nota de água no CGI e reduzindo a queima de eletricidade na bomba do poço artesiano.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669968/ouros/tips/tip_04.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669968/ouros/tips/tip_04.webp'),
        ('Gestão Térmica da Água de Bebida em Dias de Calor Extremo', '* **Diagnóstico Zootécnico:** O frango de corte é extremamente sensível à temperatura da água. Se a água na tubulação ultrapassar **25°C**, a ave reduz o consumo; se ultrapassar **30°C**, os frangos recusam a ingestão, sofrem estresse calórico severo, param de comer e podem morrer por asfixia térmica.
* **Procedimento Operacional Padrão (POP):**
  1. Meça a temperatura da água na ponta final da linha de nipples nos horários mais críticos do dia (entre 13:00 e 16:00). A meta ideal é entre **18°C e 22°C**.
  2. Isole termicamente as caixas d’água externas com cobertura protetora ou pintura reflexiva branca, e abrigue canos externos da radiação solar direta.
  3. Em dias com temperatura externa superior a 32°C, acione a descarga rápida (flushing) nas linhas por 3 a 5 minutos para expulsar a água aquecida e abastecer a tubulação com água fresca do poço.
* **Impacto no Bolso e no Ranking Ouros:** Previne picos de mortalidade por prostração calórica, mantém o ganho diário de peso e evita que as aves derramem água na cama tentando se refrescar.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669970/ouros/tips/tip_05.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669970/ouros/tips/tip_05.webp'),
        ('Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', '* **Diagnóstico Zootécnico:** Em granjas automatizadas (Dark House e pressão negativa), uma queda de energia elétrica por apenas 15 minutos em lotes adultos fecha a renovação de ar, eleva a temperatura acima de 40°C e causa morte em massa por asfixia. Testar o gerador "a vazio" (sem carga conectada) não garante que o motor suportará o pico de partida simultâneo dos exaustores.
* **Procedimento Operacional Padrão (POP):**
  1. Agende um teste semanal obrigatório, acionando o gerador com a carga real de operação da granja durante 20 a 30 minutos.
  2. Monitore a estabilidade de tensão (Volts) e frequência (60 Hz) sob plena operação dos exaustores e bombas de climatização.
  3. Drene a água acumulada no copo sedimentador do filtro de óleo diesel e cheque a carga da bateria de partida com voltímetro.
  4. Mantenha o tanque com pelo menos 75% de combustível novo e limpo, evitando condensação de vapor d''água no fundo do reservatório.
* **Impacto no Bolso e no Ranking Ouros:** Evita perdas catastróficas por sufocamento e previne queima de placas eletrônicas por oscilação brusca na reativação da rede pública.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669971/ouros/tips/tip_06.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669971/ouros/tips/tip_06.webp'),
        ('Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', '* **Diagnóstico Zootécnico:** Exaustores operando com venezianas empoeiradas ou correias frouxas perdem até 30% da sua capacidade volumétrica de sucção de ar (CFM), enquanto o motor elétrico continua puxando 100% da sua corrente elétrica nominal. Isso obriga o sistema a ligar mais exaustores do que o necessário.
* **Procedimento Operacional Padrão (POP):**
  1. A cada saída de lote, lave as palhetas das venezianas basculantes e as pás das hélices com lavadora de alta pressão. A poeira e penugem acumuladas desbalanceiam a hélice e forçam os rolamentos.
  2. Cheque a tensão das correias quinzenalmente: pressionando o centro da correia com o polegar, a deflexão correta deve ser de 1,5 a 2,0 cm.
  3. Substitua correias trincadas ou polias desgastadas em formato de "U" (a correia deve assentar nas laterais da polia em "V", nunca tocar o fundo).
  4. Lubrifique os mancais com graxa específica de lítio a cada lote ou conforme a especificação do manual.
* **Impacto no Bolso e no Ranking Ouros:** Reduz diretamente a métrica de kWh por ave (CEA), melhorando o score de 30% do CGI e diminuindo a conta de luz da concessionária em até 15%.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669974/ouros/tips/tip_07.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669974/ouros/tips/tip_07.webp'),
        ('Gestão de Consumo no Horário de Ponta e Tarifação Rural', '* **Diagnóstico Zootécnico:** As distribuidoras de energia cobram tarifas até 5 vezes mais caras pelo kWh consumido durante o Horário de Ponta (geralmente entre 18:00 e 21:00 em dias úteis). Utilizar a rede convencional nesse horário eleva drasticamente a fatura de luz do integrado.
* **Procedimento Operacional Padrão (POP):**
  1. Conheça com exatidão a janela horária de ponta praticada na sua fatura de energia rural.
  2. Calcule o custo-benefício de acionar o grupo gerador a diesel durante as 3 horas do horário de ponta para atender à granja, caso o custo do combustível por kWh gerado seja inferior à tarifa de ponta.
  3. Quando as condições meteorológicas permitirem, faça o pré-resfriamento térmico do galpão antes das 18:00 e opere com a ventilação mínima necessária durante o intervalo tarifário crítico.
  4. Evite ligar motores pesados não emergenciais (como trituradores, moegas e bombeamento pesado) no horário de ponta.
* **Impacto no Bolso e no Ranking Ouros:** Diminui drasticamente o valor monetário da fatura de eletricidade e otimiza a conversão de energia em margem líquida para o produtor.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669976/ouros/tips/tip_08.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669976/ouros/tips/tip_08.webp'),
        ('Vedação Hermética do Aviário e Calibração da Pressão Estática', '* **Diagnóstico Zootécnico:** Frestas em portas, cortinas rasgadas e fendas no forro quebram o vácuo interno do galpão. O ar frio entra por locais errados caindo direto nas aves, e os exaustores precisam rodar o dobro do tempo para tentar gerar a renovação correta, gastando eletricidade sem alcançar a velocidade desejada.
* **Procedimento Operacional Padrão (POP):**
  1. Feche completamente os inlets e portas e ligue 1 ou 2 exaustores para checar a pressão estática no manômetro Magnehelic.
  2. A pressão de vedação deve alcançar no mínimo **37 a 40 Pascals (0.15 a 0.16 polegadas de coluna d''água)** com o galpão completamente fechado.
  3. Vede frestas com espuma expansiva de poliuretano em torno dos exaustores, portas de serviço e cumeeiras.
  4. Repare rasgos em cortinas e verifique o ajuste das almofadas de vedação nas placas evaporativas.
* **Impacto no Bolso e no Ranking Ouros:** Garante que todo o ar admitido entre exclusivamente pelos inlets direcionados ao teto, economizando até 20% no consumo de ventiladores e sistemas de aquecimento.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669977/ouros/tips/tip_09.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669977/ouros/tips/tip_09.webp'),
        ('Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', '* **Diagnóstico Zootécnico:** Em fazendas avícolas, a dispersão contínua de poeira da maravalha, ração e penugem expelida pelos exaustores assenta sobre os módulos solares fotovoltaicos. Essa camada de sujeira cria um sombreamento artificial que reduz a geração de eletricidade em até 30%.
* **Procedimento Operacional Padrão (POP):**
  1. Realize a lavagem dos painéis fotovoltaicos nas primeiras horas da manhã ou no final da tarde, quando as placas estiverem frias, evitando choque térmico e trincas no vidro temperado.
  2. Utilize apenas água limpa e rodos com esponja de microfibra macia. Nunca utilize produtos abrasivos ou lavadoras de altíssima pressão direta.
  3. Mantenha uma rotina de lavagem quinzenal nos períodos secos do ano, com atenção redobrada aos módulos instalados na direção da exaustão dos galpões.
  4. Monitore a curva de geração diária no aplicativo do inversor para identificar perdas por sujidade.
* **Impacto no Bolso e no Ranking Ouros:** Maximiza a autogeração de energia renovável, zera custos de consumo na concessionária e eleva o score no Dashboard ESG da integradora.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669979/ouros/tips/tip_10.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669979/ouros/tips/tip_10.webp'),
        ('Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', '* **Diagnóstico Zootécnico:** Nos primeiros dias de vida das pintainhas, umidade relativa do ar (UR) abaixo de 50% causa desidratação severa das mucosas respiratórias e ressecamento das patas. Acima de 70%, o ar saturado impede a perda natural de calor das aves, empasta a maravalha e acelera a liberação de amônia.
* **Procedimento Operacional Padrão (POP):**
  1. Instale termo-higrômetros digitais calibrados na altura dos animais nas três zonas do aviário (entrada, centro e fundo).
  2. Mantenha a UR rigorosamente entre **50% e 70%** (meta ideal: 60%) durante a primeira semana de alojamento.
  3. Se a UR cair abaixo de 50%, acione os bicos de nebulização em pulsos curtos (10 a 15 segundos) ou umedeça os corredores sem molhar a cama.
  4. Se a UR ultrapassar 70%, aumente a taxa de ventilação mínima para expulsar a umidade excedente para o exterior.
* **Impacto no Bolso e no Ranking Ouros:** Preserva a integridade pulmonar do lote, reduz o consumo de medicamentos e garante conversão alimentar otimizada desde os primeiros dias.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669980/ouros/tips/tip_11.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669980/ouros/tips/tip_11.webp'),
        ('Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', '* **Diagnóstico Zootécnico:** A ventilação mínima não tem como função resfriar as aves, mas sim renovar o oxigênio e remover o dióxido de carbono (CO₂), amônia (NH₃) e vapor d''água acumulados. Ventilar pouco intoxica o lote; ventilar em excesso esfria o ambiente e consome combustível de aquecimento sem necessidade.
* **Procedimento Operacional Padrão (POP):**
  1. Calcule a biomassa total do lote: **Biomassa (kg) = Número de Aves Vivas × Peso Médio da Ave (kg)**.
  2. Aplique a taxa de renovação mínima recomendada pelo manual da linhagem (m³/hora por kg de biomassa viva).
  3. Programe os ciclos de temporização dos exaustores em intervalos de 5 minutos (ex.: 45 segundos ligado e 255 segundos desligado a cada ciclo de 300 segundos).
  4. Atualize os parâmetros de temporização a cada pesagem semanal do lote conforme o peso médio das aves se eleva.
* **Impacto no Bolso e no Ranking Ouros:** Economiza energia elétrica ao evitar que motores fiquem ligados desnecessariamente e economiza gás ou lenha no sistema de aquecimento.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669982/ouros/tips/tip_12.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669982/ouros/tips/tip_12.webp'),
        ('Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', '* **Diagnóstico Zootécnico:** Como as aves não transpiram, sua principal forma de perder calor com mais de 28 dias é pela sensação térmica provocada pela velocidade do ar passando sobre as penas (efeito *Wind Chill*). Vento insuficiente causa sufocamento e infarto térmico; vento excessivo em aves jovens provoca resfriamento indesejado.
* **Procedimento Operacional Padrão (POP):**
  1. Meça a velocidade do vento na altura das aves com um anemômetro portátil calibrado no centro do aviário.
  2. Para aves adultas (acima de 35 dias) sob calor intenso (acima de 30°C), mantenha a velocidade do túnel entre **2,5 m/s e 3,0 m/s** de forma homogênea.
  3. Acione os estágios de exaustores de forma progressiva, sincronizando a abertura de cortinas ou inlets de transição para evitar bolsas de ar estagnado.
  4. Nunca submeta aves com menos de 21 dias a velocidades superiores a 1,0 m/s.
* **Impacto no Bolso e no Ranking Ouros:** Mantém as aves se alimentando e bebendo água normalmente mesmo durante ondas de calor severas, eliminando a mortalidade aguda por estresse térmico.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669983/ouros/tips/tip_13.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669983/ouros/tips/tip_13.webp'),
        ('Manejo e Manutenção de Placas Evaporativas de Resfriamento', '* **Diagnóstico Zootécnico:** As placas de celulose evaporativa reduzem a temperatura do ar de entrada em até 6°C a 8°C. Se estiverem incrustadas por sais minerais ou algas, elas restringem a passagem de ar, elevando o vácuo a níveis perigosos e sobrecarregando os motores dos exaustores.
* **Procedimento Operacional Padrão (POP):**
  1. Acione as bombas das placas evaporativas apenas após os exaustores do túnel atingirem capacidade total e a temperatura interna passar de 28°C com UR abaixo de 70%.
  2. Nunca ligue as placas se a umidade relativa externa estiver acima de 75%-80%, pois a evaporação cessa e o aviário se torna uma sauna úmida letal para as aves.
  3. Realize a purga semanal do reservatório de água para evitar concentração de calcário e formação de crostas duras.
  4. Trate a água do reservatório das placas com algicidas adequados e limpe os furos de gotejamento da tubulação superior.
* **Impacto no Bolso e no Ranking Ouros:** Aumenta a durabilidade das placas de celulose, evita esforço mecânico dos motores de exaustão e garante ambiente térmico seguro.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669985/ouros/tips/tip_14.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669985/ouros/tips/tip_14.webp'),
        ('Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', '* **Diagnóstico Zootécnico:** Concentrações de amônia (NH₃) acima de 20 ppm destroem os cílios protetores da traqueia das aves, abrindo caminho para aerossaculite, bronquite e ceratoconjuntivite (cegueira). Níveis de dióxido de carbono (CO₂) acima de 3.000 ppm nos primeiros dias provocam ascite ("barriga d''água") e morte por insuficiência cardíaca.
* **Procedimento Operacional Padrão (POP):**
  1. Utilize medidor multigás portátil ou tubos reagentes na altura da cabeça das aves.
  2. Metas inegociáveis: Amônia (NH₃) abaixo de **20 ppm** (ideal < 10 ppm); Dióxido de Carbono (CO₂) abaixo de **3.000 ppm**; Monóxido de Carbono (CO) abaixo de **10 ppm**.
  3. Se houver cheiro forte de amônia ou ardor nos olhos ao entrar no aviário, os limites já foram violados. Aumente imediatamente a ventilação mínima.
  4. Remova placas de cama úmida empastada e adicione condicionadores químicos de cama para sequestrar o nitrogênio volátil.
* **Impacto no Bolso e no Ranking Ouros:** Zera condenações de carcaça por aerossaculite no abatedouro e garante desenvolvimento pulmonar sadio para suportar o ganho rápido de peso.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669987/ouros/tips/tip_15.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669987/ouros/tips/tip_15.webp'),
        ('Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', '* **Diagnóstico Zootécnico:** O pintainho de um dia não controla sua própria temperatura corporal nos primeiros dias. Se a maravalha do piso estiver fria, a ave perde calor por condução direta pelo abdômen e pés, entrando em hipotermia, retendo o saco vitelino e sofrendo paralisia digestiva.
* **Procedimento Operacional Padrão (POP):**
  1. Inicie o aquecimento de **24 a 36 horas antes da chegada do lote** (dependendo da estação do ano e tipo de piso).
  2. Não meça apenas o ar no teto: meça com termômetro laser a **temperatura da maravalha/piso, que deve estar entre 30°C e 32°C**, e o ar entre **32°C e 34°C** no momento do alojamento.
  3. Mantenha os círculos de aquecimento configurados para permitir livre circulação entre calor, água e ração.
  4. Monitore a distribuição das aves: pintinhos confortáveis ficam uniformemente dispersos; aglomerados sob a campânula indicam frio; fugindo para as bordas e ofegantes indicam calor excessivo.
* **Impacto no Bolso e no Ranking Ouros:** Garante que o pintainho quadruplique o peso inicial na primeira semana de vida. Cada 1 grama ganho aos 7 dias representa 5 a 6 gramas adicionais no abate final.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669988/ouros/tips/tip_16.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669988/ouros/tips/tip_16.webp'),
        ('Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', '* **Diagnóstico Zootécnico:** As primeiras 24 horas determinam o sucesso do lote. Se a ave não ingerir água e ração nesse período, o vitelo materno apodrece no abdômen, a mortalidade inicial dispara e o desenvolvimento intestinal fica irremediavelmente comprometido.
* **Procedimento Operacional Padrão (POP):**
  1. Realize a palpação aleatória do papo de 100 pintinhos coletados em diferentes pontos do círculo:
     - **8 horas pós-alojamento**: meta mínima de **80%** de papos cheios.
     - **12 horas pós-alojamento**: meta mínima de **85% a 90%** de papos cheios.
     - **24 horas pós-alojamento**: meta mínima de **95% a 100%** de papos cheios.
  2. O papo bem nutrido deve ter consistência macia e arredondada (mistura perfeita de ração e água). Se estiver duro, faltou água; se flácido e aquoso, faltou ração; se vazio, a ave não localizou comedouros/bebedouros.
  3. Corrija imediatamente a iluminação ou adicione mais papel forrageiro com ração se a meta não for batida.
* **Impacto no Bolso e no Ranking Ouros:** Reduz a mortalidade da primeira semana para menos de 0,7%, elevando o índice de aves entregues no contrato de integração.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669989/ouros/tips/tip_17.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669989/ouros/tips/tip_17.webp'),
        ('Forração com Papel Kraft e Ração Pré-Inicial no Chão', '* **Diagnóstico Zootécnico:** Ao saírem das caixas do incubatório, as pintainhas se guiam pelo estímulo visual e sonoro de bicadas no chão. Colocar ração apenas nos comedouros tubulares automáticos resulta em baixa ingestão inicial e consumo acidental de maravalha da cama.
* **Procedimento Operacional Padrão (POP):**
  1. Cubra pelo menos **40% a 50% da área do círculo de alojamento** com papel kraft degradável específico para avicultura.
  2. Distribua ração pré-inicial farelada de alta digestibilidade sobre o papel (50 a 60 gramas por ave) e instale pratos suplementares (1 prato para cada 80 a 100 aves).
  3. Posicione as faixas de papel imediatamente adjacentes às linhas de bebedouros tipo nipple, permitindo que a ave coma e beba no mesmo passo.
  4. O ruído das bicadas no papel atrai os demais pintinhos pelo comportamento gregário natural da espécie.
* **Impacto no Bolso e no Ranking Ouros:** Uniformiza o peso corporal de arranque do lote e acelera a absorção de imunoglobulinas maternas do saco vitelino.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669990/ouros/tips/tip_18.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669990/ouros/tips/tip_18.webp'),
        ('Prevenção de Acúmulo de Ração e Controle de Micotoxinas', '* **Diagnóstico Zootécnico:** Ração empedrada nos cantos dos pratos em ambientes de alta umidade torna-se substrato propício para proliferação de fungos (*Aspergillus*, *Fusarium* e *Penicillium*). As micotoxinas produzidas lesam o fígado, causam hemorragias internas e suprimem gravemente o sistema imune da ave.
* **Procedimento Operacional Padrão (POP):**
  1. Regule a saída da rosca helicoidal dos comedouros automáticos para manter apenas uma lâmina rasa de ração fresca no fundo do prato.
  2. Aplique o manejo de "prato limpo": faça o lote esvaziar completamente os pratos uma vez ao dia antes de religar o motor do circuito.
  3. Raspe e descarte imediatamente qualquer resíduo úmido gerado por respingos de água ou condensação.
  4. Ao término do lote, desmonte os cones dos comedouros para lavagem e desinfecção terminal com quaternário de amônio.
* **Impacto no Bolso e no Ranking Ouros:** Previne intoxicações hepáticas crônicas, evita sobras perdidas e melhora a Conversão Alimentar em até 0,05 pontos na pesagem final.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669992/ouros/tips/tip_19.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669992/ouros/tips/tip_19.webp'),
        ('Regulagem de Altura dos Pratos conforme o Crescimento das Aves', '* **Diagnóstico Zootécnico:** Quando as linhas de comedouro permanecem baixas demais, os frangos ciscam com as patas e sacodem o pescoço lateralmente, atirando quilos de ração balanceada na maravalha, onde se perde para sempre. Se estiverem altas demais, as aves menores do lote não conseguem se alimentar.
* **Procedimento Operacional Padrão (POP):**
  1. Regule a altura das linhas de comedouro a cada 2 dias utilizando o sistema de cabos de aço e guinchos.
  2. Referência anatômica correta: a borda superior do prato deve ficar sempre **nivelada com a base do peito/dorso das aves** quando estiverem em pé.
  3. A ave deve esticar o pescoço suavemente para alcançar a ração, sem apoiar o peito na borda do prato e sem conseguir colocar as patas para dentro.
  4. Mantenha os sensores elétricos de acionamento do último prato de controle sempre limpos e calibrados.
* **Impacto no Bolso e no Ranking Ouros:** A ração responde por cerca de 70% de todo o custo da criação de frango. Eliminar o desperdício de ração no chão é a forma mais rápida de elevar a remuneração por lote entregue.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669993/ouros/tips/tip_20.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669993/ouros/tips/tip_20.webp'),
        ('Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', '* **Diagnóstico Zootécnico:** Durante o calor do dia e o esfriamento da noite, a condensação de umidade nas chapas de aço galvanizado do silo faz com que a poeira de ração grude no cone de saída e nas paredes. Com o tempo, formam-se crostas pretas altamente tóxicas e cheias de fungos que contaminam cada nova entrega de ração.
* **Procedimento Operacional Padrão (POP):**
  1. Esgote 100% da ração do silo e da rosca helicoidal ao final do lote.
  2. Bata suavemente no cone com martelo de borracha para soltar placas compactadas de ração velha.
  3. Abra a escotilha superior, lave as paredes internas com lavadora de pressão e aplique desinfetante antifúngico específico durante o vazio sanitário.
  4. Deixe o silo aberto e completamente seco sob o sol por no mínimo 48 horas antes de descarregar a primeira carga de ração do lote seguinte.
* **Impacto no Bolso e no Ranking Ouros:** Previne quedas bruscas de consumo e assegura que os aditivos e promotores nutricionais fornecidos pela fábrica atuem com máxima eficiência.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669994/ouros/tips/tip_21.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669994/ouros/tips/tip_21.webp'),
        ('Cascudamento Estruturado e Fermentação Anaeróbica da Cama', '* **Diagnóstico Zootécnico:** O cascudinho da cama (*Alphitobius diaperinus*) é o principal transmissor biológico de bactérias (*Salmonella*, *E. coli*) e vírus (Gumboro e Marek), além de roer as placas de isolamento térmico de poliuretano e isopor do aviário, destruindo a vedação e o conforto térmico.
* **Procedimento Operacional Padrão (POP):**
  1. **Cascudamento Imediato:** Assim que o último caminhão de aves sair para o abatedouro (ainda com o galpão aquecido), pulverize inseticida aprovado nas muretas, rodapés e paredes até 1 metro de altura para impedir a fuga dos insetos para o telhado.
  2. **Enleiramento da Cama:** Junte toda a maravalha no centro do aviário formando leiras de 1,2 a 1,5 metros de altura.
  3. **Lona Plástica Vedada:** Cubra as leiras com lona plástica resistente vedando as bordas com terra ou maravalha para criar atmosfera anaeróbica estrita.
  4. **Controle Térmico:** A fermentação natural deve atingir **temperaturas internas entre 55°C e 65°C por pelo menos 8 a 10 dias consecutivos**, eliminando ovos, larvas, adultos de cascudinho e inativando bactérias patogênicas.
* **Impacto no Bolso e no Ranking Ouros:** Preserva a isolação térmica do galpão (menos gasto de energia para climatizar), previne gastos com inseticidas de emergência e viabiliza a reutilização segura da cama conforme as normas da Seara.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669995/ouros/tips/tip_22.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669995/ouros/tips/tip_22.webp'),
        ('Reviração Localizada da Cama e Prevenção de Calo de Pata', '* **Diagnóstico Zootécnico:** Pontos de cama úmida e compactada ("cascões") sob os bebedouros contêm altas concentrações de ácido úrico e umidade. O contato contínuo das patas das aves com essa pasta queima a pele, gerando pododermatite (calo de pata). No abatedouro, as patas de frango são produtos nobres de exportação; lotes com calo sofrem pesados descontos financeiros no acerto final.
* **Procedimento Operacional Padrão (POP):**
  1. Caminhe diariamente pelo galpão inspecionando visualmente a área sob as linhas de bebedouros tipo nipple.
  2. Utilize garfo agrícola ou minitratores com escarificador para revolver os pontos úmidos, misturando-os com maravalha seca e expondo-os à ventilação.
  3. Se houver formação de placas compactadas com mais de 3 cm de espessura, retire-as para fora do galpão com uma pá.
  4. Polvilhe cal virgem, calcário agrícola ou sulfato de cálcio nas áreas corrigidas para secar a umidade e inibir bactérias.
* **Impacto no Bolso e no Ranking Ouros:** Garante 100% de aproveitamento das patas no frigorífico, protege as articulações dos animais e preserva o bem-estar animal exigido pelos mercados internacionais.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669997/ouros/tips/tip_23.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669997/ouros/tips/tip_23.webp'),
        ('Operação Integral e Controle de Diluição do Arco de Desinfecção', '* **Diagnóstico Zootécnico:** Caminhões de ração, transporte de pintinhos, gás e retirada de aves visitam múltiplas propriedades rurais todos os dias. As rodas, pneus e chassis são os principais transportadores mecânicos de vírus altamente contagiosos (como Influenza Aviária e Newcastle) para o interior da granja.
* **Procedimento Operacional Padrão (POP):**
  1. Mantenha o arco de desinfecção ativo na entrada da fazenda operando em **100% dos veículos que adentram a propriedade**, sem exceção para carros próprios ou de funcionários.
  2. Inspecione os bicos aspersores semanalmente para assegurar que a névoa pressurizada cubra totalmente as quatro rodas, eixos e partes inferiores do chassi.
  3. Verifique a dosagem do desinfetante (glutaraldeído ou amônia quaternária) no tanque e renove a calda a cada 3 a 7 dias, ou sempre que a água estiver turva por sedimentos.
  4. Mantenha o rodolúvio e pedilúvios de acesso aos galpões sempre abastecidos com solução desinfetante ativa renovada a cada 48 horas.
* **Impacto no Bolso e no Ranking Ouros:** Atende integralmente às exigências das Instruções Normativas do MAPA e auditorias da Seara, blindando a granja contra embargos sanitários e perda do contrato de integração.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669998/ouros/tips/tip_24.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792669998/ouros/tips/tip_24.webp'),
        ('Manejo e Aplicação Correta de Vacinas via Água de Bebida', '* **Diagnóstico Zootécnico:** As vacinas vivas atenuadas (como Gumboro e Bronquite Infecciosa) são compostas por vírus frágeis. Se forem adicionadas a água tratada com cloro residual, metais pesados ou desinfetantes, as partículas virais morrem imediatamente nos canos, deixando o lote vulnerável a doenças fatais.
* **Procedimento Operacional Padrão (POP):**
  1. Desative a cloração e dosadores químicos da água **48 horas antes** da vacinação e limpe os filtros da caixa d''água.
  2. Aplique um período de sede controlado de **1 a 2 horas** (dependendo da temperatura ambiente) levantando ligeiramente os bebedouros para que todas as aves tenham sede simultânea.
  3. Adicione neutralizante de cloro ou leite em pó desnatado (2 a 2,5 g/litro de água) e corante vacinal azul na caixa de distribuição para proteger o vírus e identificar a passagem da solução.
  4. Baixe as linhas e assegure que toda a vacina seja consumida em no máximo **1 hora e meia a 2 horas**.
  5. Faça a conferência de línguas azuis em 100 aves para comprovar que mais de 95% do lote ingeriu a dose imunizante.
* **Impacto no Bolso e no Ranking Ouros:** Garante imunização uniforme, previne surtos clínicos e subclínicos de doenças e cumpre os prazos do calendário sanitário do App Ouros.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670000/ouros/tips/tip_25.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670000/ouros/tips/tip_25.webp'),
        ('Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', '* **Diagnóstico Zootécnico:** Reduzir o tempo de vazio sanitário entre lotes para antecipar alojamentos impede a quebra do ciclo de vida de vírus, fungos e bactérias residuais. Patógenos do lote anterior contaminam os pintinhos recém-nascidos nos primeiros dias de vida, comprometendo todo o ciclo zootécnico.
* **Procedimento Operacional Padrão (POP):**
  1. Respeite o período de vazio sanitário determinado pela integradora (mínimo recomendado de **12 a 15 dias** entre a saída do lote anterior e a entrada do próximo).
  2. Execute o protocolo completo de higienização: varrição minuciosa, lavagem pesada com detergente desincrustante industrial, queima de penugem no piso com vassoura de fogo a gás e pulverização de desinfetante de amplo espectro.
  3. Vede o galpão por 48 horas após a aplicação química para ação dos vapores desinfetantes e depois abra para aeração total.
  4. Mantenha portas, telas passarinheiras e cortinas fechadas para impedir o pouso de aves silvestres ou acesso de roedores durante o vazio.
* **Impacto no Bolso e no Ranking Ouros:** Quebra a cadeia de transmissão de infecções, reduz o uso de antibióticos curativos e proporciona o arranque biológico perfeito para novos recordes de ganho de peso.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670003/ouros/tips/tip_26.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670003/ouros/tips/tip_26.webp'),
        ('Padronização da Pesagem Semanal e Análise de Uniformidade', '* **Diagnóstico Zootécnico:** Pesar frangos em horários alternados ou capturar apenas aves próximas à porta gera amostragem viciada que distorce o cálculo da conversão alimentar e da curva de ganho de peso. Sem números reais de balança, o produtor não consegue antecipar a data ideal de abate nem detectar atrasos de crescimento.
* **Procedimento Operacional Padrão (POP):**
  1. Realize a pesagem semanal no mesmo dia da semana e no mesmo horário (preferencialmente de manhã cedo, com os papos das aves vazios antes do trato de ração).
  2. Amostre pelo menos **1% a 2% do lote total** (mínimo de 100 a 200 aves), utilizando cercados plásticos de contenção em três zonas distintas (entrada, meio e fundo do aviário).
  3. Pese todas as aves que ficarem contidas no cercado, sem selecionar tamanho visualmente.
  4. Calcule o Peso Médio e a **Uniformidade do Lote** (a meta zootécnica é que mais de **85% das aves estejam na faixa de ±10% do peso médio**; ou Coeficiente de Variação - CV abaixo de 8%).
  5. Lance o peso médio aferido diretamente na aba Lotes do App Ouros.
* **Impacto no Bolso e no Ranking Ouros:** Permite intervenções de manejo e ventilação antes que o lote desande, garantindo que o lote atinja o peso contratado sem gasto desnecessário de ração.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670011/ouros/tips/tip_27.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670011/ouros/tips/tip_27.webp'),
        ('Respeito Estrito à Densidade Zootécnica por Metro Quadrado', '* **Diagnóstico Zootécnico:** Ultrapassar a capacidade de lotação que a estrutura física e a exaustão do aviário suportam gera superlotação, eleva a temperatura corporal em grupo, provoca brigas por bebedouros e comedouros, e resulta em arranhões graves de carcaça provocados pelo pisoteio.
* **Procedimento Operacional Padrão (POP):**
  1. Calcule a densidade limite conforme o sistema tecnológico do seu aviário e a época do ano:
     - **Aviários Convencionais com Cortina:** máximo de **28 a 30 kg de carne por m²** (aproximadamente 10 a 12 aves/m² para frango de 2,8 kg).
     - **Aviários Climatizados Dark House:** entre **38 e 42 kg de carne por m²** (aproximadamente 14 a 16 aves/m²).
  2. Planeje com o departamento técnico da Seara a quantidade de pintinhos a receber com base no peso final de abate estipulado em contrato.
  3. Assegure área de comedouro (60 a 70 aves por prato) e de bebedouro (10 a 12 aves por bico de nipple).
* **Impacto no Bolso e no Ranking Ouros:** Reduz perdas por arranhões no dorso e celulite aviária (que causam descarte da carcaça no frigorífico) e viabiliza a melhor conversão alimentar do lote.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670015/ouros/tips/tip_28.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670015/ouros/tips/tip_28.webp'),
        ('Registro Diário da Curva de Mortalidade e Retirada Sanitária', '* **Diagnóstico Zootécnico:** Deixar aves mortas no chão do aviário atrai moscas, dissemina bactérias patogênicas para as aves vivas que bicam as carcaças e contamina a cama com fluidos em decomposição. Não registrar as baixas no sistema mascara o consumo real de água e ração por ave viva.
* **Procedimento Operacional Padrão (POP):**
  1. Realize pelo menos duas rondas sanitárias completas por dia (pela manhã e no final da tarde) percorrendo toda a extensão do aviário.
  2. Recolha imediatamente qualquer carcaça em baldes plásticos fechados e higienizados.
  3. Destine os animais mortos para a composteira acelerada, biodigestor ou incinerador da propriedade rural conforme as normas ambientais.
  4. Lance o número exato de mortes no mesmo dia no aplicativo Ouros, mantendo o saldo de aves vivas do lote sempre atualizado.
* **Impacto no Bolso e no Ranking Ouros:** Alimenta o algoritmo do App Ouros com precisão e dispara alertas antecipados caso a curva diária de mortalidade suba acima de 0,1% ao dia, permitindo correção veterinária antes de perdas massivas.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670018/ouros/tips/tip_29.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670018/ouros/tips/tip_29.webp'),
        ('Cumprimento do Programa de Escuro e Fotoperíodo Noturno', '* **Diagnóstico Zootécnico:** Manter lâmpadas acesas 24 horas por dia gera estresse crônico, canibalismo e exaustão física. O frango de corte necessita de períodos de escuro para secretar melatonina, que fortalece o sistema imunológico, consolida o desenvolvimento ósseo das pernas e reduz mortes por infarto (morte súbita) e ascite em lotes de alto crescimento.
* **Procedimento Operacional Padrão (POP):**
  1. Nos primeiros 3 a 5 dias, forneça 23 horas de luz com alta intensidade (30 a 40 Lux) para que as pintainhas se adaptem aos bebedouros e comedouros.
  2. Do 7º dia até os 35 dias de vida, implemente o programa de escuro: forneça de **4 a 6 horas diárias de escuro contínuo ininterrupto**.
  3. O período escuro deve ocorrer sempre no mesmo horário da noite através de temporizadores automáticos em lâmpadas LED dimerizáveis.
  4. Garanta que durante o escuro não haja vazamentos de luz externa por frestas de cortinas (intensidade abaixo de 0,5 Lux).
  5. Nos últimos dias antes do carregamento, eleve suavemente as horas de luz para reduzir o estresse da equipe de apanha.
* **Impacto no Bolso e no Ranking Ouros:** Reduz diretamente o consumo de kWh com iluminação em 20% a 25%, diminui condenações por problemas locomotores e derruba a mortalidade por estresse cardiovascular.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670019/ouros/tips/tip_30.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670019/ouros/tips/tip_30.webp'),
        ('Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', '* **Diagnóstico Zootécnico:** O momento do carregamento das aves para o abatedouro é a etapa com maior incidência de hematomas nas asas e coxas, fraturas ósseas e mortes por asfixia causadas por apanha violenta ou falta de jejum alimentar adequado. Qualquer hematoma grave gera condenação da peça no frigorífico, descontando o peso útil pago ao integrado.
* **Procedimento Operacional Padrão (POP):**
  1. Suspenda o fornecimento de ração de **8 a 12 horas antes da apanha** (o jejum de água nunca deve ser feito: mantenha água fresca até o momento imediatamente anterior ao recolhimento dos bebedouros). O jejum de ração evita o rompimento do papo e intestinos na linha de abate, prevenindo contaminação por fezes.
  2. Eleve todas as linhas de comedouros e bebedouros até o teto antes da entrada da equipe de apanha para abrir passagem livre.
  3. Reduza a iluminação para o mínimo possível ou utilize luz azul suave durante o carregamento; as aves não enxergam bem nessas cores e permanecem calmas.
  4. Oriente os operadores de apanha a segurar as aves sempre pelo dorso ou pelas duas pernas simultaneamente, nunca por uma única perna ou pelas asas.
* **Impacto no Bolso e no Ranking Ouros:** Maximiza o percentual de carne nobre de primeira linha, reduz as mortes no transporte (DOA - *Dead on Arrival*) e garante o bônus máximo no fechamento financeiro do lote.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670021/ouros/tips/tip_31.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670021/ouros/tips/tip_31.webp'),
        ('Calibração de Sensores e Redundância de Termostatos de Emergência', '* **Diagnóstico Zootécnico:** Sensores ambientais de temperatura e umidade com crostas de poeira ou descalibrados enviam dados falsos com erro de até 3°C a 4°C para o computador climático. Isso pode fazer com que o sistema ligue exaustores sem necessidade no frio (gastando luz e congelando as aves) ou deixe de climatizar no calor extremo.
* **Procedimento Operacional Padrão (POP):**
  1. Limpe as capas protetoras dos sensores de temperatura e umidade quinzenalmente com pincel macio ou ar comprimido seco.
  2. Realize a checagem mensal de calibração comparando o computador de bordo com um termômetro padrão posicionado ao lado de cada sensor.
  3. Mantenha termostatos mecânicos eletromecânicos de emergência instalados em circuito independente do computador central: caso o computador trave ou sofra sobretensão por raio, o termostato analógico dispara os exaustores diretamente na contatora do quadro elétrico quando a temperatura atinge 34°C.
  4. Teste a sirene de alarme e o discador telefônico semanalmente.
* **Impacto no Bolso e no Ranking Ouros:** Previne perdas catastróficas por falha eletrônica, mantém a climatização dentro das faixas reais de conforto térmico e blinda a granja contra acidentes operacionais.', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670022/ouros/tips/tip_32.webp', 'https://res.cloudinary.com/mpyey2bi/image/upload/v1792670022/ouros/tips/tip_32.webp')
) AS v(title, tip, image_url, foto_url)
WHERE NOT EXISTS (
    SELECT 1 FROM tips t WHERE t.title = v.title
);

-- 4. Vinculacao de Categorias (tip_categories)
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Regulagem Diária e Ajuste de Altura das Linhas de Nipple' AND c.category = 'Bebedouros Eficientes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Regulagem Diária e Ajuste de Altura das Linhas de Nipple' AND c.category = 'Consumo de Água'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Purgamento e Flushing Estruturado das Tubulações de Água' AND c.category = 'Sanitização de Tubulações'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Purgamento e Flushing Estruturado das Tubulações de Água' AND c.category = 'Consumo de Água'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Monitoramento Contínuo e Correção do pH da Água de Bebida' AND c.category = 'Qualidade da Água'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Monitoramento Contínuo e Correção do pH da Água de Bebida' AND c.category = 'Consumo de Água'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna' AND c.category = 'Leitura de Hidrômetro'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna' AND c.category = 'Alertas de Consumo'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo' AND c.category = 'Consumo de Água'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo' AND c.category = 'Bebedouros Eficientes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva' AND c.category = 'Manutenção de Gerador'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza' AND c.category = 'Equipamentos'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Gestão de Consumo no Horário de Ponta e Tarifação Rural' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Gestão de Consumo no Horário de Ponta e Tarifação Rural' AND c.category = 'Economia Financeira'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Vedação Hermética do Aviário e Calibração da Pressão Estática' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Vedação Hermética do Aviário e Calibração da Pressão Estática' AND c.category = 'Equipamentos'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos' AND c.category = 'Sustentabilidade ESG'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)' AND c.category = 'Ambiência'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)' AND c.category = 'Controle de Umidade'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote' AND c.category = 'Ventilação Mínima'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote' AND c.category = 'Ambiência'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor' AND c.category = 'Velocidade do Ar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor' AND c.category = 'Ambiência'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo e Manutenção de Placas Evaporativas de Resfriamento' AND c.category = 'Equipamentos'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo e Manutenção de Placas Evaporativas de Resfriamento' AND c.category = 'Ambiência'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)' AND c.category = 'Ambiência'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C' AND c.category = 'Temperatura Inicial'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C' AND c.category = 'Planejamento de Lotes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas' AND c.category = 'Planejamento de Lotes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Forração com Papel Kraft e Ração Pré-Inicial no Chão' AND c.category = 'Eficiência por Ave'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Forração com Papel Kraft e Ração Pré-Inicial no Chão' AND c.category = 'Planejamento de Lotes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas' AND c.category = 'Qualidade da Ração'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas' AND c.category = 'Bebedouros Eficientes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves' AND c.category = 'Eficiência por Ave'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves' AND c.category = 'Qualidade da Ração'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes' AND c.category = 'Qualidade da Ração'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes' AND c.category = 'Limpeza de Galpões'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama' AND c.category = 'Limpeza de Galpões'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Reviração Localizada da Cama e Prevenção de Calo de Pata' AND c.category = 'Manejo de Cama'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Reviração Localizada da Cama e Prevenção de Calo de Pata' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Operação Integral e Controle de Diluição do Arco de Desinfecção' AND c.category = 'Biosseguridade'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Operação Integral e Controle de Diluição do Arco de Desinfecção' AND c.category = 'Dados e Validação'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo e Aplicação Correta de Vacinas via Água de Bebida' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo e Aplicação Correta de Vacinas via Água de Bebida' AND c.category = 'Suporte Técnico'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes' AND c.category = 'Limpeza de Galpões'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes' AND c.category = 'Biosseguridade'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Padronização da Pesagem Semanal e Análise de Uniformidade' AND c.category = 'Eficiência por Ave'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Padronização da Pesagem Semanal e Análise de Uniformidade' AND c.category = 'Histórico de Desempenho'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado' AND c.category = 'Eficiência por Ave'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Registro Diário da Curva de Mortalidade e Retirada Sanitária' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Registro Diário da Curva de Mortalidade e Retirada Sanitária' AND c.category = 'Dados e Validação'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno' AND c.category = 'Iluminação Noturna'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento' AND c.category = 'Mortalidade e Bem-estar'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento' AND c.category = 'Planejamento de Lotes'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Calibração de Sensores e Redundância de Termostatos de Emergência' AND c.category = 'Equipamentos'
ON CONFLICT (id_tip, id_category) DO NOTHING;
INSERT INTO tip_categories (id_tip, id_category)
SELECT t.id, c.id FROM tips t, categories c
WHERE t.title = 'Calibração de Sensores e Redundância de Termostatos de Emergência' AND c.category = 'Consumo de Energia'
ON CONFLICT (id_tip, id_category) DO NOTHING;

-- 5. Vinculacao com Granjas (farms_tips)
INSERT INTO farms_tips (id_farm, id_tip)
SELECT f.id, t.id
FROM farms f
CROSS JOIN tips t
WHERE t.title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência')
ON CONFLICT (id_farm, id_tip) DO NOTHING;

-- 6. Preservacao de dados conectados: reatribuicao de reviews e notificacoes para as 32 dicas oficiais
WITH novas_dicas AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM tips
    WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência')
),
reviews_antigos AS (
    SELECT r.id, ROW_NUMBER() OVER (ORDER BY r.id) AS rn
    FROM reviews r
    WHERE r.id_tip NOT IN (SELECT id FROM tips WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência'))
)
UPDATE reviews r
SET id_tip = nd.id
FROM reviews_antigos ra
JOIN novas_dicas nd ON ((ra.rn - 1) % 32) + 1 = nd.rn
WHERE r.id = ra.id;

WITH novas_dicas AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM tips
    WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência')
),
notifs_antigas AS (
    SELECT n.id, ROW_NUMBER() OVER (ORDER BY n.id) AS rn
    FROM notifications n
    WHERE n.id_tip IS NOT NULL
      AND n.id_tip NOT IN (SELECT id FROM tips WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência'))
)
UPDATE notifications n
SET id_tip = nd.id
FROM notifs_antigas na
JOIN novas_dicas nd ON ((na.rn - 1) % 32) + 1 = nd.rn
WHERE n.id = na.id;

-- 7. Limpeza das associacoes e das dicas sinteticas antigas (mantendo integridade referencial 100% preservada)
DELETE FROM farms_tips
WHERE id_tip NOT IN (SELECT id FROM tips WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência'));

DELETE FROM tip_categories
WHERE id_tip NOT IN (SELECT id FROM tips WHERE title IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência'));

DELETE FROM tips
WHERE title NOT IN ('Regulagem Diária e Ajuste de Altura das Linhas de Nipple', 'Purgamento e Flushing Estruturado das Tubulações de Água', 'Monitoramento Contínuo e Correção do pH da Água de Bebida', 'Auditoria Diária de Hidrômetro e Teste de Estática Noturna', 'Gestão Térmica da Água de Bebida em Dias de Calor Extremo', 'Teste Semanal do Gerador sob Carga Real e Manutenção Preventiva', 'Manutenção Preventiva de Exaustores: Tensão de Correias e Limpeza', 'Gestão de Consumo no Horário de Ponta e Tarifação Rural', 'Vedação Hermética do Aviário e Calibração da Pressão Estática', 'Manutenção e Limpeza Periódica de Painéis Solares Fotovoltaicos', 'Controle Rigoroso da Umidade Relativa do Ar (50% a 70%)', 'Cálculo da Ventilação Mínima Baseada na Biomassa Total do Lote', 'Ajuste de Velocidade do Ar em Túnel de Vento nos Dias de Calor', 'Manejo e Manutenção de Placas Evaporativas de Resfriamento', 'Monitoramento de Gases Críticos: Amônia (NH₃) e Dióxido de Carbono (CO₂)', 'Pré-Aquecimento do Galpão e Temperatura do Piso a 32°C', 'Avaliação do Enchimento de Papo às 8, 12 e 24 Horas', 'Forração com Papel Kraft e Ração Pré-Inicial no Chão', 'Prevenção de Acúmulo de Ração e Controle de Micotoxinas', 'Regulagem de Altura dos Pratos conforme o Crescimento das Aves', 'Higienização e Tratamento Térmico dos Silos de Ração entre Lotes', 'Cascudamento Estruturado e Fermentação Anaeróbica da Cama', 'Reviração Localizada da Cama e Prevenção de Calo de Pata', 'Operação Integral e Controle de Diluição do Arco de Desinfecção', 'Manejo e Aplicação Correta de Vacinas via Água de Bebida', 'Vazio Sanitário Rigoroso e Limpeza Terminal entre Lotes', 'Padronização da Pesagem Semanal e Análise de Uniformidade', 'Respeito Estrito à Densidade Zootécnica por Metro Quadrado', 'Registro Diário da Curva de Mortalidade e Retirada Sanitária', 'Cumprimento do Programa de Escuro e Fotoperíodo Noturno', 'Manejo Cuidadoso de Pós-Apanha e Preparação do Carregamento', 'Calibração de Sensores e Redundância de Termostatos de Emergência');
