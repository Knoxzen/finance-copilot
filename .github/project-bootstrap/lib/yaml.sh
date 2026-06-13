#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Helper library for parsing YAML files using yq and jq.
# Designed for compatibility with Git Bash on Windows and Linux.

# Convert YAML file to JSON on stdout.
# Usage: yaml_to_json "path/to/file.yaml"
yaml_to_json() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    echo "ERROR: yaml_to_json requires a file path argument" >&2
    return 1
  fi
  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file" >&2
    return 1
  fi
  yq -o=json "$file"
}

# Query a value from a YAML file using a jq filter.
# Usage: yaml_get_val "path/to/file.yaml" ".project.name"
yaml_get_val() {
  local file="${1:-}"
  local filter="${2:-}"
  if [[ -z "$file" || -z "$filter" ]]; then
    echo "ERROR: yaml_get_val requires file path and jq filter arguments" >&2
    return 1
  fi
  yaml_to_json "$file" | jq -r "$filter"
}

# Query a value and check if it is not null/empty (returns exit code).
# Usage: if yaml_has_val "path/to/file.yaml" ".project.name"; then ...
yaml_has_val() {
  local file="${1:-}"
  local filter="${2:-}"
  if [[ -z "$file" || -z "$filter" ]]; then
    echo "ERROR: yaml_has_val requires file path and jq filter arguments" >&2
    return 1
  fi
  local res
  res=$(yaml_to_json "$file" | jq -e "$filter" 2>/dev/null)
  if [[ "$res" == "null" || -z "$res" ]]; then
    return 1
  fi
  return 0
}
