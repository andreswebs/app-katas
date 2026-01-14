#!/usr/bin/env bash
# https://www.honeycomb.io/blog/test-span-opentelemetry-collector/
curl -i http://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d @span.mock.json
