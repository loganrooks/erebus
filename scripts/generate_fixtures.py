"""Generate synthetic test fixtures under tests/fixtures/ (per REQ-SEC-006).

Phase 1 implements the actual generators (color bars + sweep tone for video_3s.mp4,
known-frequency tones for audio_3s.opus, two-track manifest_minimal.json).
At Goal 0 this is a placeholder; the meta-anchor
`test_fixtures_reproducible_from_generator` passes vacuously against the empty
tests/fixtures/ directory.
"""
