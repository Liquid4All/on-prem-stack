"""Interactive prompt utilities for the Liquid Labs CLI."""

import typer
from typing import Optional


def confirm_action(message: str, default: bool = False, abort: bool = True, force: bool = False) -> bool:
    """Prompt for confirmation unless force is True."""
    if force:
        return True

    try:
        return typer.confirm(message, default=default, abort=abort)
    except typer.Abort:
        typer.echo("\nOperation cancelled.")
        raise typer.Exit(1)


def prompt_value(
    message: str, default: Optional[str] = None, hide_input: bool = False, required: bool = True
) -> Optional[str]:
    """Prompt for a value with optional default and input hiding."""
    try:
        value = typer.prompt(
            message,
            default=default,
            hide_input=hide_input,
            show_default=not hide_input and default is not None,
        )
        if not value and required:
            typer.echo("Error: This value is required", err=True)
            return prompt_value(message, default, hide_input, required)
        return value
    except typer.Abort:
        typer.echo("\nOperation cancelled.")
        raise typer.Exit(1)
