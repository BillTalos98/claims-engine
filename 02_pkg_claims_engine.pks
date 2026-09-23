-- =====================================================================
-- PKG_CLAIMS_ENGINE — package specification
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_claims_engine AS

    -- Business validation rules for a single claim.
    -- Returns 'VALID' or a rejection reason.
    FUNCTION validate_claim(
        p_beneficiary_id   IN claim_applications.beneficiary_id%TYPE,
        p_claim_type       IN claim_applications.claim_type%TYPE,
        p_requested_amount IN claim_applications.requested_amount%TYPE
    ) RETURN VARCHAR2;

    -- Deterministic payout calculation based on claim type and household size.
    FUNCTION calculate_payout(
        p_beneficiary_id   IN claim_applications.beneficiary_id%TYPE,
        p_claim_type       IN claim_applications.claim_type%TYPE,
        p_requested_amount IN claim_applications.requested_amount%TYPE
    ) RETURN NUMBER;

    -- Writes one immutable audit row. Runs in its own autonomous
    -- transaction so an audit entry survives even if the caller rolls back.
    PROCEDURE log_audit(
        p_claim_id   IN audit_logs.claim_id%TYPE,
        p_action     IN audit_logs.action%TYPE,
        p_old_status IN audit_logs.old_status%TYPE,
        p_new_status IN audit_logs.new_status%TYPE,
        p_details    IN audit_logs.details%TYPE DEFAULT NULL
    );

    -- Main entry point: pulls PENDING claims in batches using BULK COLLECT,
    -- validates + prices each one, then applies the whole batch with
    -- FORALL ... SAVE EXCEPTIONS so a handful of bad rows never abort
    -- the run. Returns the batch id used for this run.
    FUNCTION process_pending_claims(
        p_batch_size IN PLS_INTEGER DEFAULT 5000
    ) RETURN NUMBER;

END pkg_claims_engine;
/
