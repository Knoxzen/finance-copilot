#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# GitHub Project Bootstrap Toolkit
# Main entrypoint script to create labels, milestones, project boards, epics, and tasks.

# Get the script directory and source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/yaml.sh"
source "$SCRIPT_DIR/lib/github.sh"
source "$SCRIPT_DIR/lib/project.sh"
source "$SCRIPT_DIR/lib/issue.sh"

# Define config file paths
CONFIG_FILE="$SCRIPT_DIR/config/config.yaml"
LABELS_FILE="$SCRIPT_DIR/config/labels.yaml"
MILESTONES_FILE="$SCRIPT_DIR/config/milestones.yaml"
ROADMAP_FILE="$SCRIPT_DIR/config/roadmap.yaml"

# Parse CLI options
DRY_RUN=false
COMMAND=""

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  else
    COMMAND="$arg"
  fi
done

# If no command is provided, default to "all"
if [[ -z "$COMMAND" ]]; then
  COMMAND="all"
fi

# Verify environments and tools first (before parsing yaml config, to avoid raw shell crash)
github_validate_tools

# Load owner and repo config
OWNER=$(yaml_get_val "$CONFIG_FILE" ".owner")
REPO=$(yaml_get_val "$CONFIG_FILE" ".repo")

# Validate repository access
github_validate_repo "$OWNER" "$REPO"

# Setup global variables for Project V2 metadata
PROJECT_ID=""
STATUS_FIELD_ID=""
STATUS_BACKLOG_OPT_ID=""
PRIORITY_FIELD_ID=""
PRIORITY_MEDIUM_OPT_ID=""

# Helper to fetch project cache (avoid repeated GraphQL calls)
cache_project_metadata() {
  if [[ "$DRY_RUN" == "true" ]]; then
    PROJECT_ID="dry_run_project_id"
    STATUS_FIELD_ID="dry_run_status_field_id"
    STATUS_BACKLOG_OPT_ID="dry_run_backlog_opt_id"
    PRIORITY_FIELD_ID="dry_run_priority_field_id"
    PRIORITY_MEDIUM_OPT_ID="dry_run_medium_opt_id"
    return 0
  fi

  local project_name
  project_name=$(yaml_get_val "$CONFIG_FILE" ".project.name")
  
  # Get project ID (existing or newly created)
  PROJECT_ID=$(project_setup "$OWNER" "$REPO" "$project_name" "$DRY_RUN")

  # Query the project fields JSON
  local fields_json
  fields_json=$(project_query_fields "$PROJECT_ID")

  # Resolve fields and option IDs
  STATUS_FIELD_ID=$(project_get_field_id "$fields_json" "Status")
  STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$fields_json" "Status" "Backlog")
  
  # Fallbacks for status
  if [[ -z "$STATUS_BACKLOG_OPT_ID" || "$STATUS_BACKLOG_OPT_ID" == "null" ]]; then
    STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$fields_json" "Status" "Todo")
  fi
  if [[ -z "$STATUS_BACKLOG_OPT_ID" || "$STATUS_BACKLOG_OPT_ID" == "null" ]]; then
    STATUS_BACKLOG_OPT_ID=$(project_get_field_option_id "$fields_json" "Status" "To Do")
  fi

  PRIORITY_FIELD_ID=$(project_get_field_id "$fields_json" "Priority")
  PRIORITY_MEDIUM_OPT_ID=$(project_get_field_option_id "$fields_json" "Priority" "Medium")
}

# --- Setup Operations ---

setup_labels() {
  echo "=== Creating Labels ==="
  local labels_json
  labels_json=$(yaml_to_json "$LABELS_FILE" | jq -c '.labels[]')

  while read -r label; do
    if [[ -z "$label" ]]; then continue; fi
    local name
    name=$(echo "$label" | jq -r '.name')
    local color
    color=$(echo "$label" | jq -r '.color')
    local desc
    desc=$(echo "$label" | jq -r '.description // empty')

    # Remove leading '#' from color if present
    color="${color#\#}"

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "Dry-run: Would ensure label '$name' (color: $color, description: '$desc') exists."
    else
      echo "Ensuring label '$name' exists..."
      gh label create "$name" \
        --repo "$OWNER/$REPO" \
        --color "$color" \
        --description "$desc" \
        2>/dev/null || true
    fi
  done <<< "$labels_json"
  echo "✓ Labels setup complete."
  echo
}

setup_milestones() {
  echo "=== Creating Milestones ==="
  local milestones_json
  milestones_json=$(yaml_to_json "$MILESTONES_FILE" | jq -c '.milestones[]')

  while read -r milestone; do
    if [[ -z "$milestone" ]]; then continue; fi
    local title
    title=$(echo "$milestone" | jq -r '.')

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "Dry-run: Would ensure milestone '$title' exists."
    else
      echo "Ensuring milestone '$title' exists..."
      gh api repos/"$OWNER/$REPO"/milestones \
        -f title="$title" \
        >/dev/null 2>&1 || true
    fi
  done <<< "$milestones_json"
  echo "✓ Milestones setup complete."
  echo
}

setup_project() {
  echo "=== Creating/Configuring Project V2 ==="
  local project_name
  project_name=$(yaml_get_val "$CONFIG_FILE" ".project.name")
  
  local p_id
  p_id=$(project_setup "$OWNER" "$REPO" "$project_name" "$DRY_RUN")
  project_setup_fields "$p_id" "$DRY_RUN"
  
  echo "✓ Project setup complete."
  echo
}

