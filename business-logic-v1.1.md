# Business Logic v1.1

**Status:** Integrated revision. Pilot-specific decisions remain open as listed in Section 7.

## 1. Positioning

> Capsicum is an offline-first community health record and referral-support tool for Barangay Health Workers (BHWs) serving geographically isolated and disadvantaged areas (GIDA) in the Philippines.

- **Primary user:** A BHW using an Android phone, often offline or sharing a low-resource device.
- **Primary value:** Capture a consented community health encounter once, preserve it offline, and make its follow-up or referral visible to the assigned RHU when connectivity returns.
- **Supporting value:** Give authorized health workers a concise review queue and give health leaders privacy-protected community summaries.
- **Product boundary:** Capsicum supports recordkeeping, reminders, referral, and health education. It is not a diagnostic, prescribing, emergency-response, or clinical decision-making system.
- **Initial deployment:** One barangay and its partner RHU, co-designed with BHWs, community representatives, and local health leadership before expansion.

### Project details

- **Team:** Fructose
- **Code name / short code:** Capsicum / CM
- **Platforms:** Flutter Android app for BHW field work; React Web dashboard for RHU and program staff; Supabase/PostgreSQL backend, subject to technical validation.
- **Target users:** BHWs and trained community volunteers; RHU moderators; municipal/city health or NGO administrators; public readers of approved health information.

## 2. User levels

| Level | User | MVP responsibilities and limits |
|---|---|---|
| A. System Administrator | Trusted technical operator | Configures service access, retention, backup and recovery; manages operational incidents. Cannot use broad technical access as a substitute for clinical authorization. |
| B. Administrator | Municipal/City Health Office or NGO program coordinator | Assigns accounts and barangay scope; publishes approved content; views threshold-protected summaries. No routine access to identifiable encounter details. |
| C. Moderator | RHU midwife, nurse, or authorized clinician | Reviews assigned referrals and hazard reports, records follow-up disposition, and approves health content. Clinical decisions remain with qualified health professionals. |
| D. Contributor | BHW or trained community volunteer | Records consented encounters and follow-ups for assigned communities; submits structured hazard reports. Cannot review other barangays or change clinical rules. |
| E. Guest | Resident or public reader | Views approved public education, advisories, and facility information without an account; cannot access resident records or dashboards. |

Access is enforced by the backend for every record and action. Client-side hiding is not authorization. Define whether a Moderator or Administrator may also contribute before pilot onboarding.

## 3. MVP requirements

1. **Sign-in and offline access:** Contributors, Moderators, and Administrators sign in with Google when online. An already authorized Android user can continue permitted field work offline; define device lock, session-expiry, revocation, and re-authentication behavior before pilot. Guest content requires no sign-in.
2. **Minimal resident record:** Create or find a resident using the minimum RHU-approved identifying information and a non-meaningful app identifier. Define duplicate matching and correction before development; do not use GPS or collect unnecessary profile fields.
3. **Consent:** Before saving health information, capture the approved consent version and language, decision, time, and responsible Contributor. Provide a refusal path that saves no health encounter and does not block access to public information. Define guardian consent for minors and how withdrawal affects future collection and retained records.
4. **One pilot clinical workflow:** Record only the visit type and fields selected with the partner RHU for the first pilot. Recommended starting scope is a routine adult check and its follow-up/referral, rather than launching pregnancy, immunization, child-growth, and glucose workflows all at once. Every field, unit, validation, and referral rule must be approved by a licensed clinician against current Department of Health guidance before real-data use.
5. **Offline capture and sync:** Save encrypted records locally, show pending/synced/error status, retry safely, and prevent duplicate server records on repeated sync. Define conflict handling and recovery for device loss or failed sync. Never silently discard a saved encounter.
6. **Follow-up and referral:** Let a Contributor assign a due date and destination from an approved workflow. Show the task to the assigned worker and Moderator after sync. The app does not promise that anyone is monitoring an offline device or that a referral has been received until acknowledged.
7. **Hazard reports:** Submit a short structured report with hazard category and purok/sitio-level location; route it to a Moderator for disposition. Defer photo attachments in the first pilot unless the community and privacy review establish a clear need and safe handling.
8. **Health information:** Bundle a small, approved set of short text and icon-based education/advisory content for offline Android access and public Web viewing. Launch with Filipino and English plus one pilot-selected local language. A Moderator owns approval and expiry/revision of advisories. Defer audio production and a full content-management workflow.
9. **Moderator review:** Provide one Web queue for assigned referrals and hazards with status, comment, and disposition. Require a clear handoff outcome such as reviewed, follow-up requested, referred, or closed; configure available values with the RHU.
10. **Administrator summary:** Show a small set of agreed barangay-level counts and trends only after suppression rules are applied. No resident-level dashboard or row-level health-data export in the MVP. Apply suppression to every filter and export, not just the initial chart.
11. **Account administration:** Administrators manage named users, roles, and barangay assignments. System Administrators handle service configuration and backup/recovery. Do not build a broad self-service onboarding portal for the pilot.
12. **Data lifecycle:** Define retention by record type, correction/deletion handling, backup expiry, and device-loss response before real data is collected. No sale or commercial reuse of health data in the MVP.

## 4. Required solution layers

