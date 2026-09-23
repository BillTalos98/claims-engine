-- =====================================================================
-- Autonomous audit trigger — catches status changes made OUTSIDE
-- pkg_claims_engine (e.g. a manual UPDATE by an ops user), so the
-- audit trail stays complete regardless of the entry point.
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_claim_status_audit
FOR UPDATE OF claim_status ON claim_applications
COMPOUND TRIGGER

    TYPE t_row IS RECORD (
        claim_id   claim_applications.claim_id%TYPE,
        old_status claim_applications.claim_status%TYPE,
        new_status claim_applications.claim_status%TYPE
    );
    TYPE t_rows IS TABLE OF t_row INDEX BY PLS_INTEGER;
    g_rows t_rows;

    AFTER EACH ROW IS
    BEGIN
        g_rows(g_rows.COUNT + 1).claim_id   := :NEW.claim_id;
        g_rows(g_rows.COUNT).old_status     := :OLD.claim_status;
        g_rows(g_rows.COUNT).new_status     := :NEW.claim_status;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FOR i IN 1 .. g_rows.COUNT LOOP
            pkg_claims_engine.log_audit(
                p_claim_id   => g_rows(i).claim_id,
                p_action     => 'STATUS_CHANGE',
                p_old_status => g_rows(i).old_status,
                p_new_status => g_rows(i).new_status,
                p_details    => 'Changed outside batch engine'
            );
        END LOOP;
    END AFTER STATEMENT;

END trg_claim_status_audit;
/