setup_epics() {
  echo "=== Creating Epics ==="
  cache_project_metadata

  local epics_json
  epics_json=$(yaml_to_json "$ROADMAP_FILE" | jq -c '.epics[]')

  while read -r epic; do
    if [[ -z "$epic" ]]; then continue; fi
    local name
    name=$(echo "$epic" | jq -r '.name')
    local body="Epic for $name"

    # Create epic
    local epic_res
    epic_res=$(issue_create_epic "$OWNER" "$REPO" "$name" "$body" "enhancement" "" "$DRY_RUN")

    # Add to Project V2 and set fields
    if [[ "$DRY_RUN" == "false" && -n "$PROJECT_ID" ]]; then
      local node_id
      node_id=$(echo "$epic_res" | jq -r '.id')
      
      echo "Adding Epic to Project V2..."
      local item_id
      item_id=$(issue_add_to_project "$PROJECT_ID" "$node_id" "$DRY_RUN")

      echo "Setting Epic project fields (Status=Backlog, Priority=Medium)..."
      issue_set_project_field "$PROJECT_ID" "$item_id" "$STATUS_FIELD_ID" "$STATUS_BACKLOG_OPT_ID" "$DRY_RUN"
      issue_set_project_field "$PROJECT_ID" "$item_id" "$PRIORITY_FIELD_ID" "$PRIORITY_MEDIUM_OPT_ID" "$DRY_RUN"
    fi
  done <<< "$epics_json"
  echo "✓ Epics setup complete."
  echo
}

setup_tasks() {
  echo "=== Creating Tasks and Linking to Epics ==="
  cache_project_metadata

  local epics_json
  epics_json=$(yaml_to_json "$ROADMAP_FILE" | jq -c '.epics[]')

  while read -r epic; do
    if [[ -z "$epic" ]]; then continue; fi
    local epic_name
    epic_name=$(echo "$epic" | jq -r '.name')

    local epic_title="$epic_name"
    if [[ ! "$epic_title" =~ ^\[EPIC\] ]]; then
      epic_title="[EPIC] $epic_title"
    fi

    # Find parent epic details
    local parent_num=""
    local parent_id=""
    if [[ "$DRY_RUN" == "false" ]]; then
      local parent_issue
      parent_issue=$(issue_find "$OWNER" "$REPO" "$epic_title")
      if [[ -z "$parent_issue" ]]; then
        echo "WARNING: Could not find Epic: '$epic_title'. Skipping tasks for this epic."
        continue
      fi
      parent_num=$(echo "$parent_issue" | jq -r '.number')
      parent_id=$(echo "$parent_issue" | jq -r '.id')
    fi

    # Get tasks for this epic
    local tasks_json
    tasks_json=$(echo "$epic" | jq -c '.tasks[]?')
    if [[ -z "$tasks_json" ]]; then
      continue
    fi

    while read -r task; do
      if [[ -z "$task" ]]; then continue; fi
      local title
      title=$(echo "$task" | jq -r '.title')
      local labels_comma
      labels_comma=$(echo "$task" | jq -r '.labels | join(",") // empty')
      local body="Part of $epic_title"

      # Create task and link to parent epic
      local task_res
      task_res=$(issue_create_task "$OWNER" "$REPO" "$title" "$body" "$labels_comma" "" "$parent_num" "$parent_id" "$DRY_RUN")

      # Add to project and set fields
      if [[ "$DRY_RUN" == "false" && -n "$PROJECT_ID" ]]; then
        local node_id
        node_id=$(echo "$task_res" | jq -r '.id')

        echo "Adding Task to Project V2..."
        local item_id
        item_id=$(issue_add_to_project "$PROJECT_ID" "$node_id" "$DRY_RUN")

        echo "Setting Task project fields (Status=Backlog, Priority=Medium)..."
        issue_set_project_field "$PROJECT_ID" "$item_id" "$STATUS_FIELD_ID" "$STATUS_BACKLOG_OPT_ID" "$DRY_RUN"
        issue_set_project_field "$PROJECT_ID" "$item_id" "$PRIORITY_FIELD_ID" "$PRIORITY_MEDIUM_OPT_ID" "$DRY_RUN"
      fi
    done <<< "$tasks_json"
  done <<< "$epics_json"
  echo "✓ Tasks setup complete."
  echo
}

# --- Execution ---

if [[ "$DRY_RUN" == "true" ]]; then
  echo "!!! RUNNING IN DRY RUN MODE !!!"
  echo "No changes will be written to GitHub."
  echo
fi

case "$COMMAND" in
  labels)
    setup_labels
    ;;
  milestones)
    setup_milestones
    ;;
  project)
    setup_project
    ;;
  epics)
    setup_epics
    ;;
  tasks)
    setup_tasks
    ;;
  all)
    setup_labels
    setup_milestones
    setup_project
    setup_epics
    setup_tasks
    ;;
  *)
    echo "ERROR: Unknown command '$COMMAND'" >&2
    echo "Valid commands are: labels, milestones, project, epics, tasks, all" >&2
    exit 1
    ;;
esac

echo "========================================="
echo "BOOTSTRAP RUN COMPLETED SUCCESSFULLY!"
echo "========================================="
