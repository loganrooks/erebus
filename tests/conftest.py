"""Pytest configuration for the erebus test suite.

Markers are declared in pyproject.toml [tool.pytest.ini_options];
shared fixtures and hooks go here as they are introduced.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pytest


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--run-e2e",
        action="store_true",
        default=False,
        help="Run end-to-end tests (slow; gated by default).",
    )
