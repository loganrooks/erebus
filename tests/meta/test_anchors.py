"""Docs-consistency: REQ <-> anchor coverage check."""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
REQ_FILE = REPO_ROOT / "docs" / "REQUIREMENTS.md"
SPEC_FILE = REPO_ROOT / "docs" / "TEST_SPEC.md"

REQ_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[", re.MULTILINE)
MUST_PATTERN = re.compile(r"^### (REQ-[A-Z]+-\d{3})\s*\[MUST", re.MULTILINE)
ANCHOR_REQ_REF = re.compile(r"### test_\w+\s*—\s*((?:REQ-[A-Z]+-\d{3}[,\s]*)+)")


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


@pytest.mark.anchor("test_every_must_req_has_anchor_citation")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_must_req_has_anchor_citation() -> None:
    """Every MUST requirement must be cited by at least one anchor."""
    req_text = _read(REQ_FILE)
    spec_text = _read(SPEC_FILE)
    musts = set(MUST_PATTERN.findall(req_text))
    cited: set[str] = set()
    for match in ANCHOR_REQ_REF.finditer(spec_text):
        cited.update(re.findall(r"REQ-[A-Z]+-\d{3}", match.group(1)))
    missing = musts - cited
    assert not missing, f"MUST REQs without anchor: {sorted(missing)}"


@pytest.mark.anchor("test_every_anchor_cites_valid_req")
@pytest.mark.meta
@pytest.mark.phase1
def test_every_anchor_cites_valid_req() -> None:
    """Every anchor must cite at least one REQ-ID that exists."""
    req_text = _read(REQ_FILE)
    spec_text = _read(SPEC_FILE)
    valid_reqs = set(REQ_PATTERN.findall(req_text))
    bad: list[str] = []
    for match in ANCHOR_REQ_REF.finditer(spec_text):
        cited = re.findall(r"REQ-[A-Z]+-\d{3}", match.group(1))
        if not cited:
            bad.append(f"empty citation near: {match.group(0)[:60]}")
            continue
        for req in cited:
            if req not in valid_reqs:
                bad.append(f"unknown REQ cited: {req}")
    assert not bad, "\n".join(bad)
