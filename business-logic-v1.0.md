# Business Logic

> Development of an `Android and Web` `offline-first community health companion app` using `Flutter (Android), React (Web dashboard) and a Supabase/PostgreSQL backend` for `Barangay Health Workers (BHWs), rural health units and residents of geographically isolated and disadvantaged areas (GIDA), including Indigenous Peoples communities, in the Philippines.`

- Allowed Platforms: Web, Android

## Project Details

- Company/Startup/Team Name: `Fructose`
- Project Code Name: `Capsicum`
- Project Short Code: `CM`
- Short Description: `Capsicum is an offline-first app that helps Barangay Health Workers in remote, underserved communities record basic health checks, track follow-ups, report environmental health hazards, and share health education in local languages, even without internet.`
- Long Description: `Many GIDA and Indigenous communities are hours away from the nearest rural health unit, with unreliable signal and paper-based records that get lost or arrive late. Capsicum gives Barangay Health Workers (BHWs) a simple Android app that works fully offline: they log routine checks (blood pressure, blood sugar, weight and height of children, pregnancy visits, immunization status), get reminders for follow-ups and referrals, and report environmental risks such as unsafe water sources, garbage build-up or mosquito breeding sites. Data syncs when a connection is available. Rural health midwives, nurses and volunteer physicians (Moderators) review flagged entries and give guidance, while municipal health officers (Administrators) see anonymized, aggregated dashboards that help prioritize outreach, medicine supply and sanitation projects. Residents and the public (Guests) can read health education in local languages and view community-level advisories. Capsicum is a **support and referral tool, not a diagnostic tool**: it flags values outside reference ranges for clinician review and prompts referral, and it never gives a diagnosis or treatment.`

## User Levels

> Note: Modify/rename the list of users based on the actual users that you expect to use the system.

| User Level | Description |
| --- | --- |
| A. System Administrator | Maintains/overrides system/server configurations, manages encryption keys and retention jobs, and performs regular backups. |
| B. Administrator | Municipal/City Health Office or NGO program coordinator. Manages general settings, onboards BHWs and Moderators, and generates periodic anonymized analytics and reports. |
| C. Moderator | Rural health midwife, nurse or volunteer physician. Reviews flagged entries and referrals, validates hazard reports, approves health education content, and gives guidance to BHWs. |
| D. Contributor | Barangay Health Worker (BHW) or trained community volunteer. Records health checks with resident consent, logs follow-ups, and submits environmental hazard reports. |
| E. Guest | Users who do not log in, but view limited contents on the app/web (health education articles, community advisories, nearest health facility info). |

## System Requirements

1. The app shall allow the users to authenticate using Google Sign-In integration.
2. The app shall allow Contributors to record basic health checks (blood pressure, blood glucose, weight/height, pregnancy and immunization visits) offline and sync automatically when a connection is available.
3. The app shall capture and store the resident's informed consent (in the resident's language) before any health data is recorded.
4. The app shall flag recorded values that fall outside standard reference ranges and prompt the Contributor to refer the resident to a Moderator or health facility, without displaying any diagnosis.
5. The app shall remind Contributors of upcoming follow-ups, immunization schedules and prenatal visits.
6. The app shall allow Contributors to submit environmental hazard reports (unsafe water source, poor sanitation, garbage, mosquito breeding sites) with a photo and a purok/sitio-level location only.
7. The app shall allow Moderators to review, comment on, approve or escalate flagged entries, referrals and hazard reports.
8. The app shall provide health education content (short text, icons and audio) in Filipino, English and selectable local languages, available offline.
9. The app shall allow Administrators to view anonymized, aggregated dashboards (e.g., cases per purok, vaccination coverage, hazard hotspots) and export periodic reports.
10. The app shall allow Administrators to manage user accounts, roles, assigned barangays, and content categories.
11. The app shall let Guests browse health education and public advisories without logging in.
12. The app shall allow the System Administrator to configure data retention periods, run backups and review system health.

## Required Solution Layers

1. Security and privacy by design. Data Privacy Act (RA 10173) compliance, location protection (purok/sitio-level only, no GPS tracks), retention limits, no per-user trails, aggregation thresholds (no dashboard group below a minimum size, e.g., fewer than 10 people), and consent for any data resale (no resale of health data by default).
2. Health data is sensitive personal information: encrypted at rest and in transit, encrypted local storage on devices, remote wipe for lost phones, and role-based access limited to the minimum necessary.
3. Clinical safety: all reference ranges and referral rules come from published Department of Health guidelines and are reviewed by a licensed clinician before release. The app never diagnoses or prescribes.
4. Offline-first and low-resource design: works on low-end Android devices, small data footprint, and conflict-safe sync.
5. Cultural and language accessibility: local language support, icon-driven UI, and community validation of content with leaders and elders.

## MVP Features and Access

> See the User Levels table for reference.

| Feature | Access |
| --- | --- |
| 1. Health education and public advisories (offline, multilingual) | A,B,C,D,E |
| 2. Google Sign-In and role-based access | A,B,C,D |
| 3. Resident consent capture and basic health check logging | A,B,C,D |
| 4. Follow-up and immunization/prenatal reminders | A,B,C,D |
| 5. Environmental hazard reporting | A,B,C,D |
| 6. Flagged-entry review, referral and guidance | A,B,C |
| 7. Education content management and approval | A,B,C |
| 8. User, barangay and role management | A,B |
| 9. Anonymized analytics dashboard and report export | A,B |
| 10. Retention settings, backups and server configuration | A |

## Notes

- Clinical advisor: the team's internal medicine contact (a physician) should review reference ranges, referral thresholds, and education content before any pilot. Document her review in the repo.
- Start with a single-barangay pilot, co-designed with the local Rural Health Unit and barangay leaders, before scaling.
- Check the latest DOH guidelines and local government unit requirements for health data handling, and consider consulting a data privacy officer before collecting real data. Register or coordinate with the National Privacy Commission as needed.
- Use synthetic data throughout development and testing; never use real resident data.
- Possible later features (post-MVP): SMS fallback for reminders, medicine stock tracking for the health center, and a school-based health module for teachers.
