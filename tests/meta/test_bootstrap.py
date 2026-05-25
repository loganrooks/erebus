"""Smoke test that erebus is importable at bootstrap."""

import pytest


@pytest.mark.meta
@pytest.mark.phase1
def test_erebus_importable() -> None:
    import erebus  # noqa: F401
