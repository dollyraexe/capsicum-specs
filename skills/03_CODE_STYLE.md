# 03 - Code Style

**Purpose:** Capture implementation conventions once code exists and preserve the repository's commit conventions now.

**Confidence note:** Verified for specifications and git guidelines; implementation style is unavailable.

- Name product scopes as code-name-api/<feature>, code-name-app/<feature>, code-name-web/<feature>, or code-name-specs/<feature>.
- Begin commits with a lowercase imperative scope and summary of 50 characters or fewer.
- Keep specification commits focused on requirements or document type, such as code-name-specs/design.
- Explain why a change exists, not merely what changed.
- Log errors with useful context and no secrets or personal data.
- Apply authorization and privacy checks server-side. Miss -> clients can be bypassed.
- Keep placeholder text out of production code. Miss -> ambiguous behavior reaches users.

No implementation language convention is established. Add it only after a real manifest and source entry point are verified.
