#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

FILE="${1}"

function log {
    >&2 echo "${1}"
}

if [ ! -r "${FILE}" ]; then
    log "error: ${FILE} is not readable"
    exit 1
fi

if ! jq empty "${FILE}"; then
    log "error: ${FILE} does not contain valid JSON"
    exit 1
fi

cat "${FILE}" | tr -d '\n' | tr -d ' '
