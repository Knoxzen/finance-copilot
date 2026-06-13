# GitHub Project Bootstrap Toolkit

A modular, configuration-driven toolkit to automate the creation and synchronization of GitHub Project boards, labels, milestones, issues, and parent-child issue relationships (Epics & Tasks). 

This toolkit allows you to bootstrap and run your agile roadmap entirely from standard YAML configuration files.

---

## Folder Structure

```text
.github/project-bootstrap/
├── bootstrap.sh                 # Main entrypoint executable
├── create-epic.sh               # Individual Epic creator
├── create-tasks.sh              # Individual Task creator
├── lib/                         # Shell script libraries
│   ├── github.sh                # Environment and CLI checks
│   ├── issue.sh                 # Epics, Tasks, and Project items
│   ├── project.sh               # Project V2 and custom fields configuration
│   └── yaml.sh                  # YAML parsing wrapper using yq & jq
├── config/                      # Declarative configuration files
│   ├── config.yaml              # Repository and project details
│   ├── labels.yaml              # GitHub Label setup
│   ├── milestones.yaml          # Delivery milestones
│   └── roadmap.yaml             # Product epics and task backlog
├── examples/                    # Sample Epic configuration files
└── docs/                        # Complete documentation
    ├── QUICKSTART.md            # Installation and usage instructions
    ├── ARCHITECTURE.md          # Internal mechanics & system design
    └── TROUBLESHOOTING.md       # Troubleshooting common errors
```

---

## Quick Command Guide

| Action | Command | Description |
| :--- | :--- | :--- |
| **Validate / Dry Run** | `./bootstrap.sh --dry-run` | Validates your system configuration and shows proposed changes. |
| **Full Bootstrap** | `./bootstrap.sh` | Runs the full sequence: labels, milestones, projects, epics, tasks. |
| **Create Labels Only** | `./bootstrap.sh labels` | Synchronizes repository labels. |
| **Create Milestones Only** | `./bootstrap.sh milestones` | Synchronizes delivery milestones. |
| **Create Project Only** | `./bootstrap.sh project` | Generates a Project V2 board and custom fields. |
| **Create Epics Only** | `./bootstrap.sh epics` | Synchronizes Epic issues. |
| **Create Tasks Only** | `./bootstrap.sh tasks` | Creates task issues and links them as sub-issues to Epics. |
| **Create Epic from File** | `./create-epic.sh examples/payment-service.yaml` | Creates an Epic issue from an external file. |
| **Create Tasks from File** | `./create-tasks.sh examples/payment-service.yaml` | Creates tasks under a parent Epic from an external file. |

---

## Getting Started

To get your environment set up and run the toolkit, please follow the step-by-step instructions in the [Quickstart Guide](file:///c:/IMKDX/Projects/finance-copilot/.github/project-bootstrap/docs/QUICKSTART.md).

For deep technical details about the GraphQL mutations, sub-issue mechanisms, and API flows, refer to the [Architecture Manual](file:///c:/IMKDX/Projects/finance-copilot/.github/project-bootstrap/docs/ARCHITECTURE.md).

If you run into issues with CLI scopes, authentication, or tool dependencies, consult the [Troubleshooting Manual](file:///c:/IMKDX/Projects/finance-copilot/.github/project-bootstrap/docs/TROUBLESHOOTING.md).
