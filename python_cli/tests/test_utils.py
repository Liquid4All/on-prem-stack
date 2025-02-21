"""Tests for core utility functions."""

from liquidai_cli.utils.config import (
    generate_random_string,
    extract_model_name,
    load_config,
    DEFAULT_CONFIG,
)


def test_generate_random_string():
    """Test random string generation."""
    # Test length
    assert len(generate_random_string(10)) == 10
    assert len(generate_random_string(64)) == 64

    # Test uniqueness
    str1 = generate_random_string(32)
    str2 = generate_random_string(32)
    assert str1 != str2

    # Test character set
    str_test = generate_random_string(100)
    assert all(c.isalnum() for c in str_test)


def test_extract_model_name():
    """Test model name extraction from image tag."""
    test_cases = [
        ("liquidai/lfm-7b-e:0.0.1", "7b-e"),
        ("liquidai/test-model:latest", "model"),
        ("invalid/format", None),
        ("liquidai/lfm-13b:latest", "13b"),
    ]

    for image_tag, expected in test_cases:
        assert extract_model_name(image_tag) == expected


def test_load_config(tmp_path):
    """Test configuration loading and defaults."""
    config_file = tmp_path / "liquid.yaml"

    # Test default config creation
    config = load_config(config_file)
    assert config["stack"]["version"] == DEFAULT_CONFIG["stack"]["version"]
    assert config["database"]["name"] == DEFAULT_CONFIG["database"]["name"]

    # Test secrets are generated
    assert len(config["stack"]["jwt_secret"]) == 64
    assert len(config["stack"]["auth_secret"]) == 64

    # Test config is persisted
    config2 = load_config(config_file)
    assert config["stack"]["jwt_secret"] == config2["stack"]["jwt_secret"]
    assert config["stack"]["auth_secret"] == config2["stack"]["auth_secret"]

    # Test model name generation
    config["stack"]["model_image"] = "liquidai/lfm-7b-e:0.0.1"
    config3 = load_config(config_file)
    assert config3["stack"]["model_name"] == "lfm-7b-e"
