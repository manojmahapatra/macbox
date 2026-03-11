# macbox

Persistent Linux dev environments on macOS, built on [Apple container](https://github.com/apple/container).

Combines the best of two approaches:
- **Image-first** : bakes static user config (UID/GID, account, sudo, shell) into a per-user image layer at create time — clean diffs, reproducible environments.
- **Runtime injection** : injects dynamic config (SSH agent, host filesystem, env vars) at container start — no image rebuild needed when sessions change.

## Usage

```bash
# Create a distro from any container image
macbox create ubuntu:24.04 mydev

# Enter it (starts if stopped)
macbox enter mydev

# List distros
macbox list

# Stop / remove
macbox stop mydev
macbox remove mydev
```

## What happens under the hood

### `macbox create ubuntu:24.04 mydev`

1. Generates a Dockerfile that layers your macOS user onto the base image:
   - Creates user matching your UID/GID
   - Installs sudo, sets NOPASSWD
   - Installs your preferred shell (zsh/fish/bash)
2. Builds the image via `container build`
3. Runs the container with runtime mounts:
   - `~/` mounted read-only (use `--home-rw` for read-write)
   - SSH agent socket forwarded
   - LANG, TERM, EDITOR forwarded

### `macbox enter mydev`

Starts the container if stopped, then `exec`s into it with a login shell.

## Options

```
macbox create <image> <name> [--mount path:path] [--home-rw]
macbox enter <name>
macbox list
macbox stop <name>
macbox remove <name> [--force]
```

## Requirements

- macOS 15+
- [Apple container](https://github.com/apple/container) CLI installed
- Swift 6.2+

## Design

```
┌─────────────────────────────────────────────┐
│              macbox create                   │
│                                              │
│  ┌──────────────┐    ┌────────────────────┐  │
│  │ Image Layer   │    │ Runtime Config     │  │
│  │ (static)      │    │ (dynamic)          │  │
│  │               │    │                    │  │
│  │ • UID/GID     │    │ • ~/  mount        │  │
│  │ • username    │    │ • SSH agent fwd    │  │
│  │ • sudo        │    │ • LANG, TERM, etc  │  │
│  │ • shell       │    │ • extra mounts     │  │
│  └──────┬───────┘    └────────┬───────────┘  │
│         │                     │              │
│         ▼                     ▼              │
│  container build        container run        │
│         │                     │              │
│         └─────────┬───────────┘              │
│                   ▼                          │
│           persistent distro                  │
└─────────────────────────────────────────────┘
```
