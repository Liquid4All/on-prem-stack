"""
Utils on managing devices parameters.
"""

from docker.types import DeviceRequest
from typing import List


def get_device_requests_from_gpus(gpus: str) -> List[DeviceRequest]:
    """
    Get device requests for GPUs.
    Args:
        gpus (str): requested gpus in a comma-separated string, or "all".
    Returns:
        List[DeviceRequest]: List of device requests for Docker.
    """
    if not gpus:
        return []

    if gpus == "all":
        return [{"Driver": "nvidia", "Count": -1, "Capabilities": [["gpu"]]}]
    else:
        gpu_indices = gpus.split(",")
        return [{"Driver": "nvidia", "DeviceIDs": gpu_indices, "Capabilities": [["gpu"]]}]
