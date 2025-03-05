# Liquid Labs CLI

Command line interface for managing Liquid Labs on-prem stack.

## Installation

```bash
pip install liquidai-cli
```

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
# Run a HuggingFace model
liquidai model run-hf \
  --name llama-7b \
  --path meta-llama/Llama-2-7b-chat-hf \
  --port 9000 \
  --gpu-memory-utilization 0.6 \
  --max-num-seqs 600 \
  --max-model-len 32768

# Run a local checkpoint
liquidai model run-checkpoint \
  --path /path/to/checkpoint \
  --port 9000 \
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

### Stack Commands

- `launch [--upgrade-stack] [--upgrade-model]`: Launch the stack
  - `--upgrade-stack`: Upgrade stack version
  - `--upgrade-model`: Upgrade model version
- `shutdown`: Shutdown the stack
- `test`: Test API endpoints
- `purge [--force]`: Remove all components
  - `--force`: Skip confirmation prompt

### Model Commands

- `run-hf`: Run a HuggingFace model
  - `--name`: Name for the model container
  - `--path`: HuggingFace model path
  - `--port`: Port to expose (default: 9000)
  - `--gpu`: GPU index to use (default: "all")
  - `--gpu-memory-utilization`: GPU memory fraction (default: 0.6)
  - `--max-num-seqs`: Max parallel sequences (default: 600)
  - `--max-model-len`: Max model length (default: 32768)
  - `--hf-token`: HuggingFace token (or use HUGGING_FACE_TOKEN env var)

- `run-checkpoint`: Run a local checkpoint
  - `--path`: Path to checkpoint directory
  - `--port`: Port to expose (default: 9000)
  - `--gpu`: GPU index to use (default: "all")
  - `--gpu-memory-utilization`: GPU memory fraction (default: 0.6)
  - `--max-num-seqs`: Max parallel sequences (default: 600)

- `list`: List running models
- `stop [NAME]`: Stop a model (interactive if NAME not provided)

### Database Commands

- `connect`: Connect to database using pgcli

### Infrastructure Commands

- `tunnel create [--token TOKEN]`: Create Cloudflare tunnel
  - `--token`: Cloudflare tunnel token

### Configuration Commands

- `config import [--env-file PATH] [--config-file PATH] [--force]`: Import .env configuration
  - `--env-file`: Path to .env file (default: .env)
  - `--config-file`: Path to YAML config file (default: liquid.yaml)
  - `--force`: Force overwrite existing config
