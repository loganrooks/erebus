# 0008 — Pre-setup gap analysis (pass 4)

- **Status:** proposed
- **Date:** 2026-05-24
- **Author:** Claude Code (claude-opus-4-7) — fourth-pass audit
- **Related ADRs:** archive/0001 (pass-1 audit, resolved),
  0002 (pass-1 resolution plan),
  0003 (name + license),
  archive/0004 (pass-2 audit, resolved),
  0005 (pass-2 resolution plan),
  archive/0006 (pass-3 audit, resolved),
  0007 (pass-3 resolution plan)
- **Related REQ-IDs:** (none — this is meta)
- **Related anchors:** (none — this is meta)

## Context

Fourth-pass cold-read audit of the pre-setup documentation set,
performed without reading the archived prior-pass audits or their
resolution plans. The scope is the 10 documents listed in the
audit prompt and `docs/decisions/0003-name-and-license.md` for
ADR-format context. The aim is to surface any remaining
contradiction, ambiguity, missing guardrail, or tooling assumption
before the agent executing Goal 0 begins repo bootstrap work.

The doc set is mature. The findings below are mostly polish and
forward-tense risks; no item blocks Goal 0 from starting.

## Findings

### Finding 1 — `AGENTS.md` Rule 4 points at a section that doesn't exist

