#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Create Tasks under an Epic from YAML file
# Usage: ./create-tasks.sh <path-to-epic.yaml>

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

# Read Epic name
EPIC_NAME=$(yaml_get_val "$EPIC_YAML" ".epic.name")

if [[ -z "$EPIC_NAME" || "$EPIC_NAME" == "null" ]]; then
  echo "ERROR: Epic name not defined in $EPIC_YAML (expected '.epic.name')" >&2
  exit 1
fi

# Formulate full Epic title
EPIC_TITLE="$EPIC_NAME"
if [[ ! "$EPIC_TITLE" =~ ^\[EPIC\] ]]; then
  EPIC_TITLE="[EPIC] $EPIC_TITLE"
fi

# Find the Epic issue
echo "Finding Epic: '$EPIC_TITLE'..."
EPIC_RES=$(issue_find "$OWNER" "$REPO" "$EPIC_TITLE")

if [[ -z "$EPIC_RES" ]]; then
  echo "ERROR: Epic '$EPIC_TITLE' was not found in the repository." >&2
  echo "Please create the epic first using:" >&2
  echo "    ./create-epic.sh $EPIC_YAML" >&2
  exit 1
fi

EPIC_NUM=$(echo "$EPIC_RES" | jq -r '.number')
EPIC_NODE_ID=$(echo "$EPIC_RES" | jq -r '.id')
echo "✓ Found Epic #$EPIC_NUM (ID: $EPIC_NODE_ID)"

# Get tasks list
TASKS_JSON=$(yaml_to_json "$EPIC_YAML" | jq -c '.epic.tasks[]?')

if [[ -z "$TASKS_JSON" ]]; then
  echo "No tasks found in $EPIC_YAML under '.epic.tasks'. Nothing to create."
  exit 0
fi

# Link to Project V2
PROJECT_NAME=$(yaml_get_val "$CONFIG_FILE" ".project.name")
PROJECT_ID=$(project_setup "$OWNER" "$REPO" "$PROJECT_NAME" "false")

STATUS_FIELD_ID=""
STATUS_BACKLOG_OPT_ID=""
PRIORITY_FIELD_ID=""
PRIORITY_MEDIUM_OPT_ID=""

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
fi

echo "=== Creating Tasks under Epic #$EPIC_NUM ==="

# Create tasks
while read -r task; do
  if [[ -z "$task" ]]; then continue; fi
  TITLE=$(echo "$task" | jq -r '.title')
  LABELS_COMMA=$(echo "$task" | jq -r '.labels | join(",") // empty')
  BODY="Part of $EPIC_TITLE"

  # Create task and link to Epic
  TASK_RES=$(issue_create_task "$OWNER" "$REPO" "$TITLE" "$BODY" "$LABELS_COMMA" "" "$EPIC_NUM" "$EPIC_NODE_ID" "false")
  TASK_NODE_ID=$(echo "$TASK_RES" | jq -r '.id')
  TASK_NUM=$(echo "$TASK_RES" | jq -r '.number')

  # Add to Project V2
  if [[ -n "$PROJECT_ID" ]]; then
    echo "Adding Task #$TASK_NUM to Project V2..."
    ITEM_ID=$(issue_add_to_project "$PROJECT_ID" "$TASK_NODE_ID" "false")

    echo "Setting Task #$TASK_NUM project fields (Status=Backlog, Priority=Medium)..."
    issue_set_project_field "$PROJECT_ID" "$ITEM_ID" "$STATUS_FIELD_ID" "$STATUS_BACKLOG_OPT_ID" "false"
    issue_set_project_field "$PROJECT_ID" "$ITEM_ID" "$PRIORITY_FIELD_ID" "$PRIORITY_MEDIUM_OPT_ID" "false"
  fi
done <<< "$TASKS_JSON"

echo "========================================="
echo "Tasks creation and linking complete!"
echo "========================================="
