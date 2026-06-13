#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Library for managing GitHub Issues and linking them to Project V2.
# Implements idempotency, Epic/Task creation, parent linking, and field value updates.

# Find an existing issue by title.
# Usage: issue_find "owner" "repo" "title"
# Returns issue JSON: {"number": 12, "id": "I_kwD...", "title": "..."} or empty.
issue_find() {
  local owner="$1"
  local repo="$2"
  local title="$3"

  gh issue list \
    --repo "$owner/$repo" \
    --search "\"$title\"" \
    --state all \
    --json number,id,title \
    --jq ".[] | select(.title == \"$title\")" | head -n 1
}

# Create an Epic issue.
# Usage: issue_create_epic "owner" "repo" "title" "body" "labels_comma" "milestone" "dry_run"
# Returns issue JSON with number and id.
issue_create_epic() {
  local owner="$1"
  local repo="$2"
  local title="$3"
  local body="$4"
  local labels="${5:-}"
  local milestone="${6:-}"
  local dry_run="${7:-false}"

  # Add [EPIC] prefix if not present
  if [[ ! "$title" =~ ^\[EPIC\] ]]; then
    title="[EPIC] $title"
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo "Dry-run: Would create Epic: '$title'" >&2
    echo '{"number": 999, "id": "dry_run_epic_id"}'
    return 0
  fi

  # Idempotency check
  local existing
  existing=$(issue_find "$owner" "$repo" "$title")
  if [[ -n "$existing" ]]; then
    echo "✓ Epic already exists: '$title' (#$(echo "$existing" | jq -r '.number'))" >&2
    echo "$existing"
    return 0
  fi

  echo "Creating Epic: '$title'..." >&2

  # Prepare options
  local opts=(--title "$title" --body "$body")
  if [[ -n "$labels" ]]; then
    opts+=(--label "$labels")
  fi
  if [[ -n "$milestone" ]]; then
    opts+=(--milestone "$milestone")
  fi

  local url
  url=$(gh issue create --repo "$owner/$repo" "${opts[@]}")
  local num
  num=$(echo "$url" | grep -oE '[0-9]+$')

  # Retrieve details of the newly created issue
  local new_issue
  new_issue=$(gh issue view "$num" --repo "$owner/$repo" --json number,id,title)
  echo "Created Epic #$num" >&2
  echo "$new_issue"
}

# Create a Task issue linked to an Epic.
# Usage: issue_create_task "owner" "repo" "title" "body" "labels_comma" "milestone" "epic_num" "epic_id" "dry_run"
# Returns issue JSON.
issue_create_task() {
  local owner="$1"
  local repo="$2"
  local title="$3"
  local body="$4"
  local labels="${5:-}"
  local milestone="${6:-}"
  local epic_num="${7:-}"
  local epic_id="${8:-}"
  local dry_run="${9:-false}"

  if [[ "$dry_run" == "true" ]]; then
    echo "Dry-run: Would create Task: '$title' (Parent Epic: #$epic_num)" >&2
    echo '{"number": 888, "id": "dry_run_task_id"}'
    return 0
  fi

  # Idempotency check
  local existing
  existing=$(issue_find "$owner" "$repo" "$title")
  if [[ -n "$existing" ]]; then
    # Verify if it is already linked or needs linking
    echo "✓ Task already exists: '$title' (#$(echo "$existing" | jq -r '.number'))" >&2
    
    # Link if not already linked (if parent is missing and epic is provided)
    if [[ -n "$epic_id" ]]; then
      local current_parent
      current_parent=$(gh issue view "$(echo "$existing" | jq -r '.number')" --repo "$owner/$repo" --json parent --jq '.parent.id // empty')
      if [[ -z "$current_parent" ]]; then
        echo "Linking task #$(echo "$existing" | jq -r '.number') to Epic #$epic_num..." >&2
        issue_link_subissue "$epic_id" "$(echo "$existing" | jq -r '.id')"
      fi
    fi
    echo "$existing"
    return 0
  fi

  echo "Creating Task: '$title'..." >&2

  # Prepare options
  local opts=(--title "$title" --body "$body")
  if [[ -n "$labels" ]]; then
    opts+=(--label "$labels")
  fi
  if [[ -n "$milestone" ]]; then
    opts+=(--milestone "$milestone")
  fi
  if [[ -n "$epic_num" ]]; then
    opts+=(--parent "$epic_num")
  fi

  local url
  url=$(gh issue create --repo "$owner/$repo" "${opts[@]}")
  local num
  num=$(echo "$url" | grep -oE '[0-9]+$')

  local new_issue
  new_issue=$(gh issue view "$num" --repo "$owner/$repo" --json number,id,title)
  echo "Created Task #$num" >&2
  echo "$new_issue"
}

# Link a sub-issue to a parent issue via GraphQL.
# Usage: issue_link_subissue "parent_node_id" "child_node_id"
issue_link_subissue() {
  local parent_id="$1"
  local child_id="$2"

  local query
  query='mutation($parentId: ID!, $subIssueId: ID!) {
    addSubIssue(input: { issueId: $parentId, subIssueId: $subIssueId }) {
      issue {
        number
      }
    }
  }'

  github_graphql "$query" -f parentId="$parent_id" -f subIssueId="$child_id" >/dev/null
}

# Add an issue to a Project V2.
# Usage: issue_add_to_project "project_id" "issue_node_id" "dry_run"
# Returns Project Item ID on stdout.
issue_add_to_project() {
  local project_id="$1"
  local issue_id="$2"
  local dry_run="${3:-false}"

  if [[ "$dry_run" == "true" ]]; then
    echo "dry_run_item_id"
    return 0
  fi

  local query
  query='mutation($projectId: ID!, $contentId: ID!) {
    addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
      item {
        id
      }
    }
  }'

  local res
  res=$(github_graphql "$query" -f projectId="$project_id" -f contentId="$issue_id")
  echo "$res" | jq -r '.data.addProjectV2ItemById.item.id'
}

# Update a custom Single Select field on a Project V2 item.
# Usage: issue_set_project_field "project_id" "item_id" "field_id" "option_id" "dry_run"
issue_set_project_field() {
  local project_id="$1"
  local item_id="$2"
  local field_id="$3"
  local option_id="$4"
  local dry_run="${5:-false}"

  if [[ "$dry_run" == "true" ]]; then
    return 0
  fi

  if [[ -z "$field_id" || -z "$option_id" ]]; then
    return 0 # Skip if field or option is not found
  fi

  local query
  query='mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { singleSelectOptionId: $optionId }
    }) {
      projectV2Item {
        id
      }
    }
  }'

  github_graphql "$query" \
    -f projectId="$project_id" \
    -f itemId="$item_id" \
    -f fieldId="$field_id" \
    -f optionId="$option_id" >/dev/null
}
