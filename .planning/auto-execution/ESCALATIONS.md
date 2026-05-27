# Escalations index

Append-only. One line per escalation event. Detail in
`escalations/ESCALATION-<ts>.md`. Format:

```
<ISO 8601 UTC>\t<task_id>\t<kind>\t<status>\t<path>
```

Where `status` is `open` | `resolved` | `blocked` | `superseded`.

Examples (illustrative):

```
2026-05-26T15:20:00Z	P0-T4	smoke-test	resolved	escalations/ESCALATION-20260526T152000Z-smoke.md
2026-05-26T17:45:00Z	P3-T7	human-gate-lab-clip	open	escalations/ESCALATION-20260526T174500Z-grade-lab.md
```

---
