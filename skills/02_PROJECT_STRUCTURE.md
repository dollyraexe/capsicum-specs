# 02 - Project Structure

**Purpose:** Map the workspace and state where implementation and specification changes belong.

**Confidence note:** Verified from the 2026-11-23 workspace inventory.

```text
capsicum-api/      Empty placeholder for back-end implementation
capsicum-android/  Empty placeholder for Android implementation
capsicum-web/      Empty placeholder for Web implementation
capsicum-specs/    Business logic, research, git rules, and skills
```

| Change | Place |
|---|---|
| API code, schema, and server tests | capsicum-api |
| Android code and Android tests | capsicum-android |
| Web code and Web tests | capsicum-web |
| Requirements, architecture, and cross-repo conventions | capsicum-specs |

Do not put feature implementation directly in capsicum-specs. Do not infer a framework or package layout until manifests are added; speculative names hide drift.
