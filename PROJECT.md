# erebus

A toolkit for assembling cyberpsycho-styled background video mixes from
YouTube playlists. Two paths to the same engine: an agent-friendly
Python tool surface and a CLI with curated presets.

> Working name. Erebus is the Greek primordial of deep darkness — fits
> the Apollo / Dionysus / Orpheus naming pattern and directly answers
> the "everything is too bright, it's daytime" complaint that motivated
> this project. Rename freely.

---

## 1. What this is for

A pipeline that takes:

- One or more **background video sources** (yt-dlp playlist, file, or
  directory): e.g. the Cyberpunk 2077 cyberpsycho-episode playlist
  `PLB7y0B0P3XsrAvMFaYlriVs8VEIrmNw11`.
- One or more **music sources** (yt-dlp playlist, file, or directory):
  e.g. the long-form synthwave/cyberpunk mix video
  `youtube.com/watch?v=_LC-QY2yros` or the alternate playlist
  `PLm90DCMQmtlknzGUbMtRX5JrIeMsb4_6r`.

…and produces a single rendered mp4 with the videos concatenated, the
music laid over them, the original video audio low-passed and ducked
underneath, a preset-defined visual treatment (color grading + optional
edge/glitch/scanline effects), and a music visualizer overlay with a
song-name caption that fades in when each new track starts.

The intended use is PiP background while coding. The visual register
should be dark, kinetic enough to lock attention, and dissociative
enough to mute the daytime-cheerful reality of the source footage.

## 2. Two-track architecture

Both paths target the same engine. The split is a UX concern, not an
implementation concern.

```
                ┌───────────────────────────────┐
                │   erebus.stages (importable)  │
                │   ingest, concat, grade,      │
                │   visualize, mix, caption,    │
                │   encode, lab                 │
                └──────────────┬────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
        ┌─────▼──────┐                  ┌───────▼─────────┐
        │ CLI        │                  │ Agent surface   │
        │ presets    │                  │ (plain Python)  │
        │ erebus     │                  │ MCP-shaped fns  │
        │ render     │                  │ used by Codex / │
        │ lab        │                  │ Claude Code     │
        └────────────┘                  └─────────────────┘
```

Stages are the unit of composition. Each is a plain Python function
with a typed signature, no side effects beyond the output path it
returns. The CLI is a preset orchestrator; no business logic lives in
the CLI module itself. Agents call stages directly. The shape of the
function signature is the shape of the tool.

This is the "two paths" requirement satisfied without forking the
codebase. See `docs/REQUIREMENTS.md` REQ-ARCH-001 through
REQ-ARCH-005 for the formal contract.

## 3. Document map

| File                       | Purpose                                                              | Audience          |
| -------------------------- | -------------------------------------------------------------------- | ----------------- |
| `README.md`                | Public-facing intro, install, quick example, disclaimers             | Visitors, users   |
| `LICENSE`                  | MIT license text                                                     | Visitors          |
| `PROJECT.md` (this file)   | Vision, phasing, architecture; entry point for new contributors      | Humans + agents   |
| `AGENTS.md`                | Cross-vendor agent instructions (Codex, Cursor, Copilot, Gemini)     | AI coding agents  |
| `CLAUDE.md`                | Thin Claude-Code-specific layer; imports AGENTS.md                   | Claude Code       |
| `docs/REQUIREMENTS.md`     | Formal requirements with REQ-IDs                                     | Implementers, QA  |
| `docs/TESTING.md`          | TDD philosophy, anchor discipline, test taxonomy                     | Implementers      |
| `docs/TEST_SPEC.md`        | Concrete TDD anchors keyed to REQ-IDs                                | Implementers, CI  |
| `docs/WORKFLOW.md`         | Branching, commits, reviews, cross-vendor checkpoints, recovery      | Implementers      |
| `docs/REPO_SETUP.md`       | GitHub bootstrap, secrets, branch protection, CI workflow files      | Setup goal        |
| `docs/decisions/`          | ADRs, gap analyses, deviations                                       | Long-term record  |
| `docs/review-prompts/`     | System prompts for `claude -p` review checkpoints                    | Reviewer invocation|
| `NOTES.md`                 | Running journal (one line per agent turn)                            | Agents            |
| `presets/`                 | TOML preset definitions                                              | Users + CLI       |
| `lab/`                     | Stable input clips + outputs (outputs gitignored)                    | Iteration         |

Read order for a fresh contributor (human or agent):

