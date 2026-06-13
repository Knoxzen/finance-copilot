#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Library for managing GitHub Projects V2.
# Implements project detection, creation, linking, custom field setup, and option resolution.

# Query repository and owner IDs, and list existing projects.
# Usage: project_query_meta "owner" "repo"
project_query_meta() {
  local owner="$1"
  local repo="$2"

  local query
  query='query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      id
      owner {
        id
        __typename
        ... on User {
          projectsV2(first: 100) {
            nodes {
              id
              title
              number
            }
          }
        }
        ... on Organization {
          projectsV2(first: 100) {
            nodes {
              id
              title
              number
            }
          }
        }
      }
    }
  }'

  github_graphql "$query" -f owner="$owner" -f repo="$repo"
}

# Create a Project V2.
# Usage: project_create "owner_node_id" "repo_node_id" "title"
project_create() {
  local owner_id="$1"
  local repo_id="$2"
  local title="$3"

  local query
  query='mutation($ownerId: ID!, $title: String!, $repositoryId: ID) {
    createProjectV2(input: { ownerId: $ownerId, title: $title, repositoryId: $repositoryId }) {
      projectV2 {
        id
        title
        number
      }
    }
  }'

  github_graphql "$query" -f ownerId="$owner_id" -f title="$title" -f repositoryId="$repo_id"
}

# Query all fields and their options for a project.
# Usage: project_query_fields "project_id"
project_query_fields() {
  local project_id="$1"

  local query
  query='query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 100) {
          nodes {
            ... on ProjectV2Field {
              id
              name
              dataType
            }
            ... on ProjectV2SingleSelectField {
              id
              name
              dataType
              options {
                id
                name
              }
            }
          }
        }
      }
    }
  }'

  github_graphql "$query" -f projectId="$project_id"
}

# Create a custom single-select field.
# Usage: project_create_field "project_id" "field_name" "options_json"
# options_json is a JSON array: [{"name": "Low", "color": "BLUE"}, ...]
project_create_field() {
  local project_id="$1"
  local field_name="$2"
  local options_json="$3"

  local query
  query='mutation($projectId: ID!, $name: String!, $options: [ProjectV2SingleSelectFieldOptionInput!]) {
    createProjectV2Field(input: {
      projectId: $projectId
      name: $name
      dataType: SINGLE_SELECT
      singleSelectOptions: $options
    }) {
      projectV2Field {
        ... on ProjectV2SingleSelectField {
          id
          name
          options {
            id
            name
          }
        }
      }
    }
  }'

  # Build and pipe the complete payload to gh api graphql
  # This avoids temp files and is 100% cross-platform compatible
  jq -n \
    --arg query "$query" \
    --arg projectId "$project_id" \
    --arg name "$field_name" \
    --argjson options "$options_json" \
    '{query: $query, variables: {projectId: $projectId, name: $name, options: $options}}' | \
    gh api graphql -H "GraphQL-Features: sub_issues" --input - >/dev/null
}

# Delete a custom field.
# Usage: project_delete_field "field_id"
project_delete_field() {
  local field_id="$1"

  local query
  query='mutation($fieldId: ID!) {
    deleteProjectV2Field(input: { fieldId: $fieldId }) {
      clientMutationId
    }
  }'

  github_graphql "$query" -f fieldId="$field_id" >/dev/null
}

