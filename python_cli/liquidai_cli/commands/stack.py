"""Stack management commands."""

import typer
from pathlib import Path
from liquidai_cli.utils.docker import DockerHelper
from liquidai_cli.utils.config import load_config, extract_model_name
from liquidai_cli.utils.prompt import confirm_action

app = typer.Typer(help="Manage the on-prem stack")
docker_helper = DockerHelper()


@app.command()
def launch(
    upgrade_stack: bool = typer.Option(False, "--upgrade-stack", help="Upgrade stack version"),
    upgrade_model: bool = typer.Option(False, "--upgrade-model", help="Upgrade model version"),
):
    """Launch the on-prem stack."""
    config = load_config()

    if upgrade_stack:
        config["stack"]["version"] = "c3d7dbacd1"
    if upgrade_model:
        config["stack"]["model_image"] = "liquidai/lfm-7b-e:0.0.1"

    # Set model name
    model_image = config["stack"]["model_image"]
    model_name = f"lfm-{extract_model_name(model_image)}"
    config["stack"]["model_name"] = model_name

    # Generate environment file for docker-compose
    env_vars = {
        "JWT_SECRET": config["stack"]["jwt_secret"],
        "API_SECRET": config["stack"]["api_secret"],
        "AUTH_SECRET": config["stack"]["auth_secret"],
        "STACK_VERSION": config["stack"]["version"],
        "MODEL_IMAGE": config["stack"]["model_image"],
        "MODEL_NAME": config["stack"]["model_name"],
        "POSTGRES_DB": config["database"]["name"],
        "POSTGRES_USER": config["database"]["user"],
        "POSTGRES_PASSWORD": config["database"]["password"],
        "POSTGRES_PORT": str(config["database"]["port"]),
        "POSTGRES_SCHEMA": config["database"]["schema"],
        "DATABASE_URL": (
            f"postgresql://{config['database']['user']}:{config['database']['password']}"
            f"@liquid-labs-postgres:{config['database']['port']}/{config['database']['name']}"
        ),
    }

    # Write environment variables to .env for docker-compose
    with open(".env", "w") as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")

    # Ensure postgres volume exists
    docker_helper.ensure_volume("postgres_data")

    # Launch stack
    docker_helper.run_compose(Path("docker-compose.yaml"), Path(".env"))

    typer.echo("The on-prem stack is now running.")
    typer.echo(f"\nModel '{model_name}' is accessible at http://localhost:8000")
    typer.echo("Please wait 1-2 minutes for the model to load before making API calls")


@app.command()
def shutdown():
    """Shutdown the on-prem stack."""
    docker_helper.run_compose(Path("docker-compose.yaml"), Path(".env"), action="down")
    typer.echo("Stack has been shut down.")


@app.command()
def purge(
    force: bool = typer.Option(False, "--force", "-f", help="Skip confirmation prompt"),
):
    """Remove all Liquid Labs components."""
    message = (
        "This will remove all Liquid Labs components:\n"
        "  - Stop and remove all containers\n"
        "  - Delete postgres_data volume\n"
        "  - Remove liquid_labs_network\n"
        "  - Delete .env file\n"
        "\nAre you sure?"
    )

    if not confirm_action(message, default=False, force=force):
        return

    # Shutdown containers
    docker_helper.run_compose(Path("docker-compose.yaml"), Path(".env"), action="down")

    # Remove volume and network
    docker_helper.remove_volume("postgres_data")
    docker_helper.remove_network("liquid_labs_network")

    # Remove .env file
    try:
        Path(".env").unlink()
    except FileNotFoundError:
        pass

    typer.echo("Cleanup complete. All Liquid Labs components have been removed.")


@app.command()
def test():
    """Test the API endpoints."""
    import requests
    from liquidai_cli.utils.config import load_config

    config = load_config()
    api_secret = config["stack"]["api_secret"]
    model_name = config["stack"]["model_name"]

    if not all([api_secret, model_name]):
        typer.echo("Error: API_SECRET or MODEL_NAME not found in configuration", err=True)
        raise typer.Exit(1)

    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_secret}"}

    # Test models endpoint
    typer.echo("Testing API call to get available models...")
    response = requests.get("http://0.0.0.0:8000/v1/models", headers=headers)
    typer.echo(response.json())

    # Test chat completion
    typer.echo("\nTesting model call...")
    data = {
        "model": model_name,
        "messages": [{"role": "user", "content": "At which temperature does silver melt?"}],
        "max_tokens": 128,
        "temperature": 0,
    }
    response = requests.post("http://0.0.0.0:8000/v1/chat/completions", headers=headers, json=data)
    typer.echo(response.json())