1. **Privacy and security:** Treat health data as sensitive personal information. Encrypt transport, server storage, and local device storage; enforce least-privilege role and barangay access; protect backups; and provide a documented lost-device response. No GPS tracks, background location, or nonessential resident activity tracking.
2. **Consent and data minimization:** Use approved, versioned consent text in the resident's language. Collect only what the selected workflow needs. Do not use consent for unrelated secondary use or data resale; resale is out of MVP scope.
3. **Safe aggregation:** Suppress small groups in dashboards and exports. The proposed threshold of fewer than 10 people is a starting point for privacy review, not a validated guarantee; test combinations of filters and locations for re-identification risk.
4. **Clinical safety:** Do not ship reference ranges, warning labels, or referral rules until a licensed clinician documents review of the exact source, population, units, and content version. Show referral prompts, never diagnoses or treatment recommendations.
5. **Offline reliability:** Make local save status explicit, keep retries idempotent, retain recoverable data through app restarts, and communicate that an unsynced referral has not reached the RHU.
6. **Accessibility and cultural fit:** Validate terminology, translations, icons, and workflows with BHWs and community representatives, including Indigenous Peoples communities where the pilot operates.
7. **Privacy operations:** Keep only the security audit events needed to investigate access and changes, restrict who can review them, and set a retention period. “No per-user trails” means no continuous tracking or analytics profiling; it must not prevent a minimal, protected security audit.

## 5. MVP features and access

| Feature | A | B | C | D | E |
|---|---:|---:|---:|---:|---:|
| 1. Approved public education and advisories (Web; offline Android bundle) | Read | Read | Read | Read | Read |
| 2. Sign-in, role, and barangay-scoped account access | Manage service | Manage users | Assigned scope | Assigned scope | No account |
| 3. Consent and the single pilot-approved encounter workflow | — | — | Assigned review | Create for assigned community | — |
| 4. Offline follow-up/referral queue and Moderator disposition | — | — | Review assigned | Create and track assigned | — |
| 5. Structured hazard reporting and review | — | Summary only | Review assigned | Submit for assigned community | — |
| 6. Suppressed barangay-level summary | — | View | — | — | — |
| 7. Retention, backup, recovery, and system health operations | Configure | — | — | — | — |

`—` means no access. Each role's exact data scope must be enforced server-side. The MVP excludes resident-level exports, photo uploads, SMS delivery, medicine inventory, school workflows, and diagnosis or treatment features.

## 6. Pilot acceptance gates

Do not pilot with real resident data until all applicable gates pass:

- The partner RHU and community representatives approve the chosen workflow, language set, consent process, and referral handoff.
- A licensed clinician approves the exact clinical fields, units, reference sources, and referral wording for the pilot.
- A Contributor can save an encounter offline, restart the app, see its pending status, and sync it once without data loss or duplication.
- A Moderator can see and disposition a synced assigned referral; the Contributor can distinguish pending, acknowledged, and closed states.
- Automated access tests confirm that unauthorized roles and other barangays cannot read or change records.
- Dashboard suppression is tested against filters and exports; small groups and combinations that could reveal individuals are not exposed.
- Retention, backup restoration, device-loss response, and deletion/correction procedures are exercised with synthetic data.
- The team records baseline and pilot measures agreed with the RHU, such as completion of follow-up tasks and record-sync success, using aggregate reporting rather than resident tracking.

## 7. Decisions required before build freeze

| Decision | Required owner | Why it blocks a safe, testable MVP |
|---|---|---|
| Pilot barangay, partner RHU, target population, and one supported visit workflow | Product lead and RHU | Determines forms, access scope, training, and success measures. |
| Resident matching fields, duplicate handling, and minor/guardian consent | RHU and privacy lead | Prevents mistaken record merges and unclear consent. |
| Clinical references, exact units, threshold behavior, referral destination, and escalation wording | Licensed clinician and RHU | “Standard reference range” is not specific enough to implement safely. |
| Supported device/Android baseline and offline re-authentication policy | Product and technical leads | Determines whether field users can work safely on shared or lost devices. |
| Pilot language and approved content owners/expiry | Community representatives and RHU | “Selectable local languages” is not a deliverable without a named language and review process. |
| Retention schedule, correction/deletion, audit events, backup expiry, and recovery owner | Privacy lead and System Administrator | “Retention limits” alone cannot drive implementation or operations. |
| Aggregation threshold and permitted summary metrics | Privacy lead and Administrator | Prevents dashboards or exports from revealing individuals through small groups. |
| Baseline and pilot success measures | RHU and product lead | Enables a go/no-go decision without expanding into unnecessary analytics. |

## 8. Notes and explicit deferrals

- Use synthetic data for development, demonstrations, and tests; do not use real resident data until the required reviews and operational gates are complete.
- Before a pilot, have the appropriate privacy lead assess the applicable Philippine privacy obligations and coordinate with the National Privacy Commission or other authorities as needed.
- Start with one barangay and a short training/onboarding process. Document who handles support, unsynced records, device loss, and referral follow-up.
- Review current Department of Health materials and record the exact approved source/version used for the pilot workflow.
- **Post-MVP candidates, not commitments:** additional clinical workflows (pregnancy, immunization, child growth, glucose), hazard photos, more local languages or audio, content self-service, row-level exports if separately justified, SMS fallback, medicine stock, and school health.
