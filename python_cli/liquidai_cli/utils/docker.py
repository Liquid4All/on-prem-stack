"""Docker utilities for the Liquid Labs CLI."""

import subprocess
from typing import List, Dict, Any, Optional
import docker
from docker.errors import NotFound
from pathlib import Path
import logging
from docker.models.containers import Container
import time

logger = logging.getLogger(__name__)


class DockerHelper:
    def __init__(self, env_file: Path = Path(".env")):
        self.client = docker.from_env()
        self.env_file = env_file
        env_file.touch()
        self.env_dict = {}

    def run_compose(self, compose_file: Path, action: str = "up") -> None:
        """Run docker-compose command."""
        cmd = ["docker", "compose", "--env-file", str(self.env_file), "-f", str(compose_file)]

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

    def run_container(self, image: str, name: str, **kwargs) -> Container:
        """Run a Docker container."""
        try:
            container = self.client.containers.get(name)
            container.remove(force=True)
        except NotFound:
            pass

        return self.client.containers.run(image, name=name, detach=True, **kwargs)

    def list_containers(self, ancestor: str) -> List[Dict[str, Any]]:
        """List containers by ancestor image."""
        matching_containers = set()
        matching_containers.update(self.client.containers.list(filters={"ancestor": ancestor}))

        # Get all images that match the ancestor image name and check their containers
        image_base_name = ancestor.split(":")[0]
        images = self.client.images.list(name=image_base_name)
        for image in images:
            containers = self.client.containers.list(filters={"ancestor": image.id})
            matching_containers.update(containers)
        result = []
        for c in matching_containers:
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

    def get_env_var(self, key: str) -> str:
        """Get an environment variable from the env_file."""
        if key in self.env_dict:
            return self.env_dict[key]
        with open(self.env_file, "r") as f:
            for line in f:
                if line.startswith(key):
                    return line.split("=")[1].strip()
        return ""

    def set_and_export_env_var(self, key: str, value: str) -> None:
        """Set and export an environment variable into env_file."""
        self.env_dict[key] = value
        with open(self.env_file, "r") as f:
            lines = f.readlines()
        # Check if the key already exists
        for i, line in enumerate(lines):
            if line.startswith(key):
                lines[i] = f"{key}={value}\n"
                break
        else:
            lines.append(f"{key}={value}\n")
        # Write the updated lines back to the file
        with open(self.env_file, "w") as f:
            f.writelines(lines)

    def remove_env_file(self) -> None:
        """Remove the env_file if it exists."""
        try:
            self.env_file.unlink()
        except FileNotFoundError:
            pass

    def wait_for_container_health_check(
        self, container: Container, check_period: int, timeout: Optional[int] = None
    ) -> bool:
        """
        Wait for a container to be healthy. Returns True if healthy, False
        if timeout or the container exit with a non-zero code.

        Args:
        * container: the container to check
        * check_period: the period to wait between checks (in seconds)
        * timeout: the maximum time to wait for the container to be healthy (in seconds)
        """
        counter = 0
        while True:
            inspect_results = self.client.api.inspect_container(container.id)
            health_status = inspect_results.get("State", {}).get("Health", {}).get("Status")
            if health_status == "healthy":
                return True
            elif health_status == "unhealthy":
                return False
            else:
                print(f"Container {container.name} is not healthy yet. Status: {health_status}")
            if timeout and counter >= timeout:
                print(f"Timeout waiting for container {container.name} to be healthy.")
                return False
            time.sleep(check_period)
            counter += check_period