1. `README.md` for orientation
2. `PROJECT.md` (this file) for architecture and phasing
3. `AGENTS.md` for working conventions
4. `docs/REQUIREMENTS.md` for what the code must do
5. `docs/TESTING.md` for how to prove it does
6. `docs/WORKFLOW.md` for how to actually make changes

## 4. Phase plan

Each phase has its own Codex `/goal` cycle with an auditable finish
line. The current goals are **Goal 0 (setup)** and **Goal 1 (Phase 1
development)**, stored in `goals/` after Goal 0 lands.

### Phase 0 — Repo and scaffolding (Goal 0)

Repo on GitHub, CI passing, all docs in place, all guardrails active.
Spans no actual product code beyond the project skeleton. See
`docs/REPO_SETUP.md`.

### Phase 1 — MVP pipeline (Goal 1, current dev target)

All seven stages (ingest, concat, grade, visualize, caption, mix,
encode) implemented at minimum-viable quality. One preset:
`cyberpsycho.toml`. The CLI command `erebus render --preset
cyberpsycho ...` works end-to-end on the supplied playlists. Lab
supports every stage in isolation.

Verification surface, Phase 1:

1. `erebus render --preset cyberpsycho --videos <playlist-url>
   --music <playlist-url> --out out.mp4` completes without errors on
   the supplied cyberpsycho and mix playlists.
2. The output mp4 plays with: correct total duration, audible music
   with low-passed video audio underneath, visible visualizer +
   song-name caption, cyberpsycho grading applied (precise assertions
   in `docs/TEST_SPEC.md` §"End-to-end integration").
3. Every stage is exposed as a typed Python function in
   `erebus/stages/` and callable in isolation (REQ-ARCH-002).
4. `erebus lab apply --stage <name> --params <json>
   --clip <30s-pair>` works for every stage.
5. All Phase-1 TDD anchors green; CI green on Ubuntu and macOS.

### Phase 2 — Preset expansion + tunability

Multiple presets, preset inheritance, `erebus inspect preset` and
`erebus render --tune` overrides. New goal at phase entry.

### Phase 3 — Advanced visuals

projectM-based visualizer with cyberpunk MilkDrop presets; possibly
shader-based grading via Vulkan filters or moderngl. The "deep
cyberspace" preset gets its proper treatment.

### Phase 4 — Song detection (deferred)

Chapter-marker fallback first; AcoustID/Chromaprint for chapter-less
sources; opt-in ACRCloud. Details in §10.

## 5. The cyberpsycho preset (Phase 1 target)

The preset shipped with Phase 1. Values are starting points; tune in
the lab.

```toml
# presets/cyberpsycho.toml

[grade]
brightness   = -0.08
contrast     = 1.25
saturation   = 0.85
gamma_r      = 0.95
gamma_b      = 1.05
mix_rr = 0.95 ; mix_rg = 0.05 ; mix_rb = 0.10
mix_gr = 0.00 ; mix_gg = 0.90 ; mix_gb = 0.05
mix_br = 0.10 ; mix_bg = 0.05 ; mix_bb = 1.00
rgbashift_rh = 2 ; rgbashift_rv = 0
rgbashift_bh = -2 ; rgbashift_bv = 0
vignette       = "PI/5"
noise_strength = 12

[grade.edges]
enabled = true
opacity = 0.20
low     = 0.06
high    = 0.18
tint_r  = 220 ; tint_g = 40 ; tint_b = 180

[audio.video_track]
lowpass_hz    = 1800
highpass_hz   = 80
volume_db     = -14
echo_delay_ms = 70
echo_decay    = 0.35

[audio.music_track]
lowpass_hz   = 0
highpass_hz  = 0
volume_db    = 0
normalize    = true

[visualizer]
type        = "showcqt"
position    = "bottom-center"
width       = 1200 ; height = 180
opacity     = 0.55
basefreq    = 27.5 ; endfreq = 16000
bar_g       = 7 ; sono_g = 2.5
font        = "fonts/Rajdhani-Medium.ttf"
font_size   = 22

[caption]
enabled      = true
position     = "top-left"
margin_px    = 36
font         = "fonts/Rajdhani-SemiBold.ttf"
font_size    = 36
color        = "0xE0E0FFFF"
shadow_color = "0xFF00FF80"
fade_in_ms   = 800
fade_out_ms  = 1200
hold_ms      = 6000
template     = "▮▮ {title}"

[encode]
codec_v      = "libx264"
preset       = "slow"
crf          = 19
codec_a      = "aac"
bitrate_a    = "192k"
container    = "mp4"
target_fps   = 30
target_res   = "1920x1080"
```

