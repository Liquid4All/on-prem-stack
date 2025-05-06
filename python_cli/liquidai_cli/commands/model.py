"""Model management commands."""

import typer
from pathlib import Path
from typing import Optional, Dict, List, cast
from liquidai_cli.utils.docker import DockerHelper
from liquidai_cli.utils.device import get_device_requests_from_gpus
from typing_extensions import Annotated
from docker.models.containers import Container


app = typer.Typer(help="Manage ML models")
docker_helper = DockerHelper()

NANOSECONDS_IN_SECOND = 1_000_000_000
HEALTHCHECK_INTERVAL = 30 * NANOSECONDS_IN_SECOND


@app.command(name="run-model-image")
def run_model_image(
    name: str = typer.Option(..., "--name", help="Name for the model"),
    model_image: str = typer.Option(..., "--image", help="Model image name"),
    port: Annotated[Optional[int], typer.Option("--port", help="Port to expose locally")] = None,
    gpu: Annotated[str, typer.Option("--gpu", help="Specific GPU index to use")] = "all",
    gpu_memory_utilization: Annotated[
        float,
        typer.Option("--gpu-memory-utilization", help="Fraction of GPU memory to use"),
    ] = 0.6,
    max_num_seqs: Annotated[
        int,
        typer.Option("--max-num-seqs", help="Maximum number of sequences to generate in parallel"),
    ] = 750,
    max_model_len: Annotated[int, typer.Option("--max-model-len", help="Maximum length of the model")] = 32768,
    wait_for_health: Annotated[bool, typer.Option("--wait", help="Wait for health check to pass")] = True,
):
    """
    Launch a model stored in a Docker image. Default Liquid Foundation Models (LFM) are delivered in this approach.
    """
    # Create a volume to cache the model data
    typer.echo(f"Creating volume for model data: {name}")
    model_volume_name = f"model_data_{name}"
    docker_helper.ensure_volume(model_volume_name)
    model_volume_loader_container_name = f"liquid-labs-model-volume-{name}"
    typer.echo(f"Loading model data from image: {model_image}")
    model_volume_loader_container = docker_helper.run_container(
        image=model_image,
        name=model_volume_loader_container_name,
        volumes={model_volume_name: {"bind": "/model", "mode": "rw"}},
        network="liquid_labs_network",
    )
    result = model_volume_loader_container.wait()
    if result["StatusCode"] != 0:
        typer.echo(f"Error loading model data: {result['StatusCode']}", err=True)
        raise typer.Exit(1)
    model_volume_loader_container.remove()

    typer.echo(f"Launching model container: {name}")
    vllm_version = docker_helper.get_env_var("VLLM_VERSION")
    ports_mapping = {"9000/tcp": port} if port else None

    container = docker_helper.run_container(
        image=f"liquidai/liquid-labs-vllm:{vllm_version}",
        name=name,
        device_requests=get_device_requests_from_gpus(gpu),
        volumes={model_volume_name: {"bind": "/model", "mode": "ro"}},
        network="liquid_labs_network",
        ports=ports_mapping,
        command=[
            "--model",
            "/model",
            "--served-model-name",
            name,
            "--port",
            str(9000),
            "--max-logprobs",
            "0",
            "--dtype",
            "bfloat16",
            "--device",
            "cuda",
            "--enable-chunked-prefill",
            "False",
            "--tensor-parallel-size",
            "1",
            "--gpu-memory-utilization",
            str(gpu_memory_utilization),
            "--max-model-len",
            str(max_model_len),
            "--max-num-seqs",
            str(max_num_seqs),
            "--max-seq-len-to-capture",
            str(max_model_len),
        ],
        healthcheck={
            "test": "curl --fail http://localhost:9000/health || exit 1",
            "interval": HEALTHCHECK_INTERVAL,
            "start_period": HEALTHCHECK_INTERVAL,
        },
    )
    if not wait_for_health:
        typer.echo(f"Model '{name}' started successfully")
        typer.echo("Please wait 1-2 minutes for the model to load before making API calls")
    else:
        wait_for_model_health_or_print_logs_command(name, container)
    if port:
        typer.echo(f"Model is accessible at http://localhost:{port}/v1/")


