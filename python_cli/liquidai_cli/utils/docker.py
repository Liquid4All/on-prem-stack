"""Docker utilities for the Liquid Labs CLI."""
import subprocess
from typing import Optional, List, Dict, Any, Union, Sequence
import docker
from docker.errors import NotFound, APIError
from pathlib import Path
import typer

class DockerHelper:
    def __init__(self):
        self.client = docker.from_env()
    
    def run_compose(self, compose_file: Path, env_file: Path, action: str = "up") -> None:
        """Run docker-compose command."""
        cmd = ["docker", "compose", "--env-file", str(env_file)]
        
        if action == "up":
            cmd.extend(["up", "-d", "--wait"])
        elif action == "down":
            cmd.extend(["down"])
        
        subprocess.run(cmd, check=True)
    
    def ensure_volume(self, name: str) -> None:
        """Ensure a Docker volume exists."""
        try:
            self.client.volumes.get(name)
        except NotFound:
            self.client.volumes.create(name)
    
    def remove_volume(self, name: str) -> None:
        """Remove a Docker volume if it exists."""
        try:
            volume = self.client.volumes.get(name)
            volume.remove()
        except NotFound:
            pass
    
    def remove_network(self, name: str) -> None:
        """Remove a Docker network if it exists."""
        try:
            network = self.client.networks.get(name)
            network.remove()
        except NotFound:
            pass
            
    def run_container(self, image: str, name: str, **kwargs) -> None:
        """Run a Docker container."""
        try:
            container = self.client.containers.get(name)
            container.remove(force=True)
        except NotFound:
            pass
            
        self.client.containers.run(
            image,
            name=name,
            detach=True,
            **kwargs
        )
    
    def list_containers(self, ancestor: str) -> List[Dict[str, Any]]:
        """List containers by ancestor image."""
        containers = self.client.containers.list(
            filters={"ancestor": ancestor}
        )
        result = []
        for c in containers:
            ports = {}
            try:
                network_settings = c.attrs.get("NetworkSettings", {})
                if isinstance(network_settings, dict):
                    ports = network_settings.get("Ports", {})
            except (KeyError, TypeError, AttributeError):
                pass
            result.append({"name": c.name, "ports": ports})
        return result
    
    def stop_container(self, name: str) -> None:
        """Stop and remove a container."""
        try:
            container = self.client.containers.get(name)
            container.stop()
            container.remove()
        except NotFound:
            pass
