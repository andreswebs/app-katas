#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

FILE="${1}"

function echo_stderr {
    echo "${*}" >&2
}

if [ ! -r "${FILE}" ]; then
    echo_stderr "error: ${FILE} is not readable"
    exit 1
fi

jq --compact-output --monochrome-output < "${FILE}"
