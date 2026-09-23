-- =====================================================================
-- PKG_CLAIMS_ENGINE — package body
-- =====================================================================
CREATE SEQUENCE claims_batch_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PACKAGE BODY pkg_claims_engine AS

    ----------------------------------------------------------------
    FUNCTION validate_claim(
        p_beneficiary_id   IN claim_applications.beneficiary_id%TYPE,
        p_claim_type       IN claim_applications.claim_type%TYPE,
        p_requested_amount IN claim_applications.requested_amount%TYPE
    ) RETURN VARCHAR2 IS
        l_status         beneficiaries.status%TYPE;
        l_monthly_income beneficiaries.monthly_income%TYPE;
    BEGIN
        SELECT status, monthly_income
          INTO l_status, l_monthly_income
          FROM beneficiaries
         WHERE beneficiary_id = p_beneficiary_id;

        IF l_status != 'ACTIVE' THEN
            RETURN 'BENEFICIARY_NOT_ACTIVE';
        ELSIF p_requested_amount <= 0 THEN
            RETURN 'INVALID_AMOUNT';
        ELSIF p_claim_type = 'UNEMPLOYMENT' AND l_monthly_income > 1200 THEN
            RETURN 'INCOME_ABOVE_THRESHOLD';
        ELSE
            RETURN 'VALID';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'BENEFICIARY_NOT_FOUND';
    END validate_claim;

    ----------------------------------------------------------------
    FUNCTION calculate_payout(
        p_beneficiary_id   IN claim_applications.beneficiary_id%TYPE,
        p_claim_type       IN claim_applications.claim_type%TYPE,
        p_requested_amount IN claim_applications.requested_amount%TYPE
    ) RETURN NUMBER IS
        l_household_size beneficiaries.household_size%TYPE;
        l_payout         NUMBER(12,2);
    BEGIN
        SELECT household_size INTO l_household_size
          FROM beneficiaries WHERE beneficiary_id = p_beneficiary_id;

        l_payout := CASE p_claim_type
                        WHEN 'UNEMPLOYMENT'        THEN LEAST(p_requested_amount, 600)
                        WHEN 'DISABILITY'          THEN p_requested_amount * 1.10
                        WHEN 'PENSION_SUPPLEMENT'  THEN p_requested_amount
                        WHEN 'FAMILY_BENEFIT'      THEN p_requested_amount + (l_household_size * 25)
                        ELSE p_requested_amount
                    END;
        RETURN ROUND(l_payout, 2);
    END calculate_payout;

    ----------------------------------------------------------------
    PROCEDURE log_audit(
        p_claim_id   IN audit_logs.claim_id%TYPE,
        p_action     IN audit_logs.action%TYPE,
        p_old_status IN audit_logs.old_status%TYPE,
        p_new_status IN audit_logs.new_status%TYPE,
        p_details    IN audit_logs.details%TYPE DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_logs (claim_id, action, old_status, new_status, details)
        VALUES (p_claim_id, p_action, p_old_status, p_new_status, p_details);
        COMMIT;
    END log_audit;

    ----------------------------------------------------------------
    FUNCTION process_pending_claims(
        p_batch_size IN PLS_INTEGER DEFAULT 5000
    ) RETURN NUMBER IS

        CURSOR c_pending IS
            SELECT claim_id, beneficiary_id, claim_type, requested_amount
              FROM claim_applications
             WHERE claim_status = 'PENDING'
               FOR UPDATE SKIP LOCKED;

        TYPE t_claim_ids   IS TABLE OF claim_applications.claim_id%TYPE;
        TYPE t_new_status  IS TABLE OF claim_applications.claim_status%TYPE;
        TYPE t_amounts     IS TABLE OF claim_applications.approved_amount%TYPE;
        TYPE t_reasons     IS TABLE OF claim_applications.rejection_reason%TYPE;

        l_claim_ids  t_claim_ids;
        l_ben_ids    t_claim_ids;
        l_types      DBMS_SQL.VARCHAR2_TABLE;
        l_amounts_in t_amounts;

        l_new_status t_new_status;
        l_approved   t_amounts;
        l_reasons    t_reasons;

        l_batch_id   NUMBER := claims_batch_seq.NEXTVAL;
        l_validation VARCHAR2(50);
        bulk_errors  EXCEPTION;
        PRAGMA EXCEPTION_INIT(bulk_errors, -24381);

    BEGIN
        OPEN c_pending;
        LOOP
            FETCH c_pending BULK COLLECT INTO l_claim_ids, l_ben_ids, l_types, l_amounts_in
                LIMIT p_batch_size;
            EXIT WHEN l_claim_ids.COUNT = 0;

            l_new_status := t_new_status();
            l_approved   := t_amounts();
            l_reasons    := t_reasons();
            l_new_status.EXTEND(l_claim_ids.COUNT);
            l_approved.EXTEND(l_claim_ids.COUNT);
            l_reasons.EXTEND(l_claim_ids.COUNT);

            -- Row-level validation + pricing (in-memory, no DB round trip)
            FOR i IN 1 .. l_claim_ids.COUNT LOOP
                l_validation := validate_claim(l_ben_ids(i), l_types(i), l_amounts_in(i));
                IF l_validation = 'VALID' THEN
                    l_new_status(i) := 'APPROVED';
                    l_approved(i)   := calculate_payout(l_ben_ids(i), l_types(i), l_amounts_in(i));
                    l_reasons(i)    := NULL;
                ELSE
                    l_new_status(i) := 'REJECTED';
                    l_approved(i)   := NULL;
                    l_reasons(i)    := l_validation;
                END IF;
            END LOOP;

            -- Set-based apply. SAVE EXCEPTIONS means one bad row never
            -- aborts the other 4,999 in the batch.
            BEGIN
                FORALL i IN 1 .. l_claim_ids.COUNT SAVE EXCEPTIONS
                    UPDATE claim_applications
                       SET claim_status     = l_new_status(i),
                           approved_amount  = l_approved(i),
                           rejection_reason = l_reasons(i),
                           processed_date   = SYSDATE,
                           batch_id         = l_batch_id
                     WHERE claim_id = l_claim_ids(i);
            EXCEPTION
                WHEN bulk_errors THEN
                    FOR e IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                        log_audit(
                            p_claim_id   => l_claim_ids(SQL%BULK_EXCEPTIONS(e).ERROR_INDEX),
                            p_action     => 'BATCH_UPDATE_FAILED',
                            p_old_status => 'PENDING',
                            p_new_status => 'ERROR',
                            p_details    => SQLERRM(-SQL%BULK_EXCEPTIONS(e).ERROR_CODE)
                        );
                    END LOOP;
            END;

            -- One audit row per successfully processed claim.
            -- (log_audit is autonomous, so these commit independently
            -- regardless of when the outer transaction commits.)
            FOR i IN 1 .. l_claim_ids.COUNT LOOP
                log_audit(l_claim_ids(i), 'PROCESSED', 'PENDING', l_new_status(i), l_reasons(i));
            END LOOP;

            -- NOTE: no COMMIT here. c_pending is a FOR UPDATE SKIP LOCKED
            -- cursor; committing while it's still open releases its row
            -- locks and the next FETCH raises ORA-01002 (fetch out of
            -- sequence). We commit once, after the cursor is closed.
        END LOOP;
        CLOSE c_pending;
        COMMIT;

        RETURN l_batch_id;
    END process_pending_claims;

END pkg_claims_engine;
/
