"""Configuration utilities for the Liquid Labs CLI."""
from pathlib import Path
from typing import Dict, Optional, Any
import os
import secrets
import string
import re
from ruamel.yaml import YAML
yaml = YAML()
import typer

DEFAULT_CONFIG = {
    "stack": {
        "version": "c3d7dbacd1",
        "model_image": "liquidai/lfm-7b-e:0.0.1",
        "jwt_secret": None,  # Generated on first use
        "api_secret": "local_api_token",
        "auth_secret": None,  # Generated on first use
        "model_name": None,  # Generated from model_image
    },
    "database": {
        "name": "liquid_labs",
        "user": "local_user",
        "password": "local_password",
        "port": 5432,
        "schema": "labs",
    }
}

def generate_random_string(length: int) -> str:
    """Generate a random string of specified length."""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def extract_model_name(image_tag: str) -> Optional[str]:
    """Extract model name from image tag."""
    pattern = r"liquidai/[^-]+-([^:]+)"
    match = re.search(pattern, image_tag)
    return match.group(1) if match else None

def load_config(config_file: Path = Path("liquid.yaml")) -> Dict[str, Any]:
    """Load configuration from YAML file."""
    if not config_file.exists():
        return create_default_config(config_file)
    
    with open(config_file) as f:
        config = yaml.safe_load(f)
    
    # Generate secrets if they don't exist
    if not config["stack"]["jwt_secret"]:
        config["stack"]["jwt_secret"] = generate_random_string(64)
    if not config["stack"]["auth_secret"]:
        config["stack"]["auth_secret"] = generate_random_string(64)
    
    save_config(config, config_file)
    return config

def create_default_config(config_file: Path) -> Dict[str, Any]:
    """Create default configuration file."""
    config = DEFAULT_CONFIG.copy()
    config["stack"]["jwt_secret"] = generate_random_string(64)
    config["stack"]["auth_secret"] = generate_random_string(64)
    
    save_config(config, config_file)
    return config

def save_config(config: Dict[str, Any], config_file: Path) -> None:
    """Save configuration to YAML file."""
    with open(config_file, 'w') as f:
        yaml.safe_dump(config, f, default_flow_style=False)

def get_config_value(
    config: Dict[str, Any],
    key_path: str,
    prompt: Optional[str] = None,
    default: Optional[str] = None,
    required: bool = False
) -> str:
    """Get configuration value, prompting user if not found and required."""
    keys = key_path.split('.')
    value = config
    
    try:
        for key in keys:
            value = value[key]
        if value is None and required:
            if prompt:
                return typer.prompt(prompt)
            return default if default else ""
        return str(value) if value is not None else (default if default else "")
    except (KeyError, TypeError):
        if required and prompt:
            return typer.prompt(prompt)
        return default if default else ""
