# 01 - Architecture

**Purpose:** Explain the intended system model, boundaries, data flow, and inherited tradeoffs.

**Confidence note:** Verified against workspace specifications on 2026-11-23; implementation evidence is absent.

The workspace defines a Web and Android application ecosystem, but no implementation repositories or runtime entry points currently exist. The intended model is a shared back-end API serving an Android client and a Web client, with role-based access and Google Sign-In. The DPA-compliant security and privacy layer is a required cross-cutting boundary.

| Component | Owns |
|---|---|
| capsicum-api | Authentication, authorization, business rules, data, audit-safe operations |
| capsicum-android | Android UX and local presentation state |
| capsicum-web | Browser UX and local presentation state |
| capsicum-specs | Requirements and durable engineering knowledge |

Data must flow through explicit API validation and authorization; clients must not trust client-side role checks. Location, personal data, retention, aggregation, and resale consent must remain policy-enforced server boundaries.

### Decision: Web and Android platforms (2026-11-23, project specification)
**Status:** accepted
**Context / Choice / Alternatives / Consequences:** The business logic allows Web and Android; no other platform or implementation stack is specified.

### Debt
1. No source or build manifests exist, so architecture cannot be confirmed beyond specifications.
2. Placeholder requirements and MVP features prevent precise route, schema, and release decisions.
3. The team name, code name, stack, and userbase remain unresolved.
