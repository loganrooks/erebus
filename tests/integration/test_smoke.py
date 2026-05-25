"""At least one integration test so pytest collects something at Goal-0.

The real integration anchors land in Phase 1's stage-by-stage PR
cycle (per docs/TEST_SPEC.md "Integration anchors"). This file may
be deleted once the first real integration test lands; the
test-integration CI job needs at least one collected test to pass.
"""

import pytest


@pytest.mark.phase1
def test_integration_smoke() -> None:
    assert True
