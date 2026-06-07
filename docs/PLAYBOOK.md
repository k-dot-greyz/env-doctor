# env-doctor Integration Playbook
## The Ultimate Guide to Automated Environment Auditing, Team Onboarding, and AI-Agent Alignment

Local environment drift is one of the single largest sinks of engineering time. Developers spend hours debugging broken dependencies, outdated submodules, missing CLI tools, and misconfigured credentials.

`env-doctor` solves this by providing a single-file, zero-dependency, enterprise-hardened environment discovery and progressive initialization engine. This playbook provides battle-tested integration patterns to embed `env-doctor` into your team's daily workflows, CI/CD pipelines, Git hooks, and AI-agent environments.

---

## Table of Contents
1. [Team Onboarding Playbook](#1-team-onboarding-playbook)
2. [Git Hooks Integration](#2-git-hooks-integration)
3. [CI/CD Pipeline Integration](#3-cicd-pipeline-integration)
4. [AI Coding Agent Alignment](#4-ai-coding-agent-alignment)
5. [Writing Custom Checks](#5-writing-custom-checks)
6. [Enterprise Configuration Reference](#6-enterprise-configuration-reference)

---

## 1. Team Onboarding Playbook

When a new developer joins your team or pulls a major update, they shouldn't have to follow a 20-step wiki page to set up their environment. `env-doctor` reduces onboarding to a single command.

### The "One-Command Onboarding" Pattern

Add a simple `bootstrap` script or `Makefile` target to your repository root that drives `env-doctor` progressively.

#### Option A: `Makefile`
Add the following to your `Makefile`:

```makefile
.PHONY: doctor setup

# Run read-only environment audit
doctor:
	@bash env-doctor.sh --with-submodules

# Progressively initialize the environment (Tier 2: venv, core deps, submodules, dev tools)
setup:
	@echo "Running progressive environment initialization..."
	@bash env-doctor.sh --init --tier 2 --yes
```

#### Option B: `package.json` (Node.js Projects)
Add the following scripts to your `package.json`:

```json
"scripts": {
  "doctor": "bash env-doctor.sh --with-submodules",
  "setup": "bash env-doctor.sh --init --tier 2 --yes"
}
```

#### Option C: `pyproject.toml` (Python Projects with Poetry/Taskfile)
If you use `taskipy` or a task runner:

```toml
[tool.taskipy.tasks]
doctor = "bash env-doctor.sh --with-submodules"
setup = "bash env-doctor.sh --init --tier 2 --yes"
```

---

## 2. Git Hooks Integration

Catch environment drift before it affects development. By integrating `env-doctor` into Git hooks, you can ensure that developers are alerted to missing tools, dirty trees, or uninitialized submodules during key Git events.

### Pattern A: `pre-commit` framework
If your repository uses the popular `pre-commit` framework, add `env-doctor` as a local repository hook in your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: env-doctor
        name: env-doctor environment check
        entry: bash env-doctor.sh
        language: system
        pass_filenames: false
        always_run: true
        stages: [pre-commit]
```

### Pattern B: Native Git `post-checkout` Hook
Submodules frequently drift when developers switch branches. A native `post-checkout` hook can automatically run `env-doctor` to verify submodules and virtual environments after every branch switch.

Create or edit `.git/hooks/post-checkout`:

```bash
#!/usr/bin/env bash
# .git/hooks/post-checkout

set -euo pipefail

# Only run on branch checkouts (not file checkouts)
if [[ "${3}" == "1" ]]; then
  echo "🔄 Branch checkout detected. Auditing environment..." >&2
  # Run in quiet mode, only outputting if issues are found
  if ! bash env-doctor.sh --quiet; then
    echo "⚠️  Environment issues detected! Running full audit:" >&2
    bash env-doctor.sh --with-submodules
    echo "💡 Run 'bash env-doctor.sh --init' to automatically resolve these issues." >&2
  fi
fi
```
Make the hook executable: `chmod +x .git/hooks/post-checkout`.

---

## 3. CI/CD Pipeline Integration

Ensure that your build agents are perfectly configured before running heavy test suites. Running `env-doctor` with the `--json` flag allows you to parse the environment state programmatically and fail the build with clear, structured logs if the runner is missing critical tools.

### Pattern A: GitHub Actions
Run `env-doctor` as a diagnostic step at the beginning of your workflow.

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          submodules: recursive # or let env-doctor handle it

      - name: Audit Runner Environment
        id: env-audit
        run: |
          # Run env-doctor and output JSON to a file
          bash env-doctor.sh --json > env_report.json
          cat env_report.json

          # Parse status using jq
          OK=$(jq '.ok' env_report.json)
          if [ "$OK" != "true" ]; then
            echo "❌ Runner environment is misconfigured!"
            jq '.results[] | select(.type=="fail")' env_report.json
            exit 1
          fi
```

### Pattern B: GitLab CI/CD
```yaml
stages:
  - audit
  - test

environment_audit:
  stage: audit
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y jq git
  script:
    - bash env-doctor.sh --json > env_report.json
    - cat env_report.json
    - |
      if [ "$(jq '.ok' env_report.json)" != "true" ]; then
        echo "Environment check failed!"
        jq '.results[] | select(.type=="fail")' env_report.json
        exit 1
      fi
  artifacts:
    paths:
      - env_report.json
    expire_in: 1 week
```

---

## 4. AI Coding Agent Alignment

AI Coding Agents (such as Cursor, Claude Code, or GitHub Copilot Workspace) are highly capable but can easily get stuck if the local environment is broken (e.g., a missing virtual environment, uninstalled dependencies, or uninitialized submodules).

By placing `env-doctor` in your repository and referencing it in your agent instructions, you give AI agents an **auto-healing capability**.

### System Prompt / `.cursorrules` / `AGENTS.md` Integration

Add the following block to your repository's AI instructions (e.g., `AGENTS.md` or `.cursorrules`):

```markdown
## 🩺 Environment Auto-Healing Protocol

If you encounter import errors, missing command errors, or test collection failures:
1. **Never guess** the state of the machine or try to manually install global packages.
2. Run the environment doctor in read-only mode first:
   ```bash
   bash env-doctor.sh --json
   ```
3. If issues are found, run the progressive initializer to auto-heal the environment:
   ```bash
   bash env-doctor.sh --init --tier 1 --yes
   ```
4. Re-run your command. This prevents environment-related loops and saves token context.
```

When an agent reads this, it will immediately run `env-doctor` to diagnose and fix its own environment when a build or test fails, preventing infinite loops and wasted API costs.

---

## 5. Writing Custom Checks

Because `env-doctor` is written in pure Bash and follows the **GW-AAP** architecture, it is incredibly easy to extend with custom checks specific to your company's stack (e.g., checking for a local PostgreSQL database, verifying AWS credentials, or checking an internal API endpoint).

### Anatomy of a Check

All checks in `env-doctor` use four decoupled output emitters:
* `_pass "Key" "Value"`: Registers a successful check.
* `_warn "Key" "Value"`: Registers a warning (does not fail the script).
* `_fail "Key" "Value"`: Registers a failure (increments `ISSUES` and exits 1 at the end).
* `_info "Key" "Value"`: Emits informational logs (omitted from issue counts).

### Example: Adding a PostgreSQL Connectivity Check

To add a custom check that verifies a local PostgreSQL database is running and reachable, add this function to `env-doctor.sh` and call it in `phase4_creds`:

```bash
_check_postgres() {
  _info "Database" "checking PostgreSQL connectivity..."

  if ! command -v pg_isready &>/dev/null; then
    _warn "PostgreSQL" "pg_isready CLI not found — skipping connection check"
    return
  fi

  # Read PGHOST/PGPORT with safe defaults
  local host="${PGHOST:-localhost}"
  local port="${PGPORT:-5432}"

  if _timeout_cmd 3 pg_isready -h "$host" -p "$port" &>/dev/null; then
    _pass "PostgreSQL" "connected to ${host}:${port}"
  else
    _fail "PostgreSQL" "database offline at ${host}:${port} (start Postgres)"
  fi
}
```

---

## 6. Enterprise Configuration Reference

Customize `env-doctor` without touching the core script. Copy `.env-doctor.conf.example` to `.env-doctor.conf` and configure the following variables:

### `BRAND`
* **Type**: String (alphanumeric, spaces, hyphens, underscores, dots)
* **Default**: Script filename (`env-doctor.sh`)
* **Purpose**: Sets the custom banner title displayed at the top of the output.
* **Example**: `BRAND="Acme Core Platform"`

### `ENV_DOCTOR_CORE_REPOS`
* **Type**: Regular Expression (sanitized at boundary)
* **Default**: Empty
* **Purpose**: A regular expression matching path suffixes of submodules that are considered "core" and should be initialized in Tier 1.
* **Example**: `ENV_DOCTOR_CORE_REPOS="shared-types|api-client"`

### `ENV_DOCTOR_PYTHON_DEPS`
* **Type**: Comma-separated list of package names (alphanumeric, underscores, hyphens, commas)
* **Default**: Empty
* **Purpose**: Python packages to verify (by trying to import them) when a Python project is detected.
* **Example**: `ENV_DOCTOR_PYTHON_DEPS="yaml,click,pydantic,requests,pytest"`

### `ENV_DOCTOR_HELP_URL`
* **Type**: HTTP/HTTPS URL
* **Default**: Empty
* **Purpose**: Custom URL printed next to private submodule warnings to guide developers on how to set up access (e.g., SSH keys, tokens).
* **Example**: `ENV_DOCTOR_HELP_URL="https://wiki.acme.internal/dev-setup/ssh"`
