# 13 - Dependencies

**Purpose:** Record dependency policy and unresolved dependency choices.

**Confidence note:** No implementation dependencies or manifests exist.

- Google Sign-In is a stated runtime dependency, subject to current official Android/Web integration guidance.
- Prefer maintained packages with security update and license information.
- Pin versions for repeatable builds once implementation manifests exist.
- Review transitive dependencies for credentials, telemetry, and privacy impact.
- Do not select a database, framework, cloud provider, or logging system without an explicit documented decision.
- Upgrade authentication integrations only with account-linking and session compatibility tests.