- **Axis:** 1 (Internal contradictions); 5 (Missing guardrails)
- **Severity:** SHOULD-resolve
- **Evidence:** `AGENTS.md:53–56`:
  > "If a stage needs something not in `pyproject.toml`, update
  > `docs/REQUIREMENTS.md` §"Dependencies" with the rationale, then
  > rerun the pre-setup audit before installing."

  `docs/REQUIREMENTS.md` has no `## Dependencies` section. Top-level
  sections are Architecture, Ingest, Concat, Grade, Visualize,
  Caption, Mix, Encode, Lab, CLI, Security, Observability,
  Documentation, Integration, Out-of-scope for Phase 1, Change log.
  Dependencies are listed in `PROJECT.md` §11 ("Dependencies
  (Phase 1)") and in `pyproject.toml`.
- **Issue:** Rule 4 of the non-negotiable agent rules tells the
  agent to update a section that does not exist. The rule is
  unfollowable as written. The first time a Phase-1 stage requires
  a new dep, the agent will either invent a section heading,
  modify the wrong file, or stall.
- **Suggested resolution:** Either (a) add a `## Dependencies`
  section to `REQUIREMENTS.md` listing the Phase-1 deps with their
  rationale (mirroring `PROJECT.md` §11 in REQ form, e.g.
  `REQ-DEP-001` for the runtime set), or (b) edit `AGENTS.md` Rule
  4 to reference `PROJECT.md` §11 instead.

### Finding 2 — `yt-dlp` is both a Python dependency and a host binary

- **Axis:** 1 (Internal contradictions); 7 (Tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `PROJECT.md:439` lists `yt-dlp` under "External
  binaries". `docs/REPO_SETUP.md:184` and `docs/REPO_SETUP.md:24–37`
  treat `yt-dlp` as a host binary verified at preflight.
  `REQ-SEC-005` (`docs/REQUIREMENTS.md:338–346`) says: "The host
  pre-flight check in `docs/REPO_SETUP.md` §1 SHALL verify that the
  installed `yt-dlp` binary meets the declared minimum. A
  user-supplied environment variable `EREBUS_YT_DLP_BIN` MAY
  override the binary path." `pyproject.toml` (`docs/REPO_SETUP.md:184`)
  also declares `"yt-dlp >= 2024.7.16"` as a Python dependency, so
  `uv sync` installs a venv-local `yt-dlp` binary alongside any
  host one.
- **Issue:** Two installations of `yt-dlp` can exist simultaneously
  (host + venv). Which one the `ingest` stage invokes is
  unspecified. `EREBUS_YT_DLP_BIN` lets the operator pick, but the
  default behaviour isn't stated. If the venv's `yt-dlp` is the
  one called (typical for `uv run`), the host-binary preflight in
  §1 protects nothing.
- **Suggested resolution:** Decide whether the stage calls
  `yt-dlp` as a subprocess or imports it as a Python package
  (`yt_dlp.YoutubeDL`). State the default resolution order
  (`EREBUS_YT_DLP_BIN` → venv binary → PATH binary, or whichever
  it actually is) in `REQ-SEC-005` and adjust the preflight check
  to verify the resolved binary, not necessarily the PATH one.

### Finding 3 — Audit ADRs use `Author:`; template and meta-test expect `Author(s):`

- **Axis:** 1 (Internal contradictions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/decisions/TEMPLATE.md:5`:
  > "- **Author(s):** <name(s) or agent identifier>"

  `docs/TEST_SPEC.md:598`:
  > "Each ADR contains a `Status:`, `Date:`, `Author(s):` line."

  The pass-4 invocation wrapper (this document's prompt) prescribes
  `**Author:**` (singular). `docs/decisions/0003-name-and-license.md:5`
  uses `**Author(s):**` (plural) and matches the template.
- **Issue:** When `test_adr_files_match_template` lands in Phase 1
  (it is a planned anchor in `TEST_SPEC.md`), it will check
  every file under `docs/decisions/` for the literal `Author(s):`
  marker. The current and prior pre-setup audit files written under
  the wrapper convention use `Author:` and will fail the check.
  Whether the test recurses into `archive/` depends on its
  implementation; live audits (0007, 0008) are definitely in scope.
- **Suggested resolution:** Either (a) change the pass-N audit
  wrapper to use `**Author(s):**`, then update existing pre-setup
  audits in `docs/decisions/` and `docs/decisions/archive/` in a
  single sweep before Phase 1, or (b) loosen the anchor's
  assertion to accept `Author:` or `Author(s):`.

### Finding 4 — `test_mix_video_audio_lowpassed` may be infeasible with a single ffmpeg `lowpass` filter

- **Axis:** 3 (Ambiguity); 4 (Anti-tautology)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/TEST_SPEC.md:323–335` asserts:
  > "Energy at frequencies more than 2× the cutoff is attenuated
  > by at least 20 dB relative to input."

  `REQ-MIX-002` (`docs/REQUIREMENTS.md:217–219`) mandates "filtered
  with `lowpass=f=<lowpass_hz>`" — a single filter invocation.
  ffmpeg's `lowpass` filter is a biquad (2 poles, default
  `poles=2`) and rolls off at roughly 12 dB/octave above cutoff.
  At 2× cutoff (one octave above), attenuation is approximately
  12 dB, not 20 dB.
- **Issue:** A faithful implementation of REQ-MIX-002 (one
  `lowpass=f=1800` invocation) fails the anchor's 20 dB-at-2×
  assertion. The fix requires either chaining two `lowpass` calls
  (deviates from REQ phrasing) or relaxing the anchor's threshold
  to roughly 12 dB.
- **Suggested resolution:** Either loosen the anchor to
  `≥10 dB at 2× cutoff` (matches default biquad), or amend
  REQ-MIX-002 to permit a higher-order filter (e.g., explicit pole
  count or a documented chained `lowpass`).

### Finding 5 — Pre-commit hook versions are roughly two years stale

- **Axis:** 7 (Tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md:246–278` pins:
  - `pre-commit/pre-commit-hooks` `v5.0.0`
  - `astral-sh/ruff-pre-commit` `v0.5.0`
  - `pre-commit/mirrors-mypy` `v1.10.0`
  - `gitleaks/gitleaks` `v8.18.4`

  These are mid-2024 releases. The project's stated "today" is
  2026-05-24 per the session context, roughly two years on. Pinned
  mypy 1.10 predates several relevant strict-mode improvements and
  may not play cleanly with current pydantic 2.x type plugins.
- **Issue:** Stale hook pins surface as flaky CI either at
  bootstrap or shortly after, and they widen the gap between local
  pre-commit behaviour and whatever versions Logan has installed
  globally.
- **Suggested resolution:** Bump pins to the most-recent stable
  releases at bootstrap time and record the chosen versions in an
  ADR. Reverify locally before committing the bootstrap.

### Finding 6 — Fonts referenced in the cyberpsycho preset have no provenance path

- **Axis:** 7 (Tool assumptions); 8 (Public-repo risks)
- **Severity:** SHOULD-resolve
- **Evidence:** `PROJECT.md:206`, `PROJECT.md:213` reference
  `fonts/Rajdhani-Medium.ttf` and `fonts/Rajdhani-SemiBold.ttf`
  in the preset block. `PROJECT.md:450`: "Fonts: Rajdhani (Google
  Fonts, OFL)." `docs/REPO_SETUP.md` §3.6 (the skeleton) does not
  create a `fonts/` directory or document where the font files
  come from. The `.gitignore` (`docs/REPO_SETUP.md:103–148`) does
  not mention `fonts/`.
- **Issue:** Phase 1 cannot render the cyberpsycho preset (REQ-
  CAPTION-001 through REQ-CAPTION-003, REQ-INTEG-001) without
  these font files. The project has neither a script to fetch them
  nor a committed copy. The agent will block at the first caption
  render until Logan supplies them manually.
- **Suggested resolution:** Either (a) commit the fonts under
  `fonts/` with the OFL license text alongside (and record
  provenance per REQ-SEC-006 phrasing), or (b) add a fetch script
  under `scripts/` analogous to `scripts/generate_fixtures.py` and
  reference it in `REPO_SETUP.md`. Update `.gitignore` accordingly.

### Finding 7 — REQ-INGEST-001 mandates mp4 output; REQ-INGEST-005 allows a configurable format selector

- **Axis:** 3 (Ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:** `REQ-INGEST-001` (`docs/REQUIREMENTS.md:70–75`):
  > "Download every video as mp4 (best video + best audio,
  > merged)."

  `REQ-INGEST-005` (`docs/REQUIREMENTS.md:116–120`):
  > "The format selector string passed to yt-dlp SHOULD be
  > configurable via preset (default `bv*[height<=1080]+ba`), to
  > enable lower-quality downloads for testing or higher for
  > archival."
- **Issue:** A preset configuring a format selector that produces
  webm (e.g., `bv*[ext=webm]+ba`) satisfies REQ-INGEST-005 and
  violates REQ-INGEST-001. The interaction between the two REQs is
  unspecified.
- **Suggested resolution:** Either narrow REQ-INGEST-005 to
  "format selector configurable as long as the merged output is
  mp4", or relax REQ-INGEST-001 to "mp4 by default; preset-
  configurable container."

### Finding 8 — REQ-CAPTION-003 mandates fade timing but the implementation surface is unspecified

- **Axis:** 3 (Ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:** `REQ-CAPTION-003` (`docs/REQUIREMENTS.md:202–205`):
  > "Each caption MUST fade in over `fade_in_ms`, hold for
  > `hold_ms`, and fade out over `fade_out_ms` from the start of
  > its track."

  `REQ-CAPTION-002` requires the `drawtext enable=...` expression
  to carry timing. `PROJECT.md:282` shows the expected form:
  `enable='between(t,0,6)+between(t,212,218)+...'`. The
  `drawtext.enable` expression is binary (visible or not) and
  cannot natively express an alpha envelope. Fading in `drawtext`
  is normally done via an `alpha='...'` expression or a separate
  `fade` filter wrapped around the drawtext output. Neither path
  is named in the REQs.

  The matching anchor (`test_caption_fade_timing`,
  `docs/TEST_SPEC.md:289–300`) asserts "the generated alpha
  envelope (extractable from the drawtext expression)" — which
  presumes the implementation uses `drawtext`'s `alpha=` parameter.
- **Issue:** Two reasonable implementations (alpha expression
  inside drawtext, separate fade filter chained after drawtext)
  both satisfy REQ-CAPTION-003 but only one (alpha expression)
  satisfies the anchor's "extractable from the drawtext expression"
  phrasing.
- **Suggested resolution:** Pin the implementation strategy in
  REQ-CAPTION-003 by adding "implemented via `drawtext`'s `alpha=`
  expression, generated mechanically alongside `enable=`," and
  document the expected alpha-envelope form in the same place
  PROJECT.md §5 shows the `enable` form.

### Finding 9 — REQ-OBS-001 reverses the usual stdout/stderr convention

- **Axis:** 3 (Ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:** `REQ-OBS-001` (`docs/REQUIREMENTS.md:352–357`):
  > "Every stage MUST emit structured logs (JSON lines on stderr
  > by default, human-readable on stdout when a TTY is attached)."
- **Issue:** Mixing the two by stream is unusual. Most tooling
  either writes structured logs to stdout (so pipes capture them)
  and human progress to stderr, or writes everything to stderr.
  Sending JSON to stderr while sending human output to stdout
  means downstream pipelines that `2>/dev/null` (or redirect
  stderr to a file) lose the structured data while keeping the
  human progress. `rich`, listed as a dep in `pyproject.toml`,
  writes to stdout by default — this REQ implies the rich-driven
  output is the only stdout content while structured logs route
  elsewhere.
- **Suggested resolution:** Flip the convention so structured
  JSON goes to stdout and human-readable progress goes to stderr,
  or document explicitly why the inverted convention was chosen.

### Finding 10 — SHOULD-tagged REQs contain MUST/SHALL body language

- **Axis:** 3 (Ambiguity)
- **Severity:** SHOULD-resolve
- **Evidence:**
  - `REQ-CONCAT-003 [SHOULD, phase:1]` (`docs/REQUIREMENTS.md:137–142`)
    body: "The default order MUST be the order in the manifest…"
  - `REQ-VIZ-003 [SHOULD, phase:1]` (`docs/REQUIREMENTS.md:182–185`)
    body: "Each visualizer type MUST be selectable… and SHALL
    produce a filter chain valid in ffmpeg ≥ 6."
- **Issue:** The REQ header tag (SHOULD) determines deviation
  policy ("strong default; deviation needs an ADR"). The body's
  MUST/SHALL language implies "hard requirement." A reader cannot
  tell whether deviation from the body language requires an ADR
  (per the SHOULD tag) or constitutes a hard violation (per the
  body verbs).
- **Suggested resolution:** Either elevate the affected REQs to
  `[MUST]` or rewrite the body verbs to match SHOULD-tier language
  ("default order SHOULD be the manifest order"; "each visualizer
  type SHALL be selectable and SHOULD produce a valid filter
  chain").

### Finding 11 — `uv` and `gh` minimum versions are not pinned in the §1 preflight

- **Axis:** 7 (Tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md:15–21` runs:
  ```bash
  git --version          # ≥ 2.40
  gh --version           # GitHub CLI, authenticated
  uv --version           # Astral's uv package manager
  ```
  Only `git` carries a minimum-version assertion. `gh` and `uv`
  are merely invoked. ffmpeg and yt-dlp have explicit floors
  (`≥ 6.0`, `2024.7.16`).
- **Issue:** Old `uv` versions may not honour `pyproject.toml`
  fields used in §3.3, and old `gh` versions can lack `gh repo
  create --source=` (the flag used in §2). Without floors, the
  preflight can pass on a host that breaks at the first real
  invocation.
- **Suggested resolution:** Add explicit floors (e.g.,
  `gh --version` parsed against `≥ 2.40`, `uv --version` against
  `≥ 0.4`) using the same awk pattern as the yt-dlp check.

### Finding 12 — The hatchling build backend is not version-pinned

- **Axis:** 7 (Tool assumptions)
- **Severity:** SHOULD-resolve
- **Evidence:** `docs/REPO_SETUP.md:200–202`:
  ```toml
  [build-system]
  requires = ["hatchling"]
  build-backend = "hatchling.build"
  ```
- **Issue:** A future hatchling release with a breaking change
  could break the build of an existing-state repo. Other deps
  carry explicit floors (`pydantic >= 2.7`, `typer >= 0.12`).
- **Suggested resolution:** Pin a floor: `requires =
  ["hatchling >= 1.24"]` or similar.

### Finding 13 — "Section of bootstrap commit:" labels are confusing under §3's "one commit" framing

- **Axis:** 10 (Anything else)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md:88–99` introduces §3 as a
  single bootstrap commit. Each subsection then closes with a line
  like:
  > "Section of bootstrap commit: `chore: add .gitignore`."

  The labels look like commit messages, but §3's header explicitly
  says they describe section contents, not commit boundaries.
- **Issue:** An agent reading §3 quickly may misread the labels as
  separate-commit instructions and produce eight commits instead
  of one. The clarifying text at the top of §3 sits where a hurried
  reader skips.
- **Suggested resolution:** Replace the label format with a phrase
  that doesn't mimic a commit subject — for example,
  "Conventional-Commits style for analogous post-bootstrap work:
  `chore: …`."

### Finding 14 — REQ-MIX-004 measurement strategy is unspecified

- **Axis:** 3 (Ambiguity)
- **Severity:** CONSIDER
- **Evidence:** `REQ-MIX-004` (`docs/REQUIREMENTS.md:227–231`):
  > "In the final output, the music stream's perceived loudness
  > MUST be at least 8 dB higher than the video audio's."

  `test_mix_music_louder_than_video_audio`
  (`docs/TEST_SPEC.md:337–347`): "the integrated loudness of the
  music-only stream in the output exceeds the video-audio-only
  stream by ≥ 8 dB."
- **Issue:** Once mixed, the output is a single audio stream;
  there is no "music-only stream in the output" to measure. The
  intended methodology (run the mix twice with one input silenced
  each time, or measure inputs separately before mixing) is left
  to the implementer.
- **Suggested resolution:** Specify the measurement procedure in
  the anchor, e.g., "measured by running the mix stage twice: once
  with the video audio silenced (music-only contribution), once
  with the music silenced (video-audio-only contribution), and
  comparing their `ebur128` integrated-loudness values."

### Finding 15 — `test_cli_and_python_surfaces_share_implementation` requires byte-identical mp4 output

- **Axis:** 3 (Ambiguity); 4 (Anti-tautology)
- **Severity:** CONSIDER
- **Evidence:** `docs/TEST_SPEC.md:47–57`:
  > "`sha256(cli_output) == sha256(python_output)`."
- **Issue:** mp4 muxing writes a `creation_time` metadata field by
  default; two invocations of ffmpeg seconds apart produce mp4s
  with different `creation_time` and therefore different sha256s,
  even when every other byte matches. The anchor needs either
  `-metadata creation_time=…` pinning, `-fflags +bitexact`, or
  `-write_tmcd 0` discipline to be reliably falsifiable in only
  the intended way.
- **Suggested resolution:** Either weaken the assertion (compare
  decoded streams, or compare mp4 boxes excluding `mvhd`/`tkhd`
  timestamps), or require the stage to pass deterministic flags
  to ffmpeg that suppress timestamp metadata.

### Finding 16 — `test_concat_lossless_when_inputs_match` uses bitrate as a weak proxy

- **Axis:** 4 (Anti-tautology)
- **Severity:** CONSIDER
- **Evidence:** `docs/TEST_SPEC.md:156–169`:
  > "Output bitrate is within 5% of input bitrate (re-encoding
  > would change it more than that at default CRF). Total elapsed
  > time is less than would be required for full re-encode of the
  > inputs (heuristic threshold)."
- **Issue:** A high-quality re-encode (low CRF, slow preset) can
  produce a bitrate within 5% of the input on similar-content
  inputs. The elapsed-time check is a "heuristic threshold" with
  no concrete number. A lazy implementation that re-encodes at
  CRF 14 could pass both assertions.
- **Suggested resolution:** Replace the bitrate proxy with a
  direct check: parse the ffmpeg invocation and assert it uses
  `-f concat` with the demuxer protocol when inputs match, or
  inspect the output's frame-level metadata for re-encode
  signatures (e.g., `ffprobe -show_frames` byte hashes).

### Finding 17 — REQ-INTEG-001 references a "Phase-1 goal command" file that does not exist at Goal 0

- **Axis:** 1 (Internal contradictions)
- **Severity:** CONSIDER
- **Evidence:** `REQ-INTEG-001` (`docs/REQUIREMENTS.md:412–420`):
  > "MUST produce an output that simultaneously satisfies the
  > Phase-1 verification criteria in `PROJECT.md` §4 and the
  > acceptance points 1-4 in the Phase-1 goal command."

  `PROJECT.md:102–103`: "The current goals are Goal 0 (setup) and
  Goal 1 (Phase 1 development), stored in `goals/` after Goal 0
  lands." At Goal 0 the `goals/` directory does not yet exist.
- **Issue:** Forward reference. The REQ is anchored to a document
  that is not yet committed. Anyone trying to read the cross-
  reference at Goal-0 time finds a dangling pointer. After Goal 0
  lands, the file exists and the reference resolves.
- **Suggested resolution:** Either inline the "acceptance points
  1-4" verbatim into REQ-INTEG-001 (so the REQ is self-contained),
  or annotate the reference as forward-looking ("once `goals/`
  ships in Goal 0; until then, the acceptance points in this REQ
  are the four bullets above").

### Finding 18 — First-PR `review-artifact-exists` requirement is under-documented

- **Axis:** 6 (Workflow gaps)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md:590–612` defines the
  `review-artifact-exists` job that fails when no
  `docs/decisions/reviews/<PR>-*` file exists.
  `docs/REPO_SETUP.md:688` adds it to branch protection.
  `docs/WORKFLOW.md:142–149` mentions the artifact in the PR
  checklist. The flow for the very first non-bootstrap PR (where
  the agent is encountering the review checkpoint for the first
  time) is not documented in REPO_SETUP.md as part of Goal 0's
  setup steps.
- **Issue:** The first PR after bootstrap will block at
  `review-artifact-exists` until the agent runs the cross-vendor
  review per WORKFLOW.md §5. The path is documented in WORKFLOW.md
  but not flagged at the moment of branch-protection setup.
- **Suggested resolution:** Add a note at the end of
  `docs/REPO_SETUP.md` §4 explaining that the first non-bootstrap
  PR must produce a review artifact before merge, and link to
  WORKFLOW.md §5 for the invocation.

### Finding 19 — Bootstrap CI-red recovery path is unclear before branch protection lands

- **Axis:** 6 (Workflow gaps)
- **Severity:** CONSIDER
- **Evidence:** `docs/REPO_SETUP.md` §7 ("The initial green CI
  run", lines 772–782):
  > "If it doesn't [go green]: 1. Don't merge anything else.
  > 2. Open a `fix/ci-bootstrap` branch. 3. Diagnose and fix.
  > 4. Merge via PR."

  At that moment, branch protection (§4) has not been configured
  yet — §4 runs only "After the initial main branch has a green
  CI run." So `main` accepts direct pushes, and the agent could
  technically fix-forward on main. Branch-protection-required
  status checks are not yet active.

  `docs/WORKFLOW.md:14–17`: "Never push to `main` directly. Branch
  protection in GitHub enforces this; see REPO_SETUP.md." This
  rule presumes protection is on; at this moment, it isn't.
- **Issue:** The agent encounters a contradiction: WORKFLOW.md
  forbids direct main pushes; REPO_SETUP.md §7 prescribes a PR
  flow that depends on protection being active for "Required
  status checks" — but protection isn't on yet, so the PR could
  technically merge red. The intent is clearly "PR flow with the
  developer's discipline filling in for absent CI gating," but
  this isn't stated.
- **Suggested resolution:** Clarify in REPO_SETUP.md §7 that the
  agent SHALL still use the PR flow even though branch protection
  is not yet active, and SHALL gate merge on local verification
  (CI green on the PR + `pre-commit run --all-files`) rather than
  on automated enforcement.

### Finding 20 — `NOTES.md` is empty despite the prior audit passes

- **Axis:** 10 (Anything else)
- **Severity:** CONSIDER
- **Evidence:** `NOTES.md` body (lines 22 onward) contains only
  `<!-- entries below -->` and no entries. The repo's `git log`
  shows multiple post-bootstrap-style commits including
  `docs(adr): archive 0006 — 5 findings resolved, 9 deferred per
  0007` and earlier ADR-archive operations. `AGENTS.md:157–164`
  requires one journal line per agent turn.
- **Issue:** Either the journal rule applies only to coding work
  post-Goal-0 and the docs-only audit passes are exempt, or the
  rule is being silently elided. `AGENTS.md`'s rule doesn't carve
  out an exception. Two readings are possible.
- **Suggested resolution:** Add one sentence to `AGENTS.md`
  §"The journal (NOTES.md)" stating whether pre-Goal-0 audit
  passes append to NOTES.md, and either backfill the entries or
  document the exemption.

## Summary

- 20 findings total: 0 MUST-resolve, 12 SHOULD-resolve, 8 CONSIDER.
- No MUST-resolve findings remain. Goal-0 setup work may proceed.
- The SHOULD-resolve items are recommended fixes before Phase 1
  begins; none of them block the bootstrap commit itself. Items 1,
  3, 6, and 10 are the highest-leverage to clean up early because
  they create immediate friction once Phase 1 stage PRs start
  (rule references, ADR template enforcement, font dependency,
  REQ severity ambiguity).

## Resolution log

(Left empty for Logan to fill in as items are addressed.)
