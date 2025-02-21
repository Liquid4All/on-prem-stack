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

## Verifying Installation

After installation, verify the CLI is working:

```bash
liquidai-cli --help
```

This should display the available commands and their usage.
