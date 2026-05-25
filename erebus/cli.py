"""CLI entrypoint for `erebus`. Phase 1 fills in subcommands; this is a stub.

The `app` symbol below is referenced by [project.scripts] in pyproject.toml.
"""

from __future__ import annotations

import typer

app: typer.Typer = typer.Typer(
    name="erebus",
    help="Cyberpunk video-mix toolkit (Phase-1 stub — not yet functional).",
    no_args_is_help=True,
)
