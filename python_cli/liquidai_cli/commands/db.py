"""Database management commands."""

import typer
import subprocess
from liquidai_cli.utils.config import load_config

app = typer.Typer(help="Database operations")


@app.command()
def connect():
    """Connect to the database using pgcli."""
    try:
        subprocess.run(["pgcli", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        typer.echo("Error: pgcli is not installed. Please install it first:", err=True)
        typer.echo("  pip install pgcli")
        raise typer.Exit(1)

    config = load_config()
    db_config = config["database"]

    cmd = [
        "PGOPTIONS=--search_path={}".format(db_config["schema"]),
        "pgcli",
        "postgresql://{}:{}@0.0.0.0:{}/{}".format(
            db_config["user"], db_config["password"], db_config["port"], db_config["name"]
        ),
    ]

    subprocess.run(" ".join(cmd), shell=True)
