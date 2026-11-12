/* =====================================================================
   01 · Modelo de embedding DENTRO do banco + runbooks + vetores
   Rode como ADMIN no Database Actions (SQL), com Run Script (F5).
   Nada aqui usa OCI Generative AI: os vetores são gerados pelo próprio banco.
   ===================================================================== */


/* ---------------------------------------------------------------------
   1.1 · Carregar o modelo de embedding pré-pronto da Oracle (ONNX)
   all-MiniLM-L12-v2: 384 dimensões, roda dentro do banco.
   --------------------------------------------------------------------- */
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD(
    model_name => 'ALL_MINILM_L12_V2',
    credential => NULL,
    uri        => 'https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/iPX9W0MZeRkwJKWdFmdJCemmN-iKAl_bFvNGYLW7YqIrw4kKsukL24J2q93Beb9S/n/adwc4pm/b/OML-ai-models/o/all_MiniLM_L12_v2.onnx',
    metadata   => JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}')
  );
END;
/

-- Conferência: o modelo aparece e gera um vetor de 384 posições
SELECT model_name, mining_function, algorithm FROM user_mining_models WHERE model_name = 'ALL_MINILM_L12_V2';
SELECT VECTOR_DIMENSION_COUNT(VECTOR_EMBEDDING(ALL_MINILM_L12_V2 USING 'disco cheio' AS data)) AS dimensoes FROM dual;


/* ---------------------------------------------------------------------
   1.2 · Runbooks: só o que está APROVADO pode virar resposta
   --------------------------------------------------------------------- */
CREATE TABLE runbooks (
  runbook_id   VARCHAR2(10) PRIMARY KEY,
  titulo       VARCHAR2(200) NOT NULL,
  categoria    VARCHAR2(30)  NOT NULL,
  status       VARCHAR2(20)  NOT NULL,   -- APROVADO ou RASCUNHO
  dono_time    VARCHAR2(40)  NOT NULL,
  revisado_em  DATE          NOT NULL
);

CREATE TABLE runbook_trechos (
  trecho_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  runbook_id   VARCHAR2(10) REFERENCES runbooks,
  ordem        NUMBER NOT NULL,
  texto        VARCHAR2(2000) NOT NULL,
  embedding    VECTOR(384, FLOAT32)
);

INSERT INTO runbooks VALUES ('RB-001', 'Disco de archive log acima de 90%',        'DISCO',       'APROVADO', 'Banco de Dados', DATE '2026-10-20');
INSERT INTO runbooks VALUES ('RB-002', 'Certificado TLS perto de expirar',          'CERTIFICADO', 'APROVADO', 'Plataforma',     DATE '2026-10-15');
INSERT INTO runbooks VALUES ('RB-003', 'Job de carga noturna falhou',               'APLICACAO',   'APROVADO', 'Dados',          DATE '2026-09-30');
INSERT INTO runbooks VALUES ('RB-004', 'CPU alta sustentada em servidor de aplicação','CPU',       'APROVADO', 'Aplicações',     DATE '2026-10-01');
INSERT INTO runbooks VALUES ('RB-005', 'Latência alta no load balancer',            'REDE',        'APROVADO', 'Plataforma',     DATE '2026-08-28');
INSERT INTO runbooks VALUES ('RB-006', 'Workflow de automação parado por credencial','APLICACAO',  'APROVADO', 'Automação',      DATE '2026-10-10');
-- Rascunho com um procedimento perigoso: NUNCA pode aparecer numa resposta
INSERT INTO runbooks VALUES ('RB-099', 'Liberar disco rápido (rascunho)',           'DISCO',       'RASCUNHO', 'Banco de Dados', DATE '2026-11-01');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-001', 1, 'Sintoma: o disco de archive log do banco passou de 90% de uso. Se chegar a 100%, o banco para de gravar transações.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-001', 2, 'Ação: confirme que o último backup de archive logs terminou com sucesso. Rode o backup de archive logs com remoção dos já copiados (backup archivelog all delete input) pelo RMAN.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-001', 3, 'Se o backup estiver falhando, abra chamado ALTA para o time de Banco de Dados. Nunca apague arquivos de archive manualmente pelo sistema operacional.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-002', 1, 'Sintoma: o monitoramento avisa que o certificado TLS de um site expira em menos de 15 dias.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-002', 2, 'Ação: gere a renovação no provedor do certificado, valide a cadeia completa e publique primeiro no ambiente de homologação. Depois aplique em produção numa janela de mudança aprovada.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-003', 1, 'Sintoma: o job de carga noturna do ETL terminou com erro e os relatórios da manhã ficaram desatualizados.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-003', 2, 'Ação: veja o log do job para identificar a etapa que falhou. Se for falha de conexão com a origem, reexecute apenas a etapa com erro. Avise o time de Dados antes de reprocessar a carga completa.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-004', 1, 'Sintoma: CPU acima de 85% por mais de 15 minutos em servidor de aplicação.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-004', 2, 'Ação: identifique o processo que mais consome CPU e compare com o último deploy. Se houver deploy recente, avalie rollback com o time de Aplicações. Não reinicie o servidor sem aviso.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-005', 1, 'Sintoma: latência alta entre os usuários e o load balancer, com tempo de resposta acima de 2 segundos.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-005', 2, 'Ação: verifique a saúde dos backends no load balancer e a taxa de erros 5xx. Remova do pool o backend com falha e abra chamado para o time de Plataforma.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-006', 1, 'Sintoma: um workflow de automação parou de executar com erro de autenticação.');
INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-006', 2, 'Ação: renove a credencial no cofre de segredos, atualize a conexão do workflow e execute um teste manual. Registre a nova data de expiração no inventário.');

