# Liquid Labs On-Prem Deployment

## Prerequisites
- Nvidia and CUDA driver
  - Run `nvidia-smi` to verify the driver installation.
  - May need to disable secure boot in BIOS.
  - Currently, Liquid cannot provide technical support for driver or CUDA installation.
- Docker
  - If the current user has no permission to run Docker commands, run the following commands:
  ```bash
  sudo usermod -aG docker $USER
  sudo systemctl restart docker

  # IMPORTANT: after the restart, log out and log back in
  # verify the permission
  ls -l /var/run/docker.sock
  ```
- [Docker compose plugin](https://docs.docker.com/compose/install/)
  - Run `docker compose version` to verify installation.
- [Nvidia container toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  - Run `nvidia-ctk --version` to verify installation.

## Launch

```bash
# Authenticate to the Docker registry
# Paste the password when prompted
docker login -u <docker-username>

# Launch the stack
./launch.sh

# Wait for 2 min, and run API test
./test-api.sh
```

When running for the first time, the launch script will do the following:
- Create a `.env` file and populate all the environment variables used by the stack.
- Create a Docker volume `postgres_data` for the Postgres database.
- Run the `docker-compose.yaml` file and start the stack.

When running for subsequent times, the launch script will consume the environment variables from the `.env` file and restart the stack.

Two environment variables are constructed from other variables: `DATABASE_URL` and `MODEL_NAME`. Please do not modify them directly in the `.env` file.

## Models

Currently, each on-prem stack can only run one model at a time. We will improve on this soon. The launch script runs the default model specified in `config.yaml`. To switch models, run `./launch.sh --switch-model` and select the desired model to run. The script will then stop the current model and start the newly chosen model.

## Files

| File | Description |
| ---- | ----------- |
| `README.md` | This file |
| `docker-compose.yaml` | Docker compose file to launch the stack |
| `launch.sh` | Script to launch the stack |
| `config.yaml` | Customer-specific stack configuration. |
| `.env` | Environment variables file created by the `launch.sh` script |
| `shutdown.sh` | Script to shut down the stack |
| `connect-db.sh` | Script to connect to the Postgres database |
| `test-api.sh` | Script to test the inference server API |
| `run-vllm.sh` | Script to launch any model from Hugging Face |
| `rm-vllm.sh` | Script to remove a model launched by `run-vllm.sh` |
| `run-checkpoint.sh` | Script to serve fine-tuned Liquid model checkpoints |
| `run-cf-tunnel.sh` | Script to run Cloudflare tunnel |
| `purge.sh` | Script to remove all containers, volumes, and networks |

## Update

To update stack or model to the latest version, pull the latest changes from this repository, and run the launch script with `--upgrade-stack` and / or `--upgrade-model`:

```bash
./shutdown.sh
./launch.sh [--upgrade-stack] [--upgrade-model]
```

To update the stack or modal manually to a specific version, change `STACK_VERSION` and / or `MODEL_IMAGE` in the `.env` file and run:

```bash
./shutdown.sh
./launch.sh
```

## Connect to the Database

1. Install `pgcli` first.
2. Run `connect-db.sh`.

## Shutdown

```bash
./shutdown.sh
```

## Cloudflare tunnel

To expose the web UI through Cloudflare tunnel, the default script given by Cloudflare does not work. Run the following command with `--network` and `--protocol h2mux` options instead.

```bash
# add --protocol h2mux
docker run -d --network liquid_labs_network cloudflare/cloudflared:latest tunnel --no-autoupdate run --protocol h2mux --token <tunnel-token>
```

## Launch Models from Hugging Face

Run the `run-vllm.sh` script to launch models from Hugging Face. The script requires the `--model-name`, `--hf-model-path`, and `--hf-token` parameters. For example, the following command will launch the `llama-7b` model with the Hugging Face model `meta-llama/Llama-2-7b-chat-hf`:

```bash
./run-vllm.sh --model-name llama-7b --hf-model-path "meta-llama/Llama-2-7b-chat-hf" --hf-token <hugging-face-token>
```

When accessing gated repository, please ensure:
- You have got the permission to access the repository.
- The access token has this permission scope: `Read access to contents of all public gated repos you can access`.

The launched vLLM container has no authentication. The container exposes port 9000 by default. Example API calls:

```bash
# show model ID:
curl http://0.0.0.0:9000/v1/models

# run chat completion:
curl http://0.0.0.0:9000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
  "model": "llama-7b",
  "messages": [
    {
      "role": "user",
      "content": "At which temperature does silver melt?"
    }
  ],
  "max_tokens": 128,
  "temperature": 0
}'
```

<details>

<summary>(click to see the full list of parameters for the launch script)</summary>

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `--model-name` | Yes | | Name for the docker container and model ID for API call |
| `--hf-model-path` | Yes | | Hugging Face model path (e.g. `meta-llama/Llama-2-7b-chat-hf`) |
| `--hf-token` | Required for private or gated repository | | Hugging Face API token |
| `--port` | No | `9000` | Port number for the inference server |
| `--gpu` | No | `all` | GPU device to use (e.g. to use the first gpu: `0`, to use the second gpu: `1`) |
| `--gpu-memory-utilization` | No | `0.6` | GPU memory utilization for the inference server. |
| `--max-num-seqs` | No | 600 | Maximum number of sequences per iteration. Decrease this value when running into out-of-memory issue. |
| `--max-model-len` | No | 32768 | Model context length. Decrease this value when running into out-of-memory issue. |

</details>

### Troubleshooting

<details>
<summary>(click to expand)</summary>

**Missing chat template**

When chatting with a model, if you see the following error:

> As of transformers v4.44, default chat template is no longer allowed, so you must provide a chat template if the tokenizer does not define one.

This means the model does not have a default `chat_template` in the `tokenizer_config.json`. It is possible that the model is not trained for chat input. The solution is to run a chat-compatible model instead. For example, `meta-llama/Llama-3.2-3B` has no chat template, but `meta-llama/Llama-3.2-3B-Instruct` does.

The `run-vllm.sh` script does not support passing in a custom chat template. You can modify the script yourself if needed.

**Unknown or invalid runtime name: nvidia**

1. Ensure NVIDIA Container Toolkit is installed:

```bash
sudo apt update
sudo apt install -y nvidia-container-toolkit nvidia-container-runtime
```

2. Configure Docker to use NVIDIA runtime

```bash
sudo nano /etc/docker/daemon.json
```

Ensure the file contains the following:

```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

Then, restart Docker:

```bash
sudo systemctl restart docker
```

</details>

## Serve Fine-Tuned Liquid Model Checkpoints

Install `jq`, and run the `run-checkpoint.sh` script.

For example, the following command will launch the checkpoint files in `~/finetuned-lfm-3b-output` on port `9000`:

```bash
./run-checkpoint.sh --model-checkpoint "~/finetuned-lfm-3b-output"
```

The model name is extracted from the `model_metadata.json` file in the checkpoint directory. The launched vLLM container has no authentication. The container exposes port 9000 by default. Example API calls:

```bash
# show model ID:
curl http://0.0.0.0:9000/v1/models

# run chat completion:
curl http://0.0.0.0:9000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
  "model": "lfm-3b-ft",
  "messages": [
    {
      "role": "user",
      "content": "At which temperature does silver melt?"
    }
  ],
  "max_tokens": 128,
  "temperature": 0
}'
```

<details>

<summary>(click to see the full list of parameters for the launch script)</summary>

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `--model-checkpoint` | Yes | | Local path to the fine-tuned Liquid model checkpoint |
| `--port` | No | `9000` | Port number for the inference server |
| `--gpu` | No | `all` | GPU device to use (e.g. to use the first gpu: `0`, to use the second gpu: `1`) |
| `--gpu-memory-utilization` | No | `0.6` | GPU memory utilization for the inference server. Decrease this value when running into out-of-memory issue. |
| `--max-num-seqs` | No | | Maximum number of sequences per iteration. Decrease this value when running into out-of-memory issue. |

</details>
