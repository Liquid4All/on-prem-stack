"""Infrastructure management commands."""

import typer
from typing import Optional
from liquidai_cli.utils.docker import DockerHelper

app = typer.Typer(help="Infrastructure operations")
docker_helper = DockerHelper()


@app.command()
def create(
    token: Optional[str] = typer.Option(None, "--token", help="Cloudflare tunnel token"),
):
    """Create a Cloudflare tunnel."""
    if not token:
        token = typer.prompt("Enter your Cloudflare tunnel token")

    docker_helper.run_container(
        image="cloudflare/cloudflared:latest",
        name="liquid-labs-tunnel",
        network="liquid_labs_network",
        command=["tunnel", "--no-autoupdate", "run", "--protocol", "h2mux", "--token", token],
        detach=True,
    )

    typer.echo("Cloudflare tunnel has been created successfully")
