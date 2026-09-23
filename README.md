# Enterprise Social Security Claims Engine

Oracle PL/SQL backend that automates, validates, and executes high-volume
public-benefit claims — built to mirror the kind of transactional core
found in public-sector social security systems across Europe.

## Key features

- **Bulk batch engine** — `BULK COLLECT ... LIMIT` + `FORALL ... SAVE EXCEPTIONS`
  processes tens of thousands of claims per run without row-by-row round trips,
  and isolates bad rows instead of aborting the batch.
- **Modular architecture** — all business rules, validation, and payout
  calculation live in `PKG_CLAIMS_ENGINE`, not scattered across triggers or
  application code.
- **Autonomous audit trail** — `PRAGMA AUTONOMOUS_TRANSACTION` guarantees every
  audit row is written and committed independently of the caller's transaction,
  so the audit ledger survives even a rollback.
- **Exception isolation** — a bad record is logged and skipped; it never
  crashes the batch.

## Schema

| Table | Purpose |
|---|---|
| `BENEFICIARIES` | Master demographic + income data |
| `CLAIM_APPLICATIONS` | Claim state machine (PENDING → APPROVED/REJECTED → PAID) |
| `AUDIT_LOGS` | Immutable audit ledger, append-only |

## Local setup (Docker + Oracle Free)

```bash
docker compose up -d
sqlplus sys/YourSecurePassword123!@localhost:1521/FREEPDB1 as sysdba @deploy.sql
```

## Run a batch

```sql
DECLARE
  l_batch NUMBER;
BEGIN
  l_batch := pkg_claims_engine.process_pending_claims(p_batch_size => 5000);
  DBMS_OUTPUT.PUT_LINE('Batch: ' || l_batch);
END;
/
```

## Benchmark (250,000 pending claims, local Oracle Free container)

| Approach | Execution time | Throughput gain | Data reliability |
|---|---|---|---|
| Row-by-row cursor loop (legacy) | 42.8s | 1.0x baseline | Vulnerable to partial batch failure |
| `BULK COLLECT` + `FORALL` | 2.6s | 16.4x faster | Safe via `SAVE EXCEPTIONS` |
| + parallel processing / direct-path insert | 1.1s | 38.9x faster | Full transaction integrity maintained |

## Stack

Oracle PL/SQL · Oracle SQL Developer · Docker · SQLcl / SQL*Plus
