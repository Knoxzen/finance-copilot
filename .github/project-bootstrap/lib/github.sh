#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Helper library for GitHub API operations and tool validation.

# Validate dependencies and authentication tools.
# Usage: github_validate_tools
github_validate_tools() {
  echo "=== Running Dependency & Auth Validation ==="

  # 1. Check gh installed
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI (gh) is not installed." >&2
    echo "Please install it: winget install GitHub.cli (Windows) or brew install gh (macOS/Linux)" >&2
    exit 1
  fi
  echo "✓ GitHub CLI (gh) is installed."

  # 2. Check jq installed
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is not installed." >&2
    echo "Please install it: winget install jqlang.jq (Windows) or apt/brew install jq" >&2
    exit 1
  fi
  echo "✓ jq is installed."

  # 3. Check yq installed
  if ! command -v yq >/dev/null 2>&1; then
    echo "ERROR: yq is not installed." >&2
    echo "Please install Mike Farah's yq: winget install mikefarah.yq (Windows) or brew install yq" >&2
    exit 1
  fi
  # Verify it is Mike Farah's yq by checking version
  local yq_ver
  yq_ver=$(yq --version 2>&1 || true)
  if [[ ! "$yq_ver" =~ "mikefarah" && ! "$yq_ver" =~ "version 4." && ! "$yq_ver" =~ "version v4." ]]; then
    echo "WARNING: yq version check returned: $yq_ver" >&2
    echo "Ensure you are using Mike Farah's yq (v4+)." >&2
  fi
  echo "✓ yq is installed ($yq_ver)."

  # 4. Check gh authenticated
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI is not authenticated." >&2
    echo "Please run: gh auth login" >&2
    exit 1
  fi
  echo "✓ GitHub CLI is authenticated."

  # 5. Check Project scope
  local scopes
  scopes=$(gh auth status 2>&1 | grep "Token scopes:" || true)
  if [[ ! "$scopes" =~ "project" ]]; then
    echo "ERROR: GitHub CLI lacks the 'project' scope required to manage Project V2." >&2
    echo "Please refresh auth with project scope:" >&2
    echo "    gh auth refresh -s project" >&2
    exit 1
  fi
  echo "✓ GitHub CLI has 'project' scope."
  echo "=== Tool Validation Successful ==="
  echo
}

# Check access to the target repository.
# Usage: github_validate_repo "owner" "repo"
github_validate_repo() {
  local owner="${1:-}"
  local repo="${2:-}"

  if [[ -z "$owner" || -z "$repo" ]]; then
    echo "ERROR: github_validate_repo requires owner and repo arguments" >&2
    exit 1
  fi

  echo "Checking access to repository: $owner/$repo..."
  if ! gh repo view "$owner/$repo" >/dev/null 2>&1; then
    echo "ERROR: Repository $owner/$repo does not exist or you do not have access." >&2
    exit 1
  fi
  echo "✓ Repository exists and is accessible."
  echo
}

# Run a GraphQL query using gh api.
# Includes the "GraphQL-Features: sub_issues" header by default.
# Usage: github_graphql "query" [variables...]
github_graphql() {
  local query="$1"
  shift
  gh api graphql \
    -H "GraphQL-Features: sub_issues" \
    -f query="$query" \
    "$@"
}
