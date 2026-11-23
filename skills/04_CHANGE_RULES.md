# 04 - Change Rules

**Purpose:** Prevent drift across mirrored requirements, roles, routes, schemas, security rules, and clients.

**Confidence note:** Verified from the current specifications; no executable lockstep sets exist yet.

1. User-level changes
   - Update the business requirements and every authorization matrix at the same time.
   - Miss -> a role receives an unintended capability or loses required access.
   - Retest each role against every feature.

2. Feature-access changes
   - Update the MVP access table and API/Web/Android guards together.
   - Miss -> UI and server behavior disagree.

3. Authentication changes
   - Update sign-in requirements, API token validation, Web integration, and Android integration together.
   - Miss -> duplicate or inconsistent identity flows.

4. Privacy fields or location data
   - Update collection, validation, storage, retention, exports, aggregation, and deletion together.
   - Miss -> a field survives beyond consent or policy.

5. Git rules
   - Update capsicum-specs/git-guidelines.md and existing scoped practice together.
   - Miss -> commit formats diverge across repositories.
