# Liquid Labs CLI

Command line interface for managing Liquid Labs on-prem stack.

## Installation
```bash
pip install liquidai-cli
```

A `docker-compose.yaml` file is also shipped together with the package. Any changes to this file may cause some unexpected behaviors.

## Configuration

The CLI uses a YAML configuration file (`liquid.yaml`) in your working directory. A default configuration will be created on first use, but you can customize it:

```yaml
stack:
  version: "c3d7dbacd1"
  model_image: "liquidai/lfm-7b-e:0.0.1"
  api_secret: "local_api_token"
  # Other values will be auto-generated
database:
  name: "liquid_labs"
  user: "local_user"
  password: "local_password"
  port: 5432
  schema: "labs"
```

## Local Development

### Setting Up the Development Environment

To set up a local development environment for the Liquid Labs CLI:

```bash
git clone https://github.com/Liquid4All/on-prem-stack.git
cd on-prem-stack/python_cli

# Install the package in development mode with test and development dependencies
pip install -e ".[test,dev]"
```

### Running the CLI Locally

There are several ways to run the CLI locally:

- Using Python module (recommended for development):
```bash
python -m liquidai_cli.cli [command] [args]
```

- Using `uv` without installing the package:
```bash
uv run --directory . -m liquidai_cli.cli [command] [args]
```

- Install the package in development mode with test dependencies
```bash
pip install -e ".[test,dev]"
liquid-cli [command] [args]
```

### Running Tests

To run tests for the Liquid Labs CLI:

```bash
# Run all tests with verbose output
pytest -v

# Run tests with coverage reporting
pytest --cov=liquidai_cli

# Run tests with coverage reporting and generate XML report (used in CI)
pytest --cov=liquidai_cli --cov-report=xml
```

### Code Quality Checks

Before submitting changes, make sure to run the following code quality checks:

```bash
# Check code formatting with black
black . --check

# Run linting with flake8
flake8 .

# You can also format your code automatically with black
black .
```

## Usage

### Stack Management

```bash
# Launch stack
liquidai stack launch

# Launch with upgrades
liquidai stack launch --upgrade-stack --upgrade-model

# Shutdown stack
liquidai stack shutdown

# Test API endpoints
liquidai stack test

# Purge stack (removes all components)
liquidai stack purge

# Purge without confirmation
liquidai stack purge --force
```

### Model Operations

```bash
# Run a model in docker container
liquidai model run-model-image \
  --name lfm-3b-e \
  --image "liquidai/lfm-3b-e:0.0.6"

# Run a HuggingFace model and expose on port 9000
liquidai model run-hf \
  --name llama-7b \
  --path meta-llama/Llama-2-7b-chat-hf \
  --port 9000 \
  --gpu-memory-utilization 0.6 \
  --max-num-seqs 600 \
  --max-model-len 32768

# Run a local checkpoint and expose on port 9001 to avoid conflicts
liquidai model run-checkpoint \
  --path /path/to/checkpoint \
  --port 9001 \
  --gpu-memory-utilization 0.6 \
  --max-num-seqs 600

# List running models
liquidai model list

# Stop a specific model
liquidai model stop llama-7b

# Stop a model interactively
liquidai model stop
```

### Database Operations

```bash
# Connect to database using pgcli
liquidai db connect
```

### Infrastructure

```bash
# Create Cloudflare tunnel with token
liquidai tunnel create --token YOUR_TOKEN

# Create tunnel interactively
liquidai tunnel create
```

### Configuration Management

```bash
# Import configuration from .env file
liquidai config import

# Import from specific .env file
liquidai config import --env-file /path/to/.env

# Import to specific config file
liquidai config import --config-file /path/to/liquid.yaml

# Force overwrite existing config
liquidai config import --force
```

## Command Reference
Call `liquidai [command] --help` to get the detailed usage reference.
