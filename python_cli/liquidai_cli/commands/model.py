"""Model management commands."""
import typer
import os
from typing import Optional, Dict, Any, List, cast, Type, Union, Sequence
from pathlib import Path
from liquidai_cli.utils.docker import DockerHelper
from liquidai_cli.utils.config import load_config

app = typer.Typer(help="Manage ML models")
docker_helper = DockerHelper()

@app.command(name="run-hf")
def run_huggingface(
    name: str = typer.Option(..., "--name", help="Name for the model container"),
    path: str = typer.Option(..., "--path", help="Hugging Face model path"),
    port: int = typer.Option(9000, "--port", help="Port to expose locally"),
    gpu: str = typer.Option("all", "--gpu", help="Specific GPU index to use"),
    gpu_memory_utilization: float = typer.Option(0.6, "--gpu-memory-utilization", help="Fraction of GPU memory to use"),
    max_num_seqs: int = typer.Option(600, "--max-num-seqs", help="Maximum number of sequences to generate in parallel"),
    max_model_len: int = typer.Option(32768, "--max-model-len", help="Maximum length of the model"),
    hf_token: Optional[str] = typer.Option(None, "--hf-token", help="Hugging Face access token", envvar="HUGGING_FACE_TOKEN"),
):
    """Launch a model from Hugging Face."""
    if not hf_token:
        typer.echo("Error: Hugging Face token not provided. Set HUGGING_FACE_TOKEN environment variable or use --hf-token", err=True)
        raise typer.Exit(1)
        
    docker_helper.run_container(
        image="vllm/vllm-openai:latest",
        name=name,
        environment={"HUGGING_FACE_HUB_TOKEN": hf_token},
        ports={8000: port},
        device_requests=[{"Driver": "nvidia", "Count": -1, "Capabilities": [["gpu"]]}],
        command=[
            "--host", "0.0.0.0",
            "--port", "8000",
            "--model", path,
            "--served-model-name", name,
            "--tensor-parallel-size", "1",
            "--max-logprobs", "0",
            "--gpu-memory-utilization", str(gpu_memory_utilization),
            "--max-num-seqs", str(max_num_seqs),
            "--max-model-len", str(max_model_len),
            "--max-seq-len-to-capture", str(max_model_len)
        ],
        health_cmd="curl --fail http://localhost:8000/health || exit 1",
        health_interval=30
    )
    
    typer.echo(f"Model '{name}' started successfully")
    typer.echo(f"The vLLM API will be accessible at http://localhost:{port}")
    typer.echo("Please wait 1-2 minutes for the model to load before making API calls")

@app.command(name="run-checkpoint")
def run_checkpoint(
    path: str = typer.Option(..., "--path", help="Path to model checkpoint directory"),
    port: int = typer.Option(9000, "--port", help="Port to expose locally"),
    gpu: str = typer.Option("all", "--gpu", help="Specific GPU index to use"),
    gpu_memory_utilization: float = typer.Option(0.60, "--gpu-memory-utilization", help="Fraction of GPU memory to use"),
    max_num_seqs: int = typer.Option(600, "--max-num-seqs", help="Maximum number of sequences to cache"),
):
    """Launch a model from local checkpoint."""
    import json
    
    checkpoint_path = Path(path).resolve()
    if not checkpoint_path.is_dir():
        typer.echo(f"Error: Model checkpoint directory does not exist: {path}", err=True)
        raise typer.Exit(1)
        
    metadata_file = checkpoint_path / "model_metadata.json"
    if not metadata_file.is_file():
        typer.echo("Error: model_metadata.json does not exist in the model checkpoint directory", err=True)
        raise typer.Exit(1)
        
    with open(metadata_file) as f:
        metadata = json.load(f)
        model_name = metadata.get("model_name")
        
    if not model_name:
        typer.echo("Error: model_name is not defined in model_metadata.json", err=True)
        raise typer.Exit(1)
        
    config = load_config()
    stack_version = config["stack"]["version"]
    image_name = f"liquidai/liquid-labs-vllm:{stack_version}"
    
    docker_helper.run_container(
        image=image_name,
        name=model_name,
        ports={8000: port},
        device_requests=[{"Driver": "nvidia", "Count": -1, "Capabilities": [["gpu"]]}],
        volumes={str(checkpoint_path): {"bind": "/model", "mode": "ro"}},
        command=[
            "--host", "0.0.0.0",
            "--port", "8000",
            "--model", "/model",
            "--served-model-name", model_name,
            "--tensor-parallel-size", "1",
            "--max-logprobs", "0",
            "--dtype", "bfloat16",
            "--enable-chunked-prefill", "false",
            "--gpu-memory-utilization", str(gpu_memory_utilization),
            "--max-num-seqs", str(max_num_seqs),
            "--max-model-len", "32768",
            "--max-seq-len-to-capture", "32768"
        ],
        health_cmd="curl --fail http://localhost:8000/health || exit 1",
        health_interval=30
    )
    
    typer.echo(f"Model '{model_name}' started successfully")
    typer.echo(f"The vLLM API will be accessible at http://localhost:{port}")
    typer.echo("Please wait 1-2 minutes for the model to load before making API calls")

@app.command()
def list():
    """List running models."""
    containers = docker_helper.list_containers("vllm/vllm-openai")
    
    if not containers:
        typer.echo("No running vLLM containers found.")
        return
        
    typer.echo("Running vLLM containers:")
    typer.echo("----------------------")
    
    for i, container in enumerate(containers, 1):
        ports = container.get("ports", {})
        port = "unknown"
        if isinstance(ports, dict):
            port_mappings = cast(List[Dict[str, str]], ports.get("8000/tcp", []))
            if port_mappings and isinstance(port_mappings, list):
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
    containers = docker_helper.list_containers("vllm/vllm-openai")
    if not containers:
        typer.echo("No running vLLM containers found.")
        return
        
    typer.echo("Select a container to stop:")
    for i, container in enumerate(containers, 1):
        ports = container.get("ports", {})
        port = "unknown"
        if isinstance(ports, dict):
            port_mappings = cast(List[Dict[str, str]], ports.get("8000/tcp", []))
            if port_mappings and isinstance(port_mappings, list):
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
