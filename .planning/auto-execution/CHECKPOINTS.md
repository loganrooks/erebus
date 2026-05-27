# Checkpoints summary

Append-only summary; one block per phase completion. Detail in
`checkpoints/CHECKPOINT-PN.md`.

Each block records:
- Phase ID
- Completion timestamp
- Tasks completed (count + brief list)
- Artifacts (count + pointer to per-phase checkpoint file)
- Verified postconditions
- Cost estimate (sessions, tokens, runtime)
- Link to the merged PR

---

(populated by /goal at phase boundaries)
