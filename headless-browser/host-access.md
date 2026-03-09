# Accessing Host Services from Docker Containers

## Problem

Allow a container on a Docker bridge network to access services running on `localhost` on the host machine.

## Solution: `host.docker.internal`

From inside any container, use `host.docker.internal` instead of `localhost` to reach host services.

For example, if a web app runs on `localhost:3000` on the host, the container can reach it at:

```
http://host.docker.internal:3000
```

## macOS (Docker Desktop / Rancher Desktop)

`host.docker.internal` works out of the box — no extra configuration needed.

Rancher Desktop also provides `host.rancher-desktop.internal` as an alternative.

> **Note (Rancher Desktop):** Ensure the container runtime is set to **Docker (moby)**, not containerd, when using `docker compose`.

## Linux

On Linux, `host.docker.internal` must be explicitly enabled via `extra_hosts`:

```yaml
services:
  headless-browser:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

## Verification

Test connectivity from inside a container:

```sh
docker run -it --rm busybox nslookup host.docker.internal
docker run -it --rm busybox ping host.docker.internal
```

## Notes

- The container stays on its bridge network and remains accessible to other containers on that network.
- No need to use `network_mode: host`.
- Adding `extra_hosts` on macOS is harmless and improves portability.
