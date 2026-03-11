# macbox

Think WSL, but for macOS. Persistent Linux distros with SSH, port forwarding, and host integration — built on [Apple container](https://github.com/apple/container).

Combines the best of two approaches:
- **Image-first** (à la afbjorklund): bakes static user config (UID/GID, account, sudo, shell, sshd) into a per-user image layer at create time.
- **Runtime injection** (à la applebox/toolbox): injects dynamic config (SSH agent, filesystem mounts, port forwarding, env vars) at container start.

## Quick Start

```bash
# Create a distro
macbox create ubuntu:24.04 mydev

# Enter it
macbox enter mydev

# Or SSH in (works with VS Code Remote SSH)
macbox enter mydev --ssh
ssh -p 2222 $(whoami)@localhost
code --remote ssh-remote+$(whoami)@localhost:2222 /home/$(whoami)
```

## Config File

Define distros as code with `macbox.json`:

```bash
macbox init                              # Generate sample config
macbox create --config macbox.json mydev # Create from config
```

```json
{
  "cpus": 4,
  "homeRW": false,
  "image": "ubuntu:24.04",
  "memory": "4g",
  "mounts": ["~/projects:/home/user/projects:rw"],
  "ports": ["3000:3000", "8080:8080"],
  "provision": ["apt-get update && apt-get install -y git curl nodejs"]
}
```

CLI flags override config file values.

## Commands

```
macbox create <image> <name>     Create a new distro
  --config, -c <path>            Load from macbox.json
  --mount, -m <host:guest[:ro]>  Extra mounts
  --publish, -p <host:guest>     Port forwards
  --provision <cmd>              Run command after creation
  --cpus <n>                     CPU limit
  --memory <size>                Memory limit (e.g. 4g)
  --home-rw                      Mount ~ read-write

macbox enter <name>              Enter a distro
  --ssh                          Connect via SSH

macbox list                      List distros
macbox stop <name>               Stop a distro
macbox remove <name> [--force]   Remove distro and image
macbox init [-o path]            Generate sample config
```

## What Happens Under the Hood

### Image Layer (static, built once)

- User account matching your macOS UID/GID
- sudo with NOPASSWD
- Your preferred shell (zsh/fish/bash)
- OpenSSH server on port 2222 with key-only auth

### Runtime Config (dynamic, per session)

- `~/` mounted into container (read-only by default)
- SSH agent socket forwarded
- Host SSH public key → `authorized_keys`
- LANG, TERM, EDITOR forwarded
- User-specified port forwards and mounts
- CPU and memory limits

### Provisioning (first create only)

Commands run inside the container after creation — install packages, clone repos, configure tools.

## Design

```
┌──────────────────────────────────────────────┐
│              macbox create                    │
│                                               │
│  macbox.json ─┐                               │
│               ▼                               │
│  ┌──────────────┐    ┌─────────────────────┐  │
│  │ Image Layer   │    │ Runtime Config      │  │
│  │ (static)      │    │ (dynamic)           │  │
│  │               │    │                     │  │
│  │ • UID/GID     │    │ • ~/ mount          │  │
│  │ • username    │    │ • SSH agent fwd     │  │
│  │ • sudo        │    │ • port forwards     │  │
│  │ • shell       │    │ • env vars          │  │
│  │ • sshd        │    │ • authorized_keys   │  │
│  │               │    │ • CPU/memory limits  │  │
│  └──────┬───────┘    └────────┬────────────┘  │
│         │                     │               │
│         ▼                     ▼               │
│  container build        container run         │
│         │                     │               │
│         └─────────┬───────────┘               │
│                   ▼                           │
│           persistent distro                   │
│                   │                           │
│                   ▼                           │
│           provisioning scripts                │
└──────────────────────────────────────────────┘
```

## Requirements

- macOS 15+
- [Apple container](https://github.com/apple/container) CLI
- Swift 6.2+
