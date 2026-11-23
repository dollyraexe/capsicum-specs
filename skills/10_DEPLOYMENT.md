# 10 - Deployment

**Purpose:** Define release sequencing and checks before deployable components exist.

**Confidence note:** No deployment configuration or environments are present.

1. Deploy database migrations and compatibility changes before consumers.
2. Deploy API before clients whose contracts depend on it.
3. Deploy Web and Android only after API contract verification.
4. Verify authentication configuration, role policies, privacy settings, secrets, and rollback steps.
5. Tag releases with component and version; do not infer a semantic policy from repository structure.

No CI/CD, hosting, environment names, or tags are discoverable. Do not claim a release process until manifests and pipelines are verified.
