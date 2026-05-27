# Session log

Append-only. One line per task execution. Format:

```
<ISO 8601 UTC>\t<task_id>\t<status>\t<one-line summary>\t<duration_seconds>
```

Examples (illustrative, not yet real):

```
2026-05-26T14:00:00Z	P0-T1	COMPLETE	STATE.md initialized	2
2026-05-26T14:02:14Z	P0-T2	COMPLETE	expanded 10 phase docs into atomic task lists	340
```

---
