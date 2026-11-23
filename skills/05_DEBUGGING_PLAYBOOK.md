# 05 - Debugging Playbook

**Purpose:** Provide an initial diagnostic sequence until logs and runtime code exist.

**Confidence note:** No runtime logs or source commands are currently available.

## Workspace cannot build
1. Check for package/build manifests with a repository-wide file listing.
2. Inspect each component AGENTS.md; all are currently empty placeholders.
3. Verify that the intended source files or submodules were checked out.
4. Do not diagnose application failures until an executable entry point exists.

## Authorization symptom
Check the server-side route policy first. A passing UI check does not prove server protection.

## Google Sign-In symptom
Compare Android, Web, backend audience/issuer validation, account linking, and session creation. Never trust a client-only identity claim.

## Privacy symptom
Trace collection to storage, export, aggregation, resale, and deletion. A missing delete path usually indicates a model or retention-rule defect.
