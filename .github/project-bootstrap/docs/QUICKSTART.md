# Quickstart Guide

This guide will help you install the prerequisites and use the **GitHub Project Bootstrap Toolkit** to set up and manage your repository roadmap.

---

## Prerequisites

The toolkit relies on three CLI dependencies:
1. **GitHub CLI (`gh`)** - For authenticating and interacting with GitHub API.
2. **`jq`** - Command-line JSON processor.
3. **`yq` (Mike Farah's Go version)** - Command-line YAML processor.

### Installing Dependencies

#### 1. Windows (Git Bash / PowerShell)
If you are on Windows, you can install the dependencies via **winget** or **chocolatey**:
```bash
# Install GitHub CLI
winget install GitHub.cli

# Install jq
winget install jqlang.jq

# Install Mike Farah's yq
winget install mikefarah.yq
```

#### 2. macOS
```bash
# Install all using Homebrew
brew install gh jq yq
```

#### 3. Linux (Ubuntu/Debian)
```bash
# Install gh CLI
type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Install jq & yq
sudo apt install jq -y
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
```

---

## GitHub Authentication & Scopes

Make sure the GitHub CLI is authenticated and refreshed with the **`project`** scope (which is required to manage Projects V2).

```bash
# Login to GitHub (if not already logged in)
gh auth login

# Refresh scopes to include 'project' permissions
gh auth refresh -s project
```

---

## Usage

Navigate to the project bootstrap toolkit folder:
```bash
cd .github/project-bootstrap/
```

### 1. Perform a Dry Run
Verify your configurations, environment, and CLI auth without making any changes to GitHub:
```bash
./bootstrap.sh --dry-run
```

### 2. Full Bootstrap
Run the full bootstrap sequence to create labels, milestones, project, epics, and tasks:
```bash
./bootstrap.sh
# OR
./bootstrap.sh all
```

### 3. Modulating Steps
If you only want to perform specific steps:
```bash
# Create labels only
./bootstrap.sh labels

# Create milestones only
./bootstrap.sh milestones

# Create Project V2 board only
./bootstrap.sh project

# Create epics only
./bootstrap.sh epics

# Create tasks only
./bootstrap.sh tasks
```

### 4. Create an Epic from a YAML file
Create a custom Epic from a separate YAML configuration:
```bash
./create-epic.sh examples/payment-service.yaml
```

### 5. Create Tasks under an Epic from a YAML file
Create task issues linked as sub-issues to an existing Epic:
```bash
./create-tasks.sh examples/payment-service.yaml
```
