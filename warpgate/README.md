<https://github.com/warp-tech/warpgate>
<https://warpgate.null.page>

Full agent-facing docs-nav guide, EKS Kubernetes-target how-to, deployment plan,
and basti-migration comparison live outside this repo at
`~/.docs/warpgate-docs-nav/` (guide) and
`~/programs/work/p41/.local/planning/warpgate-deployment-plan.md` (deployment
plan, gitignored there).

## Setup

`warpgate-setup` runs `warpgate unattended-setup` once against the `warpgate-db`
Postgres service and writes `/data/warpgate.yaml`, then exits; the main
`warpgate` service waits on that exit before starting (`run`, the image's
default command). Re-running `docker compose up` after the first successful
run is safe - the setup container detects the existing config and no-ops.

Log in at `https://localhost:${WARPGATE_HTTPS_EXPOSED_PORT:-8888}/@warpgate/admin`
as `admin` / `$WARPGATE_ADMIN_PASSWORD`, self-signed cert (Warpgate generates its
own during setup).

## Quirks

- **`/data` must be a named volume, not a host bind-mount.** The image runs as
  a non-root `warpgate` user (uid 1000) and has no entrypoint step that chowns
  a bind-mounted directory the way the official postgres image's entrypoint
  does. Docker only seeds a fresh volume's ownership from the image's own
  `/data` directory for *named* volumes; a host bind-mount just exposes the
  host path as-is and `unattended-setup` fails with `Permission denied (os
  error 13)`. Confirmed by running this stack end to end.
- The image bakes in `ENV WARPGATE_CONFIG=/data/warpgate.yaml` and its own
  `HEALTHCHECK CMD warpgate healthcheck` - no need to pass `--config` or
  override the healthcheck in compose.
- A bare `command: |` string under a service with a `["/bin/sh", "-c"]`
  entrypoint gets shell-tokenized by Docker Compose into separate argv
  entries (breaking the script on every space) rather than passed through as
  one argument. Wrap it as a one-element YAML list (`command: - |`) to keep
  it as a single `-c` argument. Confirmed via `docker compose config`.
- `unattended-setup` reads `WARPGATE_ADMIN_PASSWORD` from the environment when
  `--admin-password` isn't passed on the command line; used here to keep the
  admin password out of `docker inspect`/`ps` output. `--database-url` has no
  such env-var fallback, so it does appear in the setup container's command line.
- SSH, MySQL, PostgreSQL, and Kubernetes listeners are enabled at setup time;
  VNC and RDP are not (pass `--vnc-port`/`--rdp-port` to `warpgate-setup`'s
  command if needed).
- `--record-sessions` is on by default here - drop it from `warpgate-setup`'s
  command if session recording isn't wanted.
- Warpgate logs `Target credentials are stored unencrypted` on every startup
  until `WARPGATE_ENCRYPTION_KEY` is set - not wired into this kata (local/dev
  only), but required reading before this pattern goes anywhere production
  (see `production-checklist/` via the docs-nav guide).
