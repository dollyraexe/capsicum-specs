# 09 - Security

**Purpose:** Define the current threat model, mandatory controls, and accepted gaps.

**Confidence note:** Verified against the business requirements and OWASP publication research; implementation controls are absent.

## Threat model
- Identity confusion or account takeover through Google Sign-In.
- Broken access control across A-E user levels.
- Excess location or personal-data collection.
- Re-identification through sparse aggregates.
- Unauthorized resale or secondary use.
- Injection, secret exposure, and excessive logging.

## Required controls
- Server-side authentication and role/resource authorization.
- Least collection, purpose limitation, retention limits, and deletion.
- Location protection and small-group aggregation thresholds.
- Explicit consent before data resale or secondary use.
- Input validation and parameterized data access.
- Secret management through environment variables, never source files.
- Security logging that excludes credentials and unnecessary personal data.

Until implementation exists, no authentication or security control is verified. Miss -> user data or administrative actions may be exposed.
