#!/usr/bin/env bash

set -euo pipefail

############################################
# CONFIG
############################################

OWNER="${1:-}"
REPO="${2:-}"

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Usage:"
  echo "./bootstrap-github-project.sh <owner> <repo>"
  echo
  echo "Example:"
  echo "./bootstrap-github-project.sh kundan finance-copilot"
  exit 1
fi

############################################
# VALIDATION
############################################

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI (gh) not found."
  echo "Install: winget install GitHub.cli"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: GitHub CLI not authenticated."
  echo "Run: gh auth login"
  exit 1
fi

echo "Checking repository access..."

gh repo view "$OWNER/$REPO" >/dev/null

echo "Connected to $OWNER/$REPO"
echo

############################################
# LABELS
############################################

create_label() {
  local name="$1"
  local color="$2"
  local desc="$3"

  gh label create "$name" \
    --repo "$OWNER/$REPO" \
    --color "$color" \
    --description "$desc" \
    2>/dev/null || true
}

echo "Creating labels..."

create_label backend "1D76DB" "Backend development"
create_label frontend "5319E7" "Frontend development"
create_label database "0E8A16" "Database related work"
create_label security "B60205" "Security work"
create_label devops "FBCA04" "Infrastructure and CI/CD"
create_label ai "C5DEF5" "AI features"
create_label documentation "0075CA" "Documentation"
create_label bug "D73A4A" "Bug"
create_label enhancement "A2EEEF" "Enhancement"
create_label testing "F9D0C4" "Testing"

create_label high-priority "D93F0B" "High priority"
create_label medium-priority "FBCA04" "Medium priority"
create_label low-priority "0E8A16" "Low priority"

echo "Labels complete."
echo

############################################
# MILESTONES
############################################

create_milestone() {
  local title="$1"

  gh api \
    repos/$OWNER/$REPO/milestones \
    -f title="$title" \
    >/dev/null 2>&1 || true
}

echo "Creating milestones..."

create_milestone "v0.1 Authentication Service"
create_milestone "v0.2 API Gateway"
create_milestone "v0.3 Transactions"
create_milestone "v0.4 Analytics"
create_milestone "v0.5 AI Features"
create_milestone "v1.0 Production Release"

echo "Milestones complete."
echo

############################################
# ISSUE CREATOR
############################################

create_issue() {

  local title="$1"
  local labels="$2"
  local body="$3"

  local url

  url=$(gh issue create \
    --repo "$OWNER/$REPO" \
    --title "$title" \
    --label "$labels" \
    --body "$body")

  echo "$url" | grep -oE '[0-9]+$'
}

############################################
# EPICS
############################################

echo "Creating epics..."

USER_EPIC=$(create_issue \
"[EPIC] USER SERVICE" \
"enhancement" \
"Authentication and User Management Service")

API_GATEWAY_EPIC=$(create_issue \
"[EPIC] API GATEWAY" \
"enhancement" \
"Future Epic")

TRANSACTION_EPIC=$(create_issue \
"[EPIC] TRANSACTION SERVICE" \
"enhancement" \
"Future Epic")

ANALYTICS_EPIC=$(create_issue \
"[EPIC] ANALYTICS SERVICE" \
"enhancement" \
"Future Epic")

AI_EPIC=$(create_issue \
"[EPIC] AI SERVICE" \
"enhancement" \
"Future Epic")

OBSERVABILITY_EPIC=$(create_issue \
"[EPIC] OBSERVABILITY" \
"enhancement" \
"Future Epic")

DEPLOYMENT_EPIC=$(create_issue \
"[EPIC] DEPLOYMENT" \
"enhancement" \
"Future Epic")

echo "Epics complete."
echo

############################################
# TASKS
############################################

create_task() {

  local title="$1"
  local labels="$2"

  gh issue create \
    --repo "$OWNER/$REPO" \
    --title "$title" \
    --label "$labels" \
    --body "Part of User Service Epic"
}

echo "Creating User Service tasks..."

create_task "Create Spring Boot Project" "backend"
create_task "Setup PostgreSQL" "database"
create_task "Setup Docker Compose" "devops"
create_task "Setup Flyway" "database"

create_task "Design User Entity" "backend"
create_task "Design Refresh Token Entity" "backend,security"

create_task "Implement Register API" "backend"
create_task "Implement Login API" "backend,security"

create_task "Implement JWT Service" "security"

create_task "Implement Refresh Token Flow" "security"

create_task "Implement Logout API" "security"

create_task "Swagger Documentation" "documentation"

create_task "Unit Tests" "testing"

create_task "Integration Tests" "testing"

create_task "GitHub Actions CI" "devops"

echo
echo "================================="
echo "BOOTSTRAP COMPLETE"
echo "================================="
echo
echo "Repository : $OWNER/$REPO"
echo "User Epic  : #$USER_EPIC"
echo
echo "Open:"
echo "https://github.com/$OWNER/$REPO/issues"