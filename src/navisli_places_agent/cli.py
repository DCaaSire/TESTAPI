from __future__ import annotations

import json
import os
from pathlib import Path

import typer
from dotenv import load_dotenv
from supabase import create_client

from .importer import import_csv
from .repository import PlacesRepository

app = typer.Typer(no_args_is_help=True)


@app.command("import-csv")
def import_csv_command(
    file: Path = typer.Argument(..., exists=True, dir_okay=False, readable=True),
    source_name: str = typer.Option(..., help="Registered or descriptive source name"),
    dry_run: bool = typer.Option(True, "--dry-run/--write"),
) -> None:
    load_dotenv()
    repository = None
    if not dry_run:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        if not url or not key:
            raise typer.BadParameter(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required with --write"
            )
        repository = PlacesRepository(create_client(url, key))

    summary = import_csv(file, repository, source_name=source_name, dry_run=dry_run)
    typer.echo(json.dumps(summary.__dict__, indent=2))


if __name__ == "__main__":
    app()
