#!/usr/bin/env bash
#
# Generate the replica-set internal-authentication keyfile into a named volume.
#
# The keyfile lives in a volume rather than a host bind mount on purpose. On a
# Lima-backed Docker (Rancher Desktop, Docker Desktop on macOS) a host path
# reaches the VM over virtiofs, where ownership and mode do not survive: `chown`
# fails with "Permission denied" and the file commonly appears as nobody:nobody.
# mongod then refuses to start, with an error naming neither the mount nor the
# fix. A path inside the VM's own filesystem behaves exactly as Debian does.
#
# See lima-vm/lima#231 and rancher-sandbox/rancher-desktop#1209, #1679, #7924.

set -euo pipefail

KEYFILE_PATH="${KEYFILE_PATH:-/keyfile/mongodb-keyfile}"
KEYFILE_UID="${KEYFILE_UID:-999}"
KEYFILE_GID="${KEYFILE_GID:-999}"

if [ -s "${KEYFILE_PATH}" ]; then
  echo "keyfile: ${KEYFILE_PATH} already present, leaving it alone"
else
  echo "keyfile: generating ${KEYFILE_PATH}"
  mkdir -p "$(dirname "${KEYFILE_PATH}")"
  openssl rand -base64 756 > "${KEYFILE_PATH}"
fi

chown "${KEYFILE_UID}:${KEYFILE_GID}" "${KEYFILE_PATH}"
chmod 400 "${KEYFILE_PATH}"

ls -l "${KEYFILE_PATH}"
