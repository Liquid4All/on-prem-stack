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
