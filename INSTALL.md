# Installation

The `liquidai-cli` tool can be installed in one command and includes all dependencies needed to manage your Liquid Labs on-prem deployment.

## Quick Install (Recommended)

```bash
go install github.com/Liquid4All/on-prem-stack/cmd/liquidai-cli@latest
```

This command will:
- Download and install the CLI tool
- Include all required dependencies
- Make the `liquidai-cli` command available system-wide

## Building from Source

Alternatively, you can build from source:

```bash
git clone https://github.com/Liquid4All/on-prem-stack.git
cd on-prem-stack
make install
```

## Prerequisites

The CLI tool requires:
- Go 1.22 or later
- Docker and Docker Compose plugin
- Nvidia container toolkit (for GPU support)

For detailed prerequisites, see the main [README.md](README.md#prerequisites).

## Configuration

The CLI uses a YAML configuration file (`liquidai.yaml`) in your project directory to store settings. Here's an example configuration:

```yaml
version: 1
security:
  jwt_secret: "generated-random-string"
  api_secret: "local_api_token"
  auth_secret: "generated-random-string"
stack:
  version: "c3d7dbacd1"
  model:
    image: "liquidai/lfm-7b-e:0.0.1"
    name: "7b-e"  # Auto-extracted from image
database:
  name: "liquid_labs"
  user: "local_user"
  password: "local_password"
  port: 5432
  schema: "labs"
  url: "postgresql://local_user:local_password@liquid-labs-postgres:5432/liquid_labs"
```

### Configuration Migration

If you have an existing `.env` file, the CLI will automatically:
1. Convert it to the new YAML format
2. Create a backup of your `.env` file as `.env.bak`
3. Use the new configuration going forward

You don't need to take any manual steps - the migration happens automatically when you run any CLI command.

## Verifying Installation

After installation, verify the CLI is working:

```bash
liquidai-cli --help
```

This should display the available commands and their usage.

## Available Commands

- `launch`: Start the Liquid Labs stack
  - `--upgrade-stack`: Update stack version
  - `--upgrade-model`: Update model version
- `down`: Stop the running stack
- `purge`: Remove all components (requires confirmation)
