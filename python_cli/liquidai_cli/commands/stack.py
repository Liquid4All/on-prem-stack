"""Stack management commands."""

import typer
from pathlib import Path
from liquidai_cli.utils.docker import DockerHelper
from liquidai_cli.utils.config import load_config, extract_model_name
from liquidai_cli.utils.prompt import confirm_action
from liquidai_cli.commands.model import run_model_image
from importlib import resources as impresources

app = typer.Typer(help="Manage the on-prem stack")
docker_helper = DockerHelper(Path(".env"))


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
        "VLLM_VERSION": config["stack"]["vllm_version"],
        "PYTHON_API_VERSION": config["stack"]["python_api_version"],
        "WEB_VERSION": config["stack"]["web_version"],
        "DB_MIGRATION_VERSION": config["stack"]["db_migration_version"],
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

    # Export environment variables for docker-compose
    for key, value in env_vars.items():
        typer.echo(f"Setting {key}")
        docker_helper.set_and_export_env_var(key, value)

    # Ensure postgres volume exists
    docker_helper.ensure_volume("postgres_data")

    # Launch stack
    docker_helper.run_compose(get_docker_compose_file())
    # Run default model image
    run_model_image(model_name, config["stack"]["model_image"])

    typer.echo("The on-prem stack is now running.")


@app.command()
def shutdown():
    """Shutdown the on-prem stack."""
    # Shutdown running models
    containers = docker_helper.list_containers("liquidai/liquid-labs-vllm")
    for container in containers:
        container_name = container["name"]
        docker_helper.stop_container(container_name)
        typer.echo(f"Stopped and removed model container: {container_name}")

    docker_helper.run_compose(get_docker_compose_file(), action="down")
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
    docker_helper.run_compose(get_docker_compose_file(), action="down")

    # Remove volume and network
    docker_helper.remove_volume("postgres_data")
    docker_helper.remove_network("liquid_labs_network")

    # Remove .env file
    docker_helper.remove_env_file()

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
    available_model_json = response.json()
    typer.echo(available_model_json)
    if not available_model_json.get("data"):
        typer.echo("Error: No models found in the response", err=True)
        raise typer.Exit(1)

    # Test chat completion
    typer.echo("\nTesting model call...")
    for model_info in available_model_json["data"]:
        model_name = model_info["id"]
        if model_info["status"] == "running":
            typer.echo(f"Testing model: {model_name}")
            data = {
                "model": model_name,
                "messages": [{"role": "user", "content": "At which temperature does silver melt?"}],
                "max_tokens": 128,
                "temperature": 0,
            }
            response = requests.post("http://0.0.0.0:8000/v1/chat/completions", headers=headers, json=data)
            typer.echo(response.json())


def get_docker_compose_file() -> Path:
    import liquidai_cli.docker_compose_files as docker_compose_files

    path = impresources.files(docker_compose_files).joinpath("docker-compose.yaml")
    if not path.exists():
        raise FileNotFoundError(f"Docker compose file not found: {path}")
    return path