# Set up or retrieve a project.
# Usage: project_setup "owner" "repo" "project_name" "dry_run"
# Returns project ID on stdout.
project_setup() {
  local owner="$1"
  local repo="$2"
  local project_name="$3"
  local dry_run="${4:-false}"

  if [[ "$dry_run" == "true" ]]; then
    echo "dry_run_project_id"
    return 0
  fi

  # Query metadata
  local meta
  meta=$(project_query_meta "$owner" "$repo")

  local repo_id
  repo_id=$(echo "$meta" | jq -r '.data.repository.id')
  local owner_id
  owner_id=$(echo "$meta" | jq -r '.data.repository.owner.id')

  # Search for existing project
  local project_id
  project_id=$(echo "$meta" | jq -r --arg title "$project_name" '
    .data.repository.owner.projectsV2.nodes[] | select(.title == $title) | .id
  ' | head -n 1)

  if [[ -z "$project_id" || "$project_id" == "null" ]]; then
    echo "Creating Project V2: '$project_name'..." >&2
    local create_res
    create_res=$(project_create "$owner_id" "$repo_id" "$project_name")
    project_id=$(echo "$create_res" | jq -r '.data.createProjectV2.projectV2.id')
    echo "Created Project V2 with ID: $project_id" >&2
  else
    echo "Reusing existing Project V2: '$project_name' (ID: $project_id)" >&2
  fi

  echo "$project_id"
}

# Set up custom fields (Status, Priority, Size).
# Usage: project_setup_fields "project_id" "dry_run"
project_setup_fields() {
  local project_id="$1"
  local dry_run="${2:-false}"

  if [[ "$dry_run" == "true" ]]; then
    echo "Dry-run: Would configure fields Status, Priority, Size." >&2
    return 0
  fi

  echo "Configuring custom fields (Status, Priority, Size)..." >&2

  # Get current fields
  local fields_data
  fields_data=$(project_query_fields "$project_id")

  # Define required status, priority, and size options
  local status_options='[
    {"name": "Backlog", "color": "GRAY", "description": "Items in the backlog"},
    {"name": "Ready", "color": "BLUE", "description": "Items ready for development"},
    {"name": "In Progress", "color": "YELLOW", "description": "Items currently being worked on"},
    {"name": "Review", "color": "PURPLE", "description": "Items under peer or QA review"},
    {"name": "Done", "color": "GREEN", "description": "Completed items"}
  ]'

  local priority_options='[
    {"name": "Low", "color": "BLUE", "description": "Low priority item"},
    {"name": "Medium", "color": "YELLOW", "description": "Medium priority item"},
    {"name": "High", "color": "RED", "description": "High priority item"}
  ]'

  local size_options='[
    {"name": "XS", "color": "GRAY", "description": "Extra Small work estimate"},
    {"name": "S", "color": "GRAY", "description": "Small work estimate"},
    {"name": "M", "color": "BLUE", "description": "Medium work estimate"},
    {"name": "L", "color": "YELLOW", "description": "Large work estimate"},
    {"name": "XL", "color": "RED", "description": "Extra Large work estimate"}
  ]'

  # 1. Setup Status Field
  # Check if "Status" field exists and contains required options
  local status_field
  status_field=$(echo "$fields_data" | jq -c '.data.node.fields.nodes[] | select(.name == "Status")')

  if [[ -n "$status_field" ]]; then
    echo "✓ Found existing 'Status' field." >&2
    # Check if we have the backlog option
    local has_backlog
    has_backlog=$(echo "$status_field" | jq -r '.options[]? | select((.name | ascii_downcase) == "backlog") | .id')
    if [[ -z "$has_backlog" ]]; then
      echo "  - Existing status field lacks 'Backlog' option. Since built-in Status field cannot be updated easily," >&2
      echo "    we will check for 'Todo' or 'In progress' options to fall back on." >&2
    fi
  else
    # Status field doesn't exist? Create a custom one
    echo "Creating custom Status field..." >&2
    project_create_field "$project_id" "Status" "$status_options" >/dev/null
  fi

  # 2. Setup Priority Field
  local priority_field
  priority_field=$(echo "$fields_data" | jq -c '.data.node.fields.nodes[] | select(.name == "Priority")')
  local need_create_priority=true

  if [[ -n "$priority_field" ]]; then
    # Verify options contain Low, Medium, High
    local has_medium
    has_medium=$(echo "$priority_field" | jq -r '.options[]? | select(.name == "Medium") | .id')
    if [[ -n "$has_medium" ]]; then
      echo "✓ Found existing 'Priority' field with correct options." >&2
      need_create_priority=false
    else
      echo "Existing 'Priority' field has incorrect options (e.g. P0/P1). Deleting and recreating..." >&2
      local f_id
      f_id=$(echo "$priority_field" | jq -r '.id')
      project_delete_field "$f_id"
    fi
  fi

  if [[ "$need_create_priority" == "true" ]]; then
    echo "Creating 'Priority' field..." >&2
    project_create_field "$project_id" "Priority" "$priority_options" >/dev/null
  fi

  # 3. Setup Size Field
  local size_field
  size_field=$(echo "$fields_data" | jq -c '.data.node.fields.nodes[] | select(.name == "Size")')
  local need_create_size=true

  if [[ -n "$size_field" ]]; then
    local has_m
    has_m=$(echo "$size_field" | jq -r '.options[]? | select(.name == "M") | .id')
    if [[ -n "$has_m" ]]; then
      echo "✓ Found existing 'Size' field with correct options." >&2
      need_create_size=false
    else
      echo "Existing 'Size' field has incorrect options. Deleting and recreating..." >&2
      local f_id
      f_id=$(echo "$size_field" | jq -r '.id')
      project_delete_field "$f_id"
    fi
  fi

  if [[ "$need_create_size" == "true" ]]; then
    echo "Creating 'Size' field..." >&2
    project_create_field "$project_id" "Size" "$size_options" >/dev/null
  fi

  echo "✓ Custom fields setup complete." >&2
}

# Get a field ID by name from the fields JSON structure.
# Usage: project_get_field_id "$fields_json" "Priority"
project_get_field_id() {
  local fields_json="$1"
  local field_name="$2"

  echo "$fields_json" | jq -r --arg f_name "$field_name" '
    .data.node.fields.nodes[] |
    select(.name == $f_name) |
    .id
  ' | head -n 1
}

# Get a field option ID by name from the fields JSON structure.
# Usage: project_get_field_option_id "$fields_json" "Priority" "Medium"
project_get_field_option_id() {
  local fields_json="$1"
  local field_name="$2"
  local option_name="$3"

  # Perform case-insensitive search on option name
  echo "$fields_json" | jq -r --arg f_name "$field_name" --arg opt_name "$option_name" '
    .data.node.fields.nodes[] |
    select(.name == $f_name) |
    .options[]? |
    select((.name | ascii_downcase) == ($opt_name | ascii_downcase)) |
    .id
  ' | head -n 1
}