### The ffmpeg filter chain for cyberpsycho

The `grade` stage composes this through `erebus.ffmpeg.builder`, each
parameter editable separately, never as a string literal. Building
through the builder is enforced by REQ-SEC-002 (no raw filter-graph
strings reach subprocess) and tested in TEST_SPEC.md anchor
`test_grade_filter_built_via_builder_only`.

```
[0:v]
  scale=1920:1080:force_original_aspect_ratio=decrease,
  pad=1920:1080:(ow-iw)/2:(oh-ih)/2,
  eq=brightness=-0.08:contrast=1.25:saturation=0.85:
     gamma_r=0.95:gamma_b=1.05,
  colorchannelmixer=rr=0.95:rg=0.05:rb=0.10:
     gr=0:gg=0.90:gb=0.05:br=0.10:bg=0.05:bb=1.00,
  rgbashift=rh=2:rv=0:bh=-2:bv=0,
  noise=alls=12:allf=t,
  vignette=PI/5
  [base];
[base] split=2 [base1][base2];
[base2]
  edgedetect=mode=colormix:low=0.06:high=0.18,
  colorchannelmixer=rr=0.86:rg=0:rb=0.86:
     gr=0:gg=0.16:gb=0:br=0.7:bg=0:bb=0.7
  [edges];
[base1][edges] blend=all_mode=screen:all_opacity=0.20 [graded];
```

### Visualizer filter chain

```
[1:a] showcqt=s=1200x180:basefreq=27.5:endfreq=16000:bar_g=7:
        sono_g=2.5:fcount=1:bar_t=0.06:cscheme=1|0|0|0|1|1,
      format=rgba,colorchannelmixer=aa=0.55 [viz];
[graded][viz] overlay=x=(W-w)/2:y=H-h-40 [v_with_viz];
```

### Caption stage

Consumes the manifest emitted by `ingest` (per REQ-INGEST-003), derives
per-track start times, generates a `drawtext enable=...` expression:

```
drawtext=fontfile=fonts/Rajdhani-SemiBold.ttf:
  text='▮▮ Living City — Magnatron':
  fontsize=36:fontcolor=0xE0E0FF:
  shadowcolor=0xFF00FF@0.5:shadowx=0:shadowy=0:
  x=36:y=36:
  enable='between(t,0,6)+between(t,212,218)+...'
```

The `enable` expression is mechanically generated; never hand-crafted.

### Audio mix

```
[0:a] lowpass=f=1800,highpass=f=80,
      aecho=0.7:0.35:70:0.35,volume=-14dB [video_audio];
[1:a] loudnorm=I=-16:LRA=11:TP=-1.5 [music];
[video_audio][music]
  amix=inputs=2:duration=longest:weights=1 1 [aout];
```

## 6. The Tron / deep-cyberspace experiment

The cyberpsycho preset gives you "V's view through a glitched optic"
at edge-opacity 0.20. Deep-cyberspace asks: what if the world
dissolves into structure?

Four candidate techniques, ordered by cost:

1. **Edge-detect dominant.** Same recipe with edges at 0.85 opacity
   and base crushed to near-black via `curves=preset=darker` +
   `eq=brightness=-0.35`. Ships in `deep_cyberspace.toml` in Phase 2.
2. **Posterize + edge layer.** `pp=al` or `lut` to quantize colors
   into 4–8 levels before edge detection. Combined with neon edges,
   reads "wireframe render" rather than "filmed reality."
3. **Hue-keyed cyberspace.** `chromakey`/`hsvkey` to identify sky and
   large surfaces, replace with gradients/particles, keep
   people/objects as edge-outlines. Fiddly and footage-dependent.
4. **Shader-based.** GLSL fragment shader per frame via headless
   `glslViewer`, `ffglitch`, or a moderngl-driven renderer. Phase 3+.

Ship (1) in Phase 2, prototype (2) in the lab, hold (3) and (4) until
needed.

## 7. Audio treatment notes

The "dissociated / underwater" effect on the video's own audio.
Settings that work:

- Low-pass 1500–2200 Hz (default 1800; 1200 for extreme, 2400 for
  clarity). Removes consonants and sibilance, keeps voice body and
  explosion rumble.
- High-pass 60–100 Hz. Removes subsonic rumble that fights the music.
- `aecho` small delay (60–80ms), low decay (0.3–0.4) for "room
  behind glass." For more underwater feel: `afir` with a short
  reverb IR.
- Volume duck to -12 to -16 dB.

Optional lab experiments: `aphaser`, `tremolo` at very low rate,
`asuperequalizer` to scoop midrange.

