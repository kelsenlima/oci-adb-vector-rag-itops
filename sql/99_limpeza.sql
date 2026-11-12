/* Limpeza (como ADMIN) */
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name   => 'ITOPS_MCP.REMOVER_FERRAMENTA_RUNBOOK',
    job_type   => 'PLSQL_BLOCK',
    job_action => q'[BEGIN DBMS_CLOUD_AI_AGENT.DROP_TOOL('CONSULTAR_RUNBOOK'); END;]',
    enabled    => TRUE,
    auto_drop  => TRUE);
END;
/
DROP FUNCTION itops_mcp.consultar_runbook;
DROP FUNCTION responder_runbook;
DROP TABLE auditoria_rag PURGE;
DROP TABLE comandos_proibidos PURGE;
DROP INDEX idx_runbook_trechos_vec;
DROP TABLE runbook_trechos PURGE;
DROP TABLE runbooks PURGE;
EXEC DBMS_DATA_MINING.DROP_MODEL('ALL_MINILM_L12_V2');
