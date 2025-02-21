"""Main CLI entry point for Liquid Labs CLI."""

import typer
from liquidai_cli.commands import stack, model, db, infra, config

# Create main CLI app
app = typer.Typer(
    name="liquidai",
    help="Liquid Labs CLI tool for managing on-prem stack",
    no_args_is_help=True,
)

# Register command groups
app.add_typer(stack.app, name="stack", help="Manage the on-prem stack")
app.add_typer(model.app, name="model", help="Manage ML models")
app.add_typer(db.app, name="db", help="Database operations")
app.add_typer(infra.app, name="tunnel", help="Infrastructure operations")
app.add_typer(config.app, name="config", help="Manage configuration")


def main():
    """Entry point for the CLI."""
    app()


if __name__ == "__main__":
    main()
