"""Configuration management commands."""

import typer
from pathlib import Path
from typing import Dict, Any
from liquidai_cli.utils.config import (
    save_config,
    DEFAULT_CONFIG,
    generate_random_string,
)

app = typer.Typer(help="Manage configuration")


def parse_env_file(env_file: Path) -> Dict[str, Any]:
    """Parse environment variables from .env file."""
    env_vars = {}
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                try:
                    key, value = line.split("=", 1)
                    env_vars[key.strip()] = value.strip()
                except ValueError:
                    typer.echo(f"Warning: Skipping invalid line in {env_file}: {line}", err=True)
    return env_vars


@app.command()
def import_env(
    env_file: Path = typer.Option(
        Path(".env"),
        "--env-file",
        "-e",
        help="Path to .env file to import",
        exists=True,
    ),
    config_file: Path = typer.Option(
        Path("liquid.yaml"),
        "--config-file",
        "-c",
        help="Path to YAML config file",
    ),
    force: bool = typer.Option(
        False,
        "--force",
        "-f",
        help="Overwrite existing config file",
    ),
):
    """Import configuration from .env file into YAML format.

    This command reads an existing .env file and converts it to the new YAML configuration format.
    It preserves all environment variables and their relationships while maintaining backward compatibility.
    """
    if config_file.exists() and not force:
        typer.echo(f"Config file {config_file} already exists. Use --force to overwrite.", err=True)
        raise typer.Exit(1)

    # Read and parse .env file
    env_vars = parse_env_file(env_file)

    # Map to YAML structure
    config = DEFAULT_CONFIG.copy()

    # Stack configuration
    config["stack"].update(
        {
            "vllm_version": env_vars.get("VLLM_VERSION", config["stack"]["vllm_version"]),
            "python_api_version": env_vars.get("PYTHON_API_VERSION", config["stack"]["python_api_version"]),
            "web_version": env_vars.get("WEB_VERSION", config["stack"]["web_version"]),
            "db_migration_version": env_vars.get("DB_MIGRATION_VERSION", config["stack"]["db_migration_version"]),
            "model_image": env_vars.get("MODEL_IMAGE", config["stack"]["model_image"]),
            "jwt_secret": env_vars.get("JWT_SECRET", generate_random_string(64)),
            "api_secret": env_vars.get("API_SECRET", config["stack"]["api_secret"]),
            "auth_secret": env_vars.get("AUTH_SECRET", generate_random_string(64)),
            # MODEL_NAME is auto-generated from model_image in save_config
        }
    )

    # Database configuration
    config["database"].update(
        {
            "name": env_vars.get("POSTGRES_DB", config["database"]["name"]),
            "user": env_vars.get("POSTGRES_USER", config["database"]["user"]),
            "password": env_vars.get("POSTGRES_PASSWORD", config["database"]["password"]),
            "port": int(env_vars.get("POSTGRES_PORT", str(config["database"]["port"]))),
            "schema": env_vars.get("POSTGRES_SCHEMA", config["database"]["schema"]),
        }
    )

    # Save the configuration
    save_config(config, config_file)
    typer.echo(f"Successfully imported configuration from {env_file} to {config_file}")
    typer.echo("\nNote: MODEL_NAME and DATABASE_URL are auto-generated and were not imported.")
