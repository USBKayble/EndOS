#!/usr/bin/env bash
# Write installation configuration to JSON file

CONFIG_DATA="$1"
OUTPUT_FILE="${2:-/tmp/endos-install-config.json}"

echo "$CONFIG_DATA" > "$OUTPUT_FILE"
echo "$OUTPUT_FILE"
