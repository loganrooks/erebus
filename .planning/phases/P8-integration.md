# P8 — End-to-end integration

- **Source ADR:** `docs/decisions/0011-phase-1-orchestration.md`
- **Branch:** `phase/p8-integration`
- **Predecessor:** P7 merged + `CHECKPOINT-P7.md` written
- **Lab clip:** the actual end-to-end Phase-1 deliverable
- **HUMAN-GATE:** HUMAN-GATE-7 (final acceptance)

## Scope

Wire the seven stages into the end-to-end CLI command:

```
erebus render --preset cyberpsycho \
  --videos <playlist-url> \
  --music <playlist-url> \
  --out out.mp4
```

Verify against the verification surface in PROJECT.md §4.

## REQ-IDs in scope

- **REQ-INTEG-001 [MUST]** — End-to-end Phase-1 verification
- **REQ-CLI-001 [MUST]** — `erebus render` command exists
- **REQ-CLI-002 [MUST]** — `--max-duration` cap (added here if
  not landed earlier)
- **REQ-CLI-003 [SHOULD]** — Helpful error messages
- **REQ-ARCH-001 [MUST]** — Two-track surface (CLI and Python)
- **REQ-ARCH-002 [MUST]** — Stage isolation verified
  end-to-end
- **REQ-OBS-001/-002 [MUST]** — Structured logs and exit codes
  end-to-end

## Anchor tests

1. `test_phase1_integration` (REQ-INTEG-001) — **the
   acceptance anchor**. Runs `erebus render` end-to-end on
   the synthetic cyberpsycho+mix playlists; asserts the
   precise output properties from TEST_SPEC.md
   §"End-to-end integration".
2. `test_stage_callable_in_isolation` (REQ-ARCH-002) —
   verify each stage's public entry point still works
   directly after integration.
3. `test_cli_and_python_surfaces_share_implementation`
   (REQ-ARCH-001) — meta-test: CLI command and Python
   call produce identical artifacts.
4. `test_render_max_duration_caps_output` (REQ-CLI-002)
5. `test_stage_logs_are_structured` (REQ-OBS-001)
6. `test_exit_codes_distinct_per_failure_class` (REQ-OBS-002)

## Task overview

1. **P8-T1 — Failing `test_phase1_integration`.** This is the
   load-bearing anchor; everything else in P8 is the
   implementation that turns it green.
2. **P8-T2 — Implement `erebus/cli.py` `render` command**
   (Typer-based, wiring the seven stages).
3. **P8-T3 — Stage-isolation verification test.**
4. **P8-T4 — CLI ↔ Python surface equivalence test.**
5. **P8-T5 — `--max-duration` test + implementation.**
6. **P8-T6 — Observability anchors (logs, exit codes).**
7. **P8-T7 — Run end-to-end on supplied playlists** (the real
   ones, not just the synthetic fixture). Render the actual
   Phase-1 deliverable.
8. **P8-T8 — HUMAN-GATE-7 escalation:** "Phase-1 end-to-end
   render ready for final review at `lab/outputs/p8-phase1-*.mp4`.
   Please play and approve."
9. **P8-T9 — On approve: PR, review, merge.**

## Dependencies

- **Upstream:** P1–P7 all merged with their lab clips approved.
- **Downstream:** P9 (final).

## Postconditions

- `test_phase1_integration` passes on `main`.
- All P8 anchor tests pass.
- The Phase-1 deliverable (`out.mp4` from the supplied
  playlists) exists and is approved by Logan.
- PR merged.

## Deferred backlog items folded in

- 0005 F-8 — `erebus.stages.render` absent from skeleton (KEEP;
  resolved by P8-T2 — the orchestrator API IS the `render`
  command + its Python equivalent)
- 0009 F-9 — REQ-OBS-001 stdout/stderr convention inverted
  (KEEP; resolved by P8-T6)
- 0009 F-17 — REQ-INTEG-001 references not-yet-existing
  Phase-1 goal file (DROP; the goal file IS this PR's planning
  surface)

## Notes

- The supplied playlists referenced in PROJECT.md §4 are
  Logan's actual cyberpsycho and mix playlists. P8-T7 is the
  first time real-data render happens; expect it to surface
  issues the synthetic fixtures missed.
- HUMAN-GATE-7 is the load-bearing acceptance. If Logan
  rejects, the failure mode determines whether to escalate
  to a re-plan ADR or to iterate on stage-level tuning.