@app.command(name="run-hf")
def run_huggingface(
    name: str = typer.Option(..., "--name", help="Name for the model container"),
    path: str = typer.Option(..., "--path", help="Hugging Face model path"),
    port: Annotated[Optional[int], typer.Option("--port", help="Port to expose locally")] = None,
    gpu: Annotated[str, typer.Option("--gpu", help="Specific GPU index to use")] = "all",
    gpu_memory_utilization: Annotated[
        float,
        typer.Option("--gpu-memory-utilization", help="Fraction of GPU memory to use"),
    ] = 0.6,
    max_num_seqs: Annotated[
        int,
        typer.Option("--max-num-seqs", help="Maximum number of sequences to generate in parallel"),
    ] = 600,
    max_model_len: Annotated[int, typer.Option("--max-model-len", help="Maximum length of the model")] = 32768,
    hf_token: Annotated[
        Optional[str],
        typer.Option("--hf-token", help="Hugging Face access token", envvar="HUGGING_FACE_TOKEN"),
    ] = None,
    wait_for_health: Annotated[bool, typer.Option("--wait", help="Wait for health check to pass")] = True,
):
    """Launch a model from Hugging Face."""
    if not hf_token:
        typer.echo(
            "Error: Hugging Face token not provided. Set HUGGING_FACE_TOKEN environment variable or use --hf-token",
            err=True,
        )
        raise typer.Exit(1)

    vllm_version = docker_helper.get_env_var("VLLM_VERSION")
    ports_mapping = {"9000/tcp": port} if port else None
    container = docker_helper.run_container(
        image=f"liquidai/liquid-labs-vllm:{vllm_version}",
        name=name,
        environment={"HUGGING_FACE_HUB_TOKEN": hf_token},
        device_requests=get_device_requests_from_gpus(gpu),
        network="liquid_labs_network",
        ports=ports_mapping,
        command=[
            "--host",
            "0.0.0.0",
            "--port",
            "9000",
            "--model",
            path,
            "--served-model-name",
            name,
            "--tensor-parallel-size",
            "1",
            "--max-logprobs",
            "0",
            "--gpu-memory-utilization",
            str(gpu_memory_utilization),
            "--max-num-seqs",
            str(max_num_seqs),
            "--max-model-len",
            str(max_model_len),
            "--max-seq-len-to-capture",
            str(max_model_len),
        ],
        healthcheck={
            "test": "curl --fail http://localhost:9000/health || exit 1",
            "interval": HEALTHCHECK_INTERVAL,
            "start_period": HEALTHCHECK_INTERVAL,
        },
    )
    if not wait_for_health:
        typer.echo(f"Model '{name}' started successfully")
        typer.echo("Please wait 1-2 minutes for the model to load before making API calls")
    else:
        wait_for_model_health_or_print_logs_command(name, container)
    if port:
        typer.echo(f"Model is accessible at http://localhost:{port}/v1/")


