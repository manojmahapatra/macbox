# `macbox create`

Create a new persistent Linux distro on macOS from an OCI image or config file.

## Synopsis

macbox create

```text
[<image>] <name>      image may be omitted only when --config provides it
-c, --config          path to a macbox.json config file
-m, --mount           additional bind mount in hostPath:containerPath[:ro] form
-p, --publish         manual port forward in hostPort:containerPort form
--provision           command to run inside the distro after creation
--cpus                CPU limit
--memory              memory limit, for example 4g or 2048m
--home-rw             mount the host home directory read-write
--home-ro             force the host home directory to stay read-only
-h, --help            show help information
```

## Description

`macbox create` builds a per-user image layer for your macOS account, starts a persistent distro from it, and wires up the runtime integration that `macbox` manages:

- a matching Linux user for your macOS username and UID/GID
- a managed per-distro SSH key
- a unique localhost SSH port
- host mounts and forwarded environment variables
- automatic localhost forwarding for listening TCP app ports

You can create a distro directly from a base OCI image such as `ubuntu:24.04`, or load most settings from a `macbox.json` file with `--config`.

## Arguments

### `<image>`

Base image to build from, for example:

```bash
ubuntu:24.04
debian:bookworm
alpine:latest
```

Ignored when `--config` provides the image.

### `<name>`

Name of the distro to create. This name is used for:

- the running container name
- the generated SSH alias `macbox-<name>`
- the persisted distro state and managed SSH key directory

## Options

### `-c`, `--config <config>`

Load distro settings from a `macbox.json` file.

The config file can supply the image, mounts, published ports, provisioning commands, and resource limits.

Example:

```bash
macbox create --config macbox.json mydev
```

### `-m`, `--mount <hostPath:containerPath[:ro]>`

Add an extra bind mount.

Examples:

```bash
macbox create ubuntu:24.04 mydev --mount ~/projects:/work
macbox create ubuntu:24.04 mydev --mount ~/secrets:/run/secrets:ro
```

Notes:

- `:ro` makes the mount read-only
- without `:ro`, the mount is writable
- this is in addition to the default host home mount managed by `macbox`

### `-p`, `--publish <hostPort:containerPort>`

Publish a TCP port manually at startup.

Example:

```bash
macbox create ubuntu:24.04 mydev --publish 8080:8080
```

`macbox` also has automatic localhost forwarding for listening TCP app ports, but `--publish` is useful when you want a fixed host port from the start.

### `--provision <command>`

Run a shell command inside the distro after it is created.

You can pass the option multiple times:

```bash
macbox create ubuntu:24.04 mydev \
  --provision "apt-get update" \
  --provision "apt-get install -y git curl"
```

### `--cpus <count>`

Set a CPU limit for the distro.

Example:

```bash
macbox create ubuntu:24.04 mydev --cpus 4
```

### `--memory <size>`

Set a memory limit for the distro.

Examples:

```bash
macbox create ubuntu:24.04 mydev --memory 4g
macbox create ubuntu:24.04 mydev --memory 2048m
```

### `--home-rw`

Mount your macOS home directory read-write instead of read-only.

### `--home-ro`

Force your macOS home directory to remain read-only.

This is useful when the config file enables a writable home mount and you want to override it from the CLI.

## Config File

`macbox create` can read a config file created with `macbox init`.

The image must be provided either as the `<image>` argument or in the config file.

Example:

```json
{
  "image": "ubuntu:24.04",
  "mounts": ["~/projects:/home/user/projects:rw"],
  "ports": ["3000:3000", "8080:8080"],
  "provision": ["apt-get update && apt-get install -y git curl nodejs"],
  "homeRW": false,
  "cpus": 4,
  "memory": "4g"
}
```

CLI flags override config file values:

- CLI `--mount` replaces config `mounts`
- CLI `--publish` replaces config `ports`
- CLI `--provision` replaces config `provision`
- CLI `--cpus` and `--memory` override config values
- CLI `--home-rw` and `--home-ro` override config `homeRW`

## What Gets Created

After a successful `create`, `macbox` will:

1. build a per-user image from the base OCI image
2. start a persistent distro container
3. assign a unique localhost SSH port
4. generate a managed SSH keypair for the distro
5. write an SSH alias under:

```bash
~/Library/Application Support/macbox/ssh/config
```

6. save distro metadata under:

```bash
~/Library/Application Support/macbox/distros/
```

## Examples

### Basic Ubuntu distro

```bash
macbox create ubuntu:24.04 mydev
```

### Create from config

```bash
macbox init
macbox create --config macbox.json mydev
```

### Create from config with CLI overrides

```bash
macbox create --config macbox.json mydev --cpus 8 --home-ro
```

### Add project mounts and provisioning

```bash
macbox create ubuntu:24.04 webdev \
  --mount ~/projects:/home/$(whoami)/projects:rw \
  --provision "apt-get update" \
  --provision "apt-get install -y git curl nodejs npm"
```

### Set resource limits

```bash
macbox create ubuntu:24.04 backend --cpus 4 --memory 8g
```

### Make the home mount writable

```bash
macbox create ubuntu:24.04 mydev --home-rw
```

## Next Steps

After creating a distro:

```bash
macbox enter mydev
macbox enter mydev --ssh
macbox list
macbox ports mydev
```

`macbox create` also prints the assigned SSH port, a direct SSH command, and the generated SSH alias when creation succeeds.

## See Also

- [`README.md`](../../README.md)
