# Env Doctor Quickstart Guide

Get up and running with Env Doctor in under 60 seconds.

## 1. Run Your First Audit

To run a read-only environment discovery pass on your current repository:

```bash
bash env-doctor.sh
```

By default, this runs a fast, read-only audit of your shell, OS, installed developer tools, credentials, and configuration files.

If your project uses git submodules and you want to scan their initialization status and check for private repository access:

```bash
bash env-doctor.sh --with-submodules
```

## 2. Customize for Your Project

To tailor the checks to your project's specific requirements (such as required Python dependencies, core submodules, or a custom help URL):

1. Generate a configuration template:
   ```bash
   bash env-doctor.sh --print-config-template > .env-doctor.conf
   ```

2. Open `.env-doctor.conf` and uncomment/edit the variables:
   ```bash
   BRAND="My Project Name"
   ENV_DOCTOR_CORE_REPOS="shared-types|api-client"
   ENV_DOCTOR_PYTHON_DEPS="yaml,click,pydantic,requests"
   ENV_DOCTOR_HELP_URL="https://wiki.myproject.internal/setup"
   ```

3. Run the audit again. Your custom brand banner and checks will be applied immediately.

## 3. Auto-Heal Your Environment

If Env Doctor detects missing virtual environments or uninstalled Python dependencies, you can progressively initialize the environment using the progressive init engine:

- **Dry-run (preview what changes will be made)**:
  ```bash
  bash env-doctor.sh --init --tier 1 --dry-run
  ```

- **Execute progressive initialization (requires explicit consent)**:
  ```bash
  bash env-doctor.sh --init --tier 1 --yes
  ```

## 4. Align Your AI Coding Agents

AI coding agents (such as Cursor, Claude Code, or Copilot) can get stuck in infinite loops when local environments are broken. Give them auto-healing capabilities:

1. Generate the agent protocol template:
   ```bash
   bash env-doctor.sh --print-agent-template > AGENTS.md
   ```

2. When your AI agent starts, it will read `AGENTS.md` and automatically run `env-doctor.sh` to self-diagnose and resolve environment issues instead of guessing or failing.

## 5. Integrate with Git Hooks and CI/CD

Check the `templates/` directory for ready-to-use integration configurations:
- **Git Hooks**: Copy `templates/pre-commit-config.yaml` to your `.pre-commit-config.yaml` to run fast environment smoke checks before every commit.
- **CI/CD**: Add `templates/github-actions-env-doctor.yml` to your GitHub Actions workflows to verify build runner environments automatically.
