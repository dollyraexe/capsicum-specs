# 07 - Database

**Purpose:** State the minimum database design rules for identity, privacy, deletes, and migrations.

**Confidence note:** Inferred from required solution layers; no schema or migration files exist.

- Use server-generated, non-sensitive identifiers for records.
- Store identity-provider subject identifiers with explicit account-linking rules.
- Minimize personal and location fields. Do not retain fields without a stated purpose.
- Define retention and deletion policy before production storage exists.
- Do not create per-user location trails; use aggregation thresholds and purpose-bound reports.
- Suppress small aggregates that could identify individuals.
- Migrations require up/down or forward-fix evidence, rollback steps, and production data verification.
- Dangerous operations require a tested backup and explicit data-restoration procedure.
