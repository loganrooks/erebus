# erebus

A Python toolkit for assembling cyberpunk-styled background video
mixes. Ingests YouTube playlists via `yt-dlp`, applies an
ffmpeg-based processing pipeline (color grading, visualizer overlay,
song-name caption, audio mixing), and renders a single mp4 for
picture-in-picture background while you work.

Designed to be driven both from a CLI with curated presets and from
AI coding agents (Codex CLI, Claude Code, Cursor) via a typed Python
tool surface. The two surfaces share one engine — see
[`PROJECT.md`](PROJECT.md) for the architecture.

## Status

Phase 1 (MVP pipeline) is the current development target. See
[`PROJECT.md`](PROJECT.md) §4 for the phase plan and
[`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) for the formal
contract.

## Install

Requires Python ≥ 3.11, `ffmpeg` ≥ 6, and `yt-dlp` on PATH.

```bash
git clone https://github.com/loganrooks/erebus
cd erebus
uv sync --extra dev
uv run pre-commit install
```

## Quick example (post-Phase-1)

```bash
# Render a mix from the cyberpsycho playlist and a synthwave mix video
erebus render \
  --preset cyberpsycho \
  --videos "https://youtube.com/playlist?list=PLB7y0B0P3XsrAvMFaYlriVs8VEIrmNw11" \
  --music  "https://youtube.com/watch?v=_LC-QY2yros" \
  --out cyberpsycho-mix.mp4 \
  --max-duration 3600

# Iterate on grading params against a 30-second reference clip
erebus lab apply \
  --stage grade \
  --params '{"brightness": -0.12, "contrast": 1.30}' \
  --clip  lab/clips/cyberpsycho_30s.mp4 \
  --audio lab/clips/synthwave_30s.opus
```

## Use only with content you have the right to download

`erebus` automates `yt-dlp`. Downloading videos from YouTube and
other platforms may violate their Terms of Service and, depending on
the content and jurisdiction, copyright law. This project is
distributed for personal use with content you own or have explicit
permission to download (your own uploads, Creative Commons sources,
public-domain footage, content licensed for offline use).

You are responsible for ensuring your use complies with applicable
law and platform terms. The maintainers do not host or distribute
downloaded content and do not condone use that infringes others'
rights.

## Contributing

If you're contributing as a human, start with [`PROJECT.md`](PROJECT.md).
If you're an AI coding agent, start with [`AGENTS.md`](AGENTS.md)
(or [`CLAUDE.md`](CLAUDE.md) if you're Claude Code). The full
contributor doc set is mapped in `PROJECT.md` §3.

## License

MIT. See [`LICENSE`](LICENSE).

## References

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg filters](https://ffmpeg.org/ffmpeg-filters.html)
- [AGENTS.md open standard](https://agents.md)
- [Claude Code headless mode](https://docs.anthropic.com/en/docs/claude-code/sdk/sdk-headless)
- Beck, K. (2002), *Test-Driven Development: By Example* — the
  testing discipline this project follows
