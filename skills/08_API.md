# 08 - API

**Purpose:** Set the expected API surface until implementation exists.

**Confidence note:** No routes, framework, or response envelope are verified.

The API must:

1. Authenticate Google Sign-In tokens or sessions.
2. Authorize every route by server-side role and resource ownership.
3. Validate all input at the boundary.
4. Return a consistent success/error envelope only after implementation selects it.
5. Limit exports and reporting to authorized roles and approved aggregation thresholds.
6. Log security-relevant events without secrets or unnecessary personal identifiers.

Do not expose a route or role solely because a client button is present. Miss -> direct API access bypasses UI controls.
