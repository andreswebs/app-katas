#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

export url_paths=(
  "/vets"
  "/pettypes"
  "/owners"
)

ARRAY_SIZE=${#url_paths[@]}
i=1
while true
do
  url_path=${url_paths[$((RANDOM % ARRAY_SIZE))]}
  if ! ((i % 100))
  then
    echo "${i} requests"
    sleep "$(( ( RANDOM % 10 ) + 1 ))s"
  fi
  curl -s "${API_URL}/${url_path}" -o /dev/null &
  sleep ".$(( RANDOM % 100 ))s"
  ((i++))
done