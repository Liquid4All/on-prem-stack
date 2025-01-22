# Liquid Labs On-Prem Deployment

## Files

| File | Description |
| ---- | ----------- |
| `README.md` | This file |
| `docker-compose.yaml` | Docker compose file to launch the stack |
| `launch.sh` | Script to launch the stack |
| `.env` | Environment variables file created by the `launch.sh` script |
| `shutdown.sh` | Script to shut down the stack |
| `connect-db.sh` | Script to connect to the Postgres database |
| `test-api.sh` | Script to test the inference server API |
| `models.yaml` | Available models to run |
| `switch-model.sh` | Script to switch between available models |

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

Currently, each on-prem stack can only run one model at a time. The launch script runs `lfm-3b-jp` by default. To switch models, run `.switch-model.sh` and select the desired model to run. The script will then stop the current model and start the newly chosen model.

## Update

To update the stack, change `STACK_VERSION` and `MODEL_IMAGE` in the `.env` file and run the launch script again.

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

Run the `run-vllm.sh` script with the following parameters:

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `--model-name` | Yes | | Name for the docker container and model ID for API call |
| `--hf-model-path` | Yes | | Hugging Face model path (e.g. `meta-llama/Llama-2-7b-chat-hf`) |
| `--hf-token` | Required for private or gated repository | | Hugging Face API token |
| `--port` | No | `9000` | Port number for the inference server |
| `--gpu` | No | `all` | GPU device to use (e.g. to use the first gpu: `0`, to use the second gpu: `1`) |

For example, the following command will launch the `llama-7b` model with the Hugging Face model `meta-llama/Llama-2-7b-chat-hf` on port `9000`:

When accessing gated repository, please ensure:
- You have got the permission to access the repository.
- The access token has this permission scope: `Read access to contents of all public gated repos you can access`.

```bash
./run-vllm.sh --model-name llama-7b --hf-model-path "meta-llama/Llama-2-7b-chat-hf" --hf-token <hugging-face-token>
```

The launched vLLM container has no authentication. Example API calls:

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

### Troubleshooting

<details>
<summary>(click to expand)</summary>

**Missing chat template**

When chatting with a model, if you see the following error:

> As of transformers v4.44, default chat template is no longer allowed, so you must provide a chat template if the tokenizer does not define one.

This means the model does not have a default `chat_template` in the `tokenizer_config.json`. It is possible that the model is not trained for chat input. The solution is to run a chat-compatible model instead. For example, `meta-llama/Llama-3.2-3B` has no chat template, but `meta-llama/Llama-3.2-3B-Instruct` does.

The `run-vllm.sh` script does not support passing in a custom chat template. You can modify the script yourself if needed.

</details>

## Serve Fine-Tuned Liquid Model Checkpoints

Run the `run-checkpoint.sh` script with the following parameters:

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `--model-name` | Yes | | Name for the docker container and model ID for API call |
| `--model-path` | Yes | | Local path to the fine-tuned Liquid model checkpoint |
| `--port` | No | `9000` | Port number for the inference server |
| `--gpu` | No | `all` | GPU device to use (e.g. to use the first gpu: `0`, to use the second gpu: `1`) |
| `--gpu-memory-utilization` | No | `0.6` | GPU memory utilization for the inference server. Decrease this value when running into out-of-memory issue. |
| `--max-num-seqs` | No | | Maximum number of sequences per iteration. Decrease this value when running into out-of-memory issue. |

For example, the following command will launch the checkpoint files in `~/finetuned-lfm-3b-output` as `lfm-3b-ft` on port `9000`:

```bash
./run-vllm.sh --model-name lfm-3b-ft --model-path "~/finetuned-lfm-3b-output"
```

The launched vLLM container has no authentication. Example API calls:

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
