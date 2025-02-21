"""Tests for Docker helper functions."""

import pytest
from unittest.mock import patch, MagicMock
from docker.errors import NotFound
from liquidai_cli.utils.docker import DockerHelper


@pytest.fixture
def mock_docker_client():
    """Mock Docker client for testing."""
    with patch("docker.from_env") as mock:
        client = MagicMock()
        mock.return_value = client
        yield client


def test_ensure_volume(mock_docker_client):
    """Test Docker volume creation."""
    helper = DockerHelper()

    # Test volume exists
    volume = MagicMock()
    mock_docker_client.volumes.get.return_value = volume
    helper.ensure_volume("test_volume")
    mock_docker_client.volumes.get.assert_called_once_with("test_volume")
    mock_docker_client.volumes.create.assert_not_called()

    # Test volume doesn't exist
    mock_docker_client.volumes.get.side_effect = NotFound("not found")
    helper.ensure_volume("new_volume")
    mock_docker_client.volumes.create.assert_called_once_with("new_volume")


def test_remove_volume(mock_docker_client):
    """Test Docker volume removal."""
    helper = DockerHelper()

    # Test remove existing volume
    volume = MagicMock()
    mock_docker_client.volumes.get.return_value = volume
    helper.remove_volume("test_volume")
    volume.remove.assert_called_once()

    # Test remove non-existent volume
    mock_docker_client.volumes.get.side_effect = NotFound("not found")
    helper.remove_volume("missing_volume")  # Should not raise


def test_list_containers(mock_docker_client):
    """Test container listing."""
    helper = DockerHelper()

    # Mock container with network settings
    container = MagicMock()
    container.name = "test-container"
    container.attrs = {"NetworkSettings": {"Ports": {"8000/tcp": [{"HostPort": "9000"}]}}}
    mock_docker_client.containers.list.return_value = [container]

    containers = helper.list_containers("test-image")
    assert len(containers) == 1
    assert containers[0]["name"] == "test-container"
    assert containers[0]["ports"]["8000/tcp"][0]["HostPort"] == "9000"
