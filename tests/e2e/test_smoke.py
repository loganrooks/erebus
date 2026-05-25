"""At least one e2e test so pytest collects something at Goal-0.

The test-e2e workflow runs `pytest tests/e2e -m phase1 --run-e2e`
on PRs touching erebus/, presets/, or tests/e2e/. Without a
collected test, pytest exits 5 ("no tests ran") and the job
reports failure on the first stage PR. WORKFLOW.md §3 says
test-e2e MUST be green when it runs.

Real e2e anchors (`test_phase1_integration`) land in their
feature PRs during Phase 1; this placeholder may be deleted once
that anchor is in place.
"""

import pytest


@pytest.mark.phase1
def test_e2e_smoke() -> None:
    assert True