INSERT INTO runbook_trechos (runbook_id, ordem, texto) VALUES ('RB-099', 1, 'Rascunho: para liberar o disco de archive rapidamente, apague os arquivos de archive mais antigos direto pelo sistema operacional com rm.');
COMMIT;


/* ---------------------------------------------------------------------
   1.3 · Gerar os vetores dentro do banco
   --------------------------------------------------------------------- */
UPDATE runbook_trechos
   SET embedding = VECTOR_EMBEDDING(ALL_MINILM_L12_V2 USING texto AS data);
COMMIT;

SELECT runbook_id, ordem, VECTOR_DIMENSION_COUNT(embedding) AS dimensoes
  FROM runbook_trechos ORDER BY runbook_id, ordem;


/* ---------------------------------------------------------------------
   1.4 · Índice vetorial (IVF: não depende de memória dedicada a vetores)
   --------------------------------------------------------------------- */
CREATE VECTOR INDEX idx_runbook_trechos_vec ON runbook_trechos (embedding)
  ORGANIZATION NEIGHBOR PARTITIONS
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;


/* ---------------------------------------------------------------------
   1.5 · Primeira busca semântica: perguntas sem as mesmas palavras do runbook
   Quanto MENOR a distância, mais parecido. Anote os valores: vamos usar
   para calibrar o limite do "não sei" no passo 2.
   --------------------------------------------------------------------- */
-- Pergunta relacionada (deve achar RB-001)
SELECT t.runbook_id, r.status, ROUND(VECTOR_DISTANCE(t.embedding,
         VECTOR_EMBEDDING(ALL_MINILM_L12_V2 USING 'o espaço de archive do banco está quase acabando, o que eu faço?' AS data), COSINE), 3) AS distancia,
       SUBSTR(t.texto, 1, 80) AS trecho
  FROM runbook_trechos t JOIN runbooks r ON r.runbook_id = t.runbook_id
 ORDER BY distancia
 FETCH FIRST 4 ROWS ONLY;

-- Pergunta relacionada (deve achar RB-002)
SELECT t.runbook_id, r.status, ROUND(VECTOR_DISTANCE(t.embedding,
         VECTOR_EMBEDDING(ALL_MINILM_L12_V2 USING 'o certificado do site vai vencer semana que vem' AS data), COSINE), 3) AS distancia,
       SUBSTR(t.texto, 1, 80) AS trecho
  FROM runbook_trechos t JOIN runbooks r ON r.runbook_id = t.runbook_id
 ORDER BY distancia
 FETCH FIRST 4 ROWS ONLY;

-- Pergunta SEM runbook (deve ficar longe de tudo)
SELECT t.runbook_id, r.status, ROUND(VECTOR_DISTANCE(t.embedding,
         VECTOR_EMBEDDING(ALL_MINILM_L12_V2 USING 'como configuro a impressora da recepção?' AS data), COSINE), 3) AS distancia,
       SUBSTR(t.texto, 1, 80) AS trecho
  FROM runbook_trechos t JOIN runbooks r ON r.runbook_id = t.runbook_id
 ORDER BY distancia
 FETCH FIRST 4 ROWS ONLY;
