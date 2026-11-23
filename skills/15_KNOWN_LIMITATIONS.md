# 15 - Known Limitations

**Purpose:** Rank gaps most likely to surprise contributors.

**Confidence note:** Verified by inventory on 2026-11-23.

1. Critical: API, Android, and Web contain no implementation or build manifests.
2. Critical: A concrete tech stack, hosting model, database, and test stack are undefined.
3. Critical: MVP features are placeholders, so role-to-feature behavior cannot be implemented safely.
4. High: Authentication requirements name Google Sign-In but do not define account linking or session lifecycle.
5. High: The Data Privacy Act is named, but jurisdictional and operational compliance controls are not fully specified.
6. Medium: No logs, CI/CD, metrics, incidents, or migration history exist.
7. Medium: No release tags or deployment environments are available.
8. Medium: Performance limits and capacity estimates are absent.

Redesign priority: establish a concrete product scope and implementation repositories before adding detailed API or database contracts.