Music: default `loudnorm` only. Per-track filters opt-in via preset.

## 8. Visualizer choices

### Phase 1: FFmpeg-native

`showcqt` default (constant-Q transform; log frequency axis;
musical). Cyan/magenta `cscheme` is on-aesthetic immediately.

Alternates available in lab:
- `avectorscope` — Lissajous stereo scope. Beautiful for electronic
  music, unreadable as spectrum.
- `showfreqs` — linear frequency bars; less musical, more
  "spectrum analyzer chic."
- `showspectrum` — scrolling spectrogram texture.
- `showvolume` — level meters; composable next to others.

The visualizer stage dispatches by `type` parameter to per-type
sub-modules implementing `build_filter(audio_path, config) -> str`
(REQ-ARCH-004).

### Phase 3: projectM

[projectM](https://github.com/projectM-visualizer/projectm) is the
C++ port of MilkDrop. Headless render to video file given audio +
`.milk` preset. Wrap in `erebus/visualizers/projectm.py` when build
deps are acceptable.

## 9. The lab

The full pipeline takes minutes per render; the lab takes seconds.

Stable inputs: 30-second video and 30-second audio clips in
`lab/clips/`. Don't change unless rebaselining.

Subcommands:

```bash
erebus lab apply --stage grade \
  --params '{"brightness": -0.12, "contrast": 1.30}' \
  --clip lab/clips/cyberpsycho_30s.mp4 \
  --audio lab/clips/synthwave_30s.opus

erebus lab compare \
  lab/outputs/...__abc123.mp4 lab/outputs/...__def456.mp4

erebus lab thumbs lab/outputs/...__abc123.mp4

erebus lab render --preset cyberpsycho --duration 30 \
  --video-source lab/clips/cyberpsycho_30s.mp4 \
  --music-source lab/clips/synthwave_30s.opus
```

Output filenames are deterministic from `(timestamp, stage,
params-hash)`. `lab/outputs/` is gitignored.

## 10. Song detection (Phase 4)

For `youtube.com/watch?v=_LC-QY2yros`:

**Path A: chapter scrape (free).** `yt-dlp --write-info-json
--skip-download <url>` → `jq '.chapters' "<title>.info.json"`. Many
synthwave mix uploaders add chapters.

**Path B: Chromaprint / AcoustID (free, open).** Novelty detection
(librosa: RMS + spectral flux + chroma) for boundaries; `fpcalc` per
segment; AcoustID web API; MusicBrainz for metadata. Sonnleitner et
al. 2016 ISMIR ("Landmark-based audio fingerprinting for DJ-mix
monitoring") is the academic baseline.

**Path C: ACRCloud (commercial).** Reliable on DJ-mix inputs. Few
cents per identification. Behind `audio_fingerprint.provider =
"acrcloud"` config flag.

Implementation order in Phase 4: A → B → C.

## 11. Dependencies (Phase 1)

External binaries: `ffmpeg` ≥ 6, `yt-dlp`, `ffprobe`.

Python (declared with minimum versions in `pyproject.toml`; exact
resolved versions locked in `uv.lock` and committed):
`typer`, `pydantic` v2, `rich`. (`tomllib` from stdlib for TOML
parsing — Python ≥ 3.11 is required so no third-party fallback is
needed.)

Out of scope for Phase 1: any ML dep (`librosa`, `torch`, `numpy`
for audio analysis), projectM, headless browsers, AcoustID.

Fonts: Rajdhani (Google Fonts, OFL).

## 12. References

- Codex goals primer:
  https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex
- AGENTS.md open standard: https://agents.md
- Claude Code headless mode:
  https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless
- yt-dlp: https://github.com/yt-dlp/yt-dlp
- FFmpeg filter reference: https://ffmpeg.org/ffmpeg-filters.html
- AcoustID + Chromaprint: https://acoustid.org/chromaprint
- Sonnleitner, Arzt, Widmer 2016, "Landmark-based audio
  fingerprinting for DJ-mix monitoring," ISMIR
- projectM: https://github.com/projectM-visualizer/projectm
- Beck, K. (2002), *Test-Driven Development: By Example* —
  red-green-refactor baseline behind `docs/TESTING.md`
- Source playlists:
  - Cyberpsycho footage: `PLB7y0B0P3XsrAvMFaYlriVs8VEIrmNw11`
  - Long-form mix: `_LC-QY2yros`
  - Alternate mix playlist: `PLm90DCMQmtlknzGUbMtRX5JrIeMsb4_6r`
