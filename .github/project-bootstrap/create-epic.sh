#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Create Epic from YAML file
# Usage: ./create-epic.sh <path-to-epic.yaml>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/yaml.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/project.sh"
source "$SCRIPT_DIR/lib/issue.sh"

# Paths to configurations
CONFIG_FILE="$SCRIPT_DIR/config/config.yaml"

# Validate input
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-epic.yaml>" >&2
  exit 1
fi

EPIC_YAML="$1"

if [[ ! -f "$EPIC_YAML" ]]; then
  echo "ERROR: Epic YAML file not found: $EPIC_YAML" >&2
  exit 1
fi

# Verify environments and tools first (before parsing yaml config, to avoid raw shell crash)
github_validate_tools

# Load owner and repo config
OWNER=$(yaml_get_val "$CONFIG_FILE" ".owner")
REPO=$(yaml_get_val "$CONFIG_FILE" ".repo")

# Validate repository access
github_validate_repo "$OWNER" "$REPO"

# Read Epic information
EPIC_NAME=$(yaml_get_val "$EPIC_YAML" ".epic.name")
EPIC_DESC=$(yaml_get_val "$EPIC_YAML" ".epic.description // \"Epic for $EPIC_NAME\"")

if [[ -z "$EPIC_NAME" || "$EPIC_NAME" == "null" ]]; then
  echo "ERROR: Epic name not defined in $EPIC_YAML (expected '.epic.name')" >&2
  exit 1
fi

echo "=== Creating Epic from file: $EPIC_YAML ==="
echo "Epic Name: $EPIC_NAME"

# Create the epic issue
EPIC_RES=$(issue_create_epic "$OWNER" "$REPO" "$EPIC_NAME" "$EPIC_DESC" "enhancement" "" "false")
EPIC_NUM=$(echo "$EPIC_RES" | jq -r '.number')
EPIC_NODE_ID=$(echo "$EPIC_RES" | jq -r '.id')

# Link to Project V2
PROJECT_NAME=$(yaml_get_val "$CONFIG_FILE" ".project.name")
PROJECT_ID=$(project_setup "$OWNER" "$REPO" "$PROJECT_NAME" "false")

if [[ -n "$PROJECT_ID" ]]; then
  # Load project fields and options cache
  FIELDS_JSON=$(project_query_fields "$PROJECT_ID")
  STATUS_FIELD_ID=$(project_get_field_id "$FIELDS_JSON" "Status")
  STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$FIELDS_JSON" "Status" "Backlog")
  
  if [[ -z "$STATUS_BACKLOG_OPT_ID" || "$STATUS_BACKLOG_OPT_ID" == "null" ]]; then
    STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$FIELDS_JSON" "Status" "Todo")
  fi
  if [[ -z "$STATUS_BACKLOG_OPT_ID" || "$STATUS_BACKLOG_OPT_ID" == "null" ]]; then
    STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$FIELDS_JSON" "Status" "To Do")
  fi

  PRIORITY_FIELD_ID=$(project_get_field_id "$FIELDS_JSON" "Priority")
  PRIORITY_MEDIUM_OPT_ID=$(project_get_field_option_id "$FIELDS_JSON" "Priority" "Medium")

  echo "Adding Epic to Project V2..."
  ITEM_ID=$(issue_add_to_project "$PROJECT_ID" "$EPIC_NODE_ID" "false")

  echo "Setting Epic project fields (Status=Backlog, Priority=Medium)..."
  issue_set_project_field "$PROJECT_ID" "$ITEM_ID" "$STATUS_FIELD_ID" "$STATUS_BACKLOG_OPT_ID" "false"
  issue_set_project_field "$PROJECT_ID" "$ITEM_ID" "$PRIORITY_FIELD_ID" "$PRIORITY_MEDIUM_OPT_ID" "false"
fi

echo "========================================="
echo "Epic #$EPIC_NUM created and linked successfully!"
echo "========================================="
