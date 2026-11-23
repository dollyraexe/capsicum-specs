# 12 - Performance

**Purpose:** Separate known performance constraints from invented targets.

**Confidence note:** No hot paths or measurable limits are available.

No latency, throughput, payload, memory, or cost limits are specified. Do not invent SLOs. Before optimization:

1. Measure real Web and Android API operations.
2. Identify expensive authentication, aggregation, export, and report queries.
3. Profile server and client separately.
4. Preserve privacy limits and access controls during caching.
5. Leave code untouched unless measured evidence and a testable budget justify it.
