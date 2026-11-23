# 16 - Engineering Principles

**Purpose:** Define durable, quotable rules for the project.

**Confidence note:** Verified from the specification constraints and workspace evidence.

1. Server policy beats client behavior.
   Reason: UI controls can be bypassed; direct API access or modified clients can still reach a route.
   Evidence: role levels and security requirements in capsicum-specs/business-logic-v1.0.md.

2. Minimize data before minimizing endpoints.
   Reason: unnecessary personal or location data creates retention, breach, and re-identification exposure.
   Evidence: required privacy-by-design layer in capsicum-specs/business-logic-v1.0.md.

3. Keep mirrored sets synchronized.
   Reason: role lists, feature access, routes, schemas, and clients drift quickly when changed independently.
   Evidence: 04 cross-file change rules.

4. Verify the code before trusting a document.
   Reason: templates and handoff instructions can describe intended work rather than implemented behavior.
   Evidence: empty component directories and AGENTS.md files.

5. Retire stale knowledge in place.
   Reason: silent deletion erases contributor context and can make old assumptions look resolved.
   Evidence: 00 index and handoff maintenance rules.

Trust the code over any document, including this one.
