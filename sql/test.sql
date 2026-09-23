SELECT line, position, text
FROM user_errors
WHERE name = 'PKG_CLAIMS_ENGINE'
ORDER BY sequence;

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_CLAIMS_ENGINE';

SELECT USER FROM DUAL;

SET SERVEROUTPUT ON;
DECLARE
    l_batch NUMBER;
BEGIN
    l_batch := pkg_claims_engine.process_pending_claims(p_batch_size => 5000);
    DBMS_OUTPUT.PUT_LINE('Batch id: ' || l_batch);
END;
/