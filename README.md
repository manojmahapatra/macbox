# macbox

Persistent Linux distros on macOS with SSH, automatic localhost port forwarding, and host integration, built on [Apple container](https://github.com/apple/container).

`macbox` builds a per-user Linux image for your macOS account, starts it as a reusable distro, and adds the developer workflow pieces you usually want on macOS: SSH access, host mounts, SSH agent forwarding, and automatic localhost port forwarding.

## Highlights

- Create persistent named distros from standard OCI images such as Ubuntu, Alpine, and other common Linux bases.
- Enter with an interactive shell or SSH using a managed per-distro key and generated SSH alias.
- Forward your home directory, env vars, and SSH agent into the distro.
- Auto-forward listening TCP app ports to `localhost` while the distro is running.
- Define distros as code with `macbox.json`.

## Quick Start

```bash
# Create a distro
macbox create ubuntu:24.04 mydev

# Enter it
macbox enter mydev

# See auto-forwarded app ports
macbox ports mydev

# Or SSH in
macbox enter mydev --ssh
# macbox prints the assigned localhost SSH port and manages a distro-specific SSH key
ssh -i ~/Library/Application\ Support/macbox/keys/mydev/id_ed25519 -p <assigned-port> $(whoami)@localhost
# or use the generated SSH alias
ssh -F ~/Library/Application\ Support/macbox/ssh/config macbox-mydev
code --remote ssh-remote+$(whoami)@localhost:<assigned-port> /home/$(whoami)
```

## Declarative Config

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
macbox create <image> <name>      Create a new distro
  --config, -c <path>             Load from macbox.json
  --mount, -m <host:guest[:ro]>   Extra mounts
  --publish, -p <host:guest>      Port forwards
  --provision <cmd>               Run command after creation
  --cpus <n>                      CPU limit
  --memory <size>                 Memory limit (e.g. 4g)
  --home-rw                       Mount ~ read-write
  --home-ro                       Force ~ to stay read-only

macbox enter <name>               Enter a distro
  --ssh                           Connect via SSH

macbox list                       List distros and assigned SSH ports
macbox ports <name>               Show auto-forwarded app ports
macbox stop <name>                Stop a distro
macbox remove <name> [--force]    Remove distro and image
macbox init [-o path]             Generate sample config
```

## Support Matrix

The table below shows what `macbox` supports today and what we plan to add next.
The roadmap is informed by tools like Distrobox, but shaped for the macOS and Apple `container` model.

| Capability | `macbox` now | Planned next |
| --- | --- | --- |
| Create persistent named distros from OCI images | Yes | Broaden the tested image matrix |
| Enter distros with interactive shell or SSH | Yes | Add non-interactive `enter -- command ...` |
| Managed per-distro SSH key and generated SSH alias | Yes | Add optional `~/.ssh/config` install helper |
| Home/project mounts and runtime env forwarding | Yes | Add mount presets and per-distro home isolation |
| SSH agent forwarding | Yes | Add explicit opt-out and per-distro policy |
| Manual port publishing | Yes | Add UDP and stricter host-port reservation controls |
| Automatic localhost app-port forwarding | Yes, for listening TCP ports | Add UDP, labels, and richer inspection |
| Declarative single-distro config (`macbox.json`) | Yes | Add validation and schema docs |
| Multi-distro manifest / fleet apply | No | Add `macbox apply` / `macbox up` |
| Export commands or apps from distro to host | No | Add `macbox export` for binaries, wrappers, and launchers |
| Run host commands from inside distro | No | Add `macbox host-exec` |
| Ephemeral throwaway distros | No | Add `macbox ephemeral` |
| Bulk upgrade / rebuild all distros | No | Add `macbox upgrade` / `macbox rebuild` |
| Initful / service-oriented distros | Partial | Add service mode and stronger init handling |
| Desktop app export and GUI integration | No | Investigate macOS-friendly app launchers and file associations |
| Stronger isolation modes (custom home, unshare/network modes) | No | Add isolated homes and stricter sharing controls |

## What Happens Under the Hood

### Image Layer (static, built once)

- User account matching your macOS UID/GID
- sudo with NOPASSWD
- Your preferred shell (zsh/fish/bash)
- OpenSSH server on port 2222 with key-only auth

### Runtime Config (dynamic, per session)

- `~/` mounted into container (read-only by default)
- Per-distro localhost SSH port published to container port `2222`
- SSH agent forwarded with native `container --ssh`
- A macbox-managed SSH public key synced into `authorized_keys`
- A generated SSH config at `~/Library/Application Support/macbox/ssh/config`
- Listening TCP app ports are auto-forwarded to localhost while the distro is running
- LANG, TERM, EDITOR forwarded
- User-specified port forwards and mounts
- CPU and memory limits

### Provisioning (first create only)

Commands run inside the container after creation — install packages, clone repos, configure tools.

## Mental Model

- `create` builds a per-user image layer and starts a persistent container.
- `enter` reuses that container like a named distro instead of creating a fresh one each time.
- Each distro gets its own managed SSH key, localhost SSH port, and SSH alias.
- App ports are discovered after startup and forwarded back to your Mac automatically.

## Who It Is For

`macbox` is a good fit for:

- developers who want persistent Linux environments on macOS
- teams that want reproducible onboarding with a checked-in `macbox.json`
- backend and service workflows that need Linux userland but easy localhost access
- people juggling multiple toolchains, distro versions, or project-specific setups

`macbox` is a weaker fit for:

- GUI Linux desktop app workflows
- strong isolation or sandboxing use cases
- heavy `systemd` or full-VM expectations
- projects that already work well with native macOS tooling

## Example Distros

- `webdev`: Node, Python, frontend tooling, and a mounted projects directory
- `backend`: Go/Rust/Java plus Docker/Compose for multi-service stacks
- `infra`: Terraform, Ansible, `kubectl`, Helm, and cloud CLIs
- `db-lab`: PostgreSQL, Redis, ClickHouse, or other local Linux services
- `compat-ubuntu`: a pinned Ubuntu version for older dependencies
- `editor`: a Linux coding environment used mainly through VS Code Remote SSH

## When To Use What

| Need | Best fit |
| --- | --- |
| A persistent Linux dev box on your Mac | `macbox` |
| A single app container or disposable runtime | Docker / `container run` |
| A fuller machine-like environment with stronger isolation | VM |
| Native macOS tools are already enough | Stay on macOS |

## Isolation Boundaries

`macbox` is designed for developer convenience and workflow isolation, not for strong sandboxing.

What `macbox` is good at:

- keeping Linux toolchains and dependencies out of your macOS host
- separating projects into distinct persistent distros
- limiting exposure to localhost services instead of broad network access
- giving you a more structured boundary than installing everything directly on macOS

What `macbox` is not designed to guarantee:

- strong isolation from untrusted code
- VM-grade separation from the host
- desktop-style sandbox policies
- safe execution of hostile workloads with access to forwarded mounts, SSH agent, or secrets

If you need a stronger security boundary, prefer a VM-oriented setup with reduced host mounts and fewer integrations.

## Examples

### Web app dev

```bash
macbox create ubuntu:24.04 webdev \
  --mount ~/projects:/home/$(whoami)/projects:rw \
  --provision "apt-get update && apt-get install -y git curl nodejs npm"

macbox enter webdev
cd ~/projects/my-app
npm install
npm run dev

# In another macOS terminal
macbox ports webdev
open http://127.0.0.1:3000
```

### Multi-service backend

```bash
macbox create ubuntu:24.04 backend \
  --mount ~/src:/home/$(whoami)/src:rw \
  --cpus 4 \
  --memory 8g \
  --provision "apt-get update && apt-get install -y docker.io docker-compose-plugin"

macbox enter backend
cd ~/src/my-stack
docker compose up

# Inspect forwarded ports
macbox list
macbox ports backend
```

### VS Code Remote SSH

```bash
macbox create ubuntu:24.04 editor

# Connect with the generated SSH alias
ssh -F ~/Library/Application\ Support/macbox/ssh/config macbox-editor

# Or open directly in VS Code Remote SSH after create
code --remote ssh-remote+$(whoami)@localhost:<assigned-port> /home/$(whoami)
```

## Troubleshooting

### `container` CLI not found

- Install or build the Apple `container` CLI first.
- If it is not on your `PATH`, set `MACBOX_CONTAINER_BIN=/path/to/container`.
- Make sure the runtime is started with `container system start`.

### SSH does not connect

- Run `macbox list` and confirm the distro is running.
- Use the printed SSH command or the generated SSH config:
  `ssh -F ~/Library/Application\ Support/macbox/ssh/config macbox-<name>`
- If needed, re-run `macbox enter <name> --ssh` to refresh the SSH config and key sync.

### Auto-forwarded ports do not appear

- Start the app inside the distro first, then wait a few seconds for the background sync loop.
- Run `macbox ports <name>` to inspect detected forwards.
- The current implementation auto-forwards listening TCP ports only.
- If the app binds late or changes ports, check again after it is fully started.

### Base image behaves unexpectedly

- `macbox` works best with standard Linux OCI images that include or can install common user and package-management tools.
- Ubuntu, Debian, Alpine, Fedora, AlmaLinux, and similar images are the best candidates.
- Extremely minimal or unusual images may fail during package install, user creation, or SSH setup.

## Design

```
┌──────────────────────────────────────────────────────────┐
│                       macbox create                      │
│                                                          │
│  macbox.json / CLI                                       │
│         │                                                │
│         ├──────────────────────┐                         │
│         ▼                      ▼                         │
│  container build         container run                  │
│         │                      │                         │
│         ▼                      ▼                         │
│  Image Layer              Running Distro                 │
│  (built once)             (persistent container)         │
│                                                          │
│  • UID/GID user           • home / project mounts        │
│  • sudo                   • SSH agent forwarding         │
│  • login shell            • env vars                     │
│  • sshd                   • manual published ports       │
│                                                          │
│         └──────────────┬───────────────┬────────────────┘
│                        │               │
│                        ▼               ▼
│                 Post-start sync   Persisted state
│                 • authorized_keys • distro metadata
│                 • SSH config      • SSH port
│                 • managed keypair • managed key paths
│
│                        ▼
│                 Background monitor
│                 • detect listening TCP ports
│                 • create localhost forwards
│                 • update `macbox ports`
│
│                        ▼
│                 Developer workflow
│                 • macbox enter
│                 • SSH / VS Code
│                 • localhost services
│                 • provisioning
└──────────────────────────────────────────────────────────┘
```

## Requirements

- macOS 15+
- [Apple container](https://github.com/apple/container) CLI
- Swift 6.2+
