#!/usr/bin/env bash

OVERRIDE_FILE="${HOME}/Library/Application\ Support/rancher-desktop/lima/_config/override.yaml"

cat <<EOT > "${OVERRIDE_FILE}"
---
ssh:
  forwardAgent: true
provision:
  - mode: system
    script: |
      #!/bin/sh
      cat <<'EOF' > /etc/security/limits.d/rancher-desktop.conf
      * soft     nofile         82920
      * hard     nofile         82920
      EOF
      sysctl -w vm.max_map_count=262144
EOT
