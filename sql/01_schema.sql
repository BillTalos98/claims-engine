-- =====================================================================
-- Enterprise Social Security Claims Engine
-- 01_schema.sql — core schema: BENEFICIARIES, CLAIM_APPLICATIONS, AUDIT_LOGS
-- =====================================================================

CREATE TABLE beneficiaries (
    beneficiary_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    national_id      VARCHAR2(20)   NOT NULL UNIQUE,
    first_name       VARCHAR2(100)  NOT NULL,
    last_name        VARCHAR2(100)  NOT NULL,
    date_of_birth    DATE           NOT NULL,
    monthly_income   NUMBER(12,2)   DEFAULT 0,
    household_size   NUMBER(3)      DEFAULT 1,
    status           VARCHAR2(20)   DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','SUSPENDED','DECEASED')),
    created_at       TIMESTAMP      DEFAULT SYSTIMESTAMP
);

CREATE TABLE claim_applications (
    claim_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    beneficiary_id    NUMBER         NOT NULL
                        REFERENCES beneficiaries(beneficiary_id),
    claim_type        VARCHAR2(30)   NOT NULL
                        CHECK (claim_type IN
                          ('UNEMPLOYMENT','DISABILITY','PENSION_SUPPLEMENT','FAMILY_BENEFIT')),
    claim_status      VARCHAR2(20)   DEFAULT 'PENDING'
                        CHECK (claim_status IN
                          ('PENDING','VALIDATED','APPROVED','REJECTED','PAID','ERROR')),
    requested_amount  NUMBER(12,2)   NOT NULL,
    approved_amount   NUMBER(12,2),
    submitted_date    DATE           DEFAULT SYSDATE,
    processed_date    DATE,
    rejection_reason  VARCHAR2(4000),
    batch_id          NUMBER
);

CREATE TABLE audit_logs (
    audit_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id          NUMBER,
    action            VARCHAR2(50),
    old_status        VARCHAR2(20),
    new_status        VARCHAR2(20),
    action_by         VARCHAR2(50)   DEFAULT USER,
    action_timestamp  TIMESTAMP      DEFAULT SYSTIMESTAMP,
    details           VARCHAR2(4000)
);

CREATE INDEX idx_claims_status      ON claim_applications(claim_status);
CREATE INDEX idx_claims_beneficiary ON claim_applications(beneficiary_id);
CREATE INDEX idx_audit_claim_id     ON audit_logs(claim_id);

SELECT table_name FROM user_tables ORDER BY table_name;
