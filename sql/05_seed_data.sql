-- =====================================================================
-- Seed data generator. Default below creates 10,000 beneficiaries and
-- 50,000 pending claims — raise p_claims to 250,000 to match the
-- benchmark scenario in the project spec.
-- =====================================================================
DECLARE
    p_beneficiaries CONSTANT PLS_INTEGER := 10000;
    p_claims        CONSTANT PLS_INTEGER := 50000;
    l_types         SYS.ODCIVARCHAR2LIST :=
        SYS.ODCIVARCHAR2LIST('UNEMPLOYMENT','DISABILITY','PENSION_SUPPLEMENT','FAMILY_BENEFIT');
BEGIN
    FOR i IN 1 .. p_beneficiaries LOOP
        INSERT INTO beneficiaries (national_id, first_name, last_name, date_of_birth,
                                    monthly_income, household_size, status)
        VALUES ('ID' || LPAD(i, 9, '0'), 'First' || i, 'Last' || i,
                DATE '1960-01-01' + MOD(i, 20000),
                ROUND(DBMS_RANDOM.VALUE(400, 2500), 2),
                TRUNC(DBMS_RANDOM.VALUE(1, 5)),
                CASE WHEN MOD(i, 50) = 0 THEN 'SUSPENDED' ELSE 'ACTIVE' END);
    END LOOP;

    FOR i IN 1 .. p_claims LOOP
        INSERT INTO claim_applications (beneficiary_id, claim_type, requested_amount, claim_status)
        VALUES (TRUNC(DBMS_RANDOM.VALUE(1, p_beneficiaries + 1)),
                l_types(TRUNC(DBMS_RANDOM.VALUE(1, 5))),
                ROUND(DBMS_RANDOM.VALUE(50, 900), 2),
                'PENDING');
        IF MOD(i, 5000) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;
    COMMIT;
END;
/
