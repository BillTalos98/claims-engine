-- Run from SQL*Plus / SQLcl, connected as the target schema owner:
--   sqlplus user/pass@//localhost:1521/FREEPDB1 @deploy.sql

SET ECHO ON
SET SERVEROUTPUT ON

@@sql/01_schema.sql
@@sql/02_pkg_claims_engine.pks
@@sql/03_pkg_claims_engine_body.pkb
@@sql/04_triggers.sql
@@sql/05_seed_data.sql

PROMPT Deployment complete. Run a batch with:
PROMPT   DECLARE l_batch NUMBER; BEGIN l_batch := pkg_claims_engine.process_pending_claims(p_batch_size => 5000); DBMS_OUTPUT.PUT_LINE('Batch: '||l_batch); END; /