@app.command(name="run-checkpoint")
def run_checkpoint(
    path: str = typer.Option(..., "--path", help="Path to model checkpoint directory"),
    port: Annotated[Optional[int], typer.Option("--port", help="Port to expose locally")] = None,
    gpu: Annotated[str, typer.Option("--gpu", help="Specific GPU index to use")] = "all",
    gpu_memory_utilization: Annotated[
        float,
        typer.Option("--gpu-memory-utilization", help="Fraction of GPU memory to use"),
    ] = 0.6,
    max_num_seqs: Annotated[int, typer.Option("--max-num-seqs", help="Maximum number of sequences to cache")] = 600,
    wait_for_health: Annotated[bool, typer.Option("--wait", help="Wait for health check to pass")] = True,
):
    """Launch a model from local checkpoint."""
    import json

    checkpoint_path = Path(path).resolve()
    if not checkpoint_path.is_dir():
        typer.echo(f"Error: Model checkpoint directory does not exist: {path}", err=True)
        raise typer.Exit(1)

    metadata_file = checkpoint_path / "model_metadata.json"
    if not metadata_file.is_file():
        typer.echo(
            "Error: model_metadata.json does not exist in the model checkpoint directory",
            err=True,
        )
        raise typer.Exit(1)

    with open(metadata_file) as f:
        metadata = json.load(f)
        model_name = metadata.get("model_name")

    if not model_name:
        typer.echo("Error: model_name is not defined in model_metadata.json", err=True)
        raise typer.Exit(1)

    vllm_version = docker_helper.get_env_var("VLLM_VERSION")
    image_name = f"liquidai/liquid-labs-vllm:{vllm_version}"
    ports_mapping = {"9000/tcp": port} if port else None

    container = docker_helper.run_container(
        image=image_name,
        name=model_name,
        device_requests=get_device_requests_from_gpus(gpu),
        volumes={str(checkpoint_path): {"bind": "/model", "mode": "ro"}},
        network="liquid_labs_network",
        ports=ports_mapping,
        command=[
            "--host",
            "0.0.0.0",
            "--port",
            "9000",
            "--model",
            "/model",
            "--served-model-name",
            model_name,
            "--tensor-parallel-size",
            "1",
            "--max-logprobs",
            "0",
            "--dtype",
            "bfloat16",
            "--enable-chunked-prefill",
            "false",
            "--gpu-memory-utilization",
            str(gpu_memory_utilization),
            "--max-num-seqs",
            str(max_num_seqs),
            "--max-model-len",
            "32768",
            "--max-seq-len-to-capture",
            "32768",
        ],
        healthcheck={
            "test": "curl --fail http://localhost:9000/health || exit 1",
            "interval": HEALTHCHECK_INTERVAL,
            "start_period": HEALTHCHECK_INTERVAL,
        },
    )

    if not wait_for_health:
        typer.echo(f"Model '{model_name}' started successfully")
        typer.echo("Please wait 1-2 minutes for the model to load before making API calls")
    else:
        wait_for_model_health_or_print_logs_command(model_name, container)
    if port:
        typer.echo(f"Model is accessible at http://localhost:{port}/v1/")


@app.command()
def list():
    """List running models."""
    containers = docker_helper.list_containers("liquidai/liquid-labs-vllm")

    if not containers:
        typer.echo("No running vLLM containers found.")
        return

    typer.echo("Running vLLM containers:")
    typer.echo("----------------------")

    for i, container in enumerate(containers, 1):
        ports = container.get("ports", {})
        port = "unknown"
        if isinstance(ports, dict):
            port_mappings = cast(List[Dict[str, str]], ports.get("9000/tcp", []))
            if port_mappings:
                mapping = port_mappings[0]
                if isinstance(mapping, dict):
                    port = mapping.get("HostPort", "unknown")
        typer.echo(f"{i}) {container['name']} (Port: {port})")


@app.command()
def stop(
    name: Optional[str] = typer.Argument(None, help="Name of the model to stop"),
):
    """Stop a running model."""
    if name:
        docker_helper.stop_container(name)
        typer.echo(f"Stopped and removed container: {name}")
        return

    # Interactive mode if no name provided
    containers = docker_helper.list_containers("liquidai/liquid-labs-vllm")
    if not containers:
        typer.echo("No running vLLM containers found.")
        return

    typer.echo("Select a container to stop:")
    for i, container in enumerate(containers, 1):
        ports = container.get("ports", {})
        port = "unknown"
        if isinstance(ports, dict):
            port_mappings = cast(List[Dict[str, str]], ports.get("9000/tcp", []))
            if port_mappings:
                mapping = port_mappings[0]
                if isinstance(mapping, dict):
                    port = mapping.get("HostPort", "unknown")
        typer.echo(f"{i}) {container['name']} (Port: {port})")

    try:
        choice = typer.prompt("Enter container number", type=int)
        if 1 <= choice <= len(containers):
            container = containers[choice - 1]
            docker_helper.stop_container(container["name"])
            typer.echo(f"Stopped and removed container: {container['name']}")
        else:
            typer.echo("Invalid selection", err=True)
    except typer.Abort:
        typer.echo("\nOperation cancelled.")


def wait_for_model_health_or_print_logs_command(name: str, container: Container):
    typer.echo(f"Model '{name}' started successfully")
    typer.echo(f"Waiting for model '{name}' to be healthy. This may take a 1-2 minutes...")
    if docker_helper.wait_for_container_health_check(container, 15):
        typer.echo(f"Model '{name}' has started serving requests.")
    else:
        typer.echo(f"Error: Model '{name}' failed to start serving requests", err=True)
        typer.echo(f"Use `docker logs {container.short_id}` to obtain container loggings.")
