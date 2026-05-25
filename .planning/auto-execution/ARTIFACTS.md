# Artifacts registry

Append-only registry of files produced by /goal during Phase-1
execution. Used for audit, rollback, and the DONE.md summary.

Format: markdown table.

| Path | Phase | Task | Created (UTC) | sha256 (first 16) |
|---|---|---|---|---|

(table populated by /goal as artifacts land)
