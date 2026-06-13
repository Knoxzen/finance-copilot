# Troubleshooting Guide

This guide covers common issues, error messages, and solutions when working with the **GitHub Project Bootstrap Toolkit**.

---

## 1. GitHub CLI Authentication and Scopes

### Error: `ERROR: GitHub CLI lacks the 'project' scope required to manage Project V2.`
By default, standard `gh auth login` does not request the `project` scope, which is required to query, create, and modify Project V2 boards.

#### Solution:
Refresh your token scopes to explicitly grant access:
```bash
gh auth refresh -s project
```

### Error: `ERROR: GitHub CLI is not authenticated.`
Your local shell session is not authorized to interact with GitHub.

#### Solution:
Run the login flow and follow the browser instructions:
```bash
gh auth login
```

---

## 2. Dependency Errors

### Error: `yq: The term 'yq' is not recognized...` (Windows)
The shell cannot locate the `yq` executable on the system PATH.

#### Solution:
Install the package using your manager (e.g. winget, chocolatey) and restart your Git Bash window:
```bash
# Windows Winget
winget install mikefarah.yq

# macOS Homebrew
brew install yq
```

### Error: `WARNING: Ensure you are using Mike Farah's yq (v4+).`
There is another tool called `yq` (typically the python wrapper around `jq` or a v3 release of `yq`) which does not support the v4 `-o=json` format command syntax.

#### Solution:
Verify the version:
```bash
yq --version
```
Ensure it returns version `4.x`. If not, uninstall it and download the official prebuilt binary for Mike Farah's `yq` from the [GitHub releases page](https://github.com/mikefarah/yq/releases).

---

## 3. Git Bash on Windows Line Ending Issues

### Error: `\r: command not found` or similar syntax syntax errors.
Windows uses CRLF (`\r\n`) line endings, while Bash scripts require LF (`\n`). If git checked out the files with CRLF on Windows, Git Bash will fail to execute them.

#### Solution:
Configure git to use LF endings for shell files, or convert the scripts using `dos2unix`:
```bash
# Install dos2unix if missing, or run via git bash
dos2unix bootstrap.sh lib/*.sh create-*.sh
```
Or force Git to checkout LF endings by adding a `.gitattributes` file:
```text
*.sh text eol=lf
```

---

## 4. GraphQL API Issues

### Error: `Expected type 'number', but it was malformed`
This usually happens when passing command arguments in PowerShell. Shell escaping strips quotes, turning strings into cmdlet arguments.

#### Solution:
Run the scripts inside **Git Bash** rather than PowerShell. The scripts are optimized specifically for Git Bash and Linux standard environments.

### Error: `Could not resolve to a node with the global id of '...'`
This happens when you attempt to add issues or modify projects across different accounts or repositories that have restricted visibility or policies.

#### Solution:
Ensure the personal access token (PAT) you are using has access to both the repository and the user account (`Knoxzen`). You can verify repository access by running:
```bash
gh repo view Knoxzen/finance-copilot
```
If you get a permission error, make sure your token is not expired and has standard `repo` scope.
