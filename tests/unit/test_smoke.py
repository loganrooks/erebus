"""At least one unit test so pytest collects something at Goal-0."""

import pytest


@pytest.mark.phase1
def test_smoke() -> None:
    assert True
