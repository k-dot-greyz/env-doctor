# Env Doctor Safety and Privacy Model

Env Doctor is designed with a "local-first, zero-trust" architecture. We believe that developer utility tools should never compromise your system security or leak sensitive credentials.

This document outlines the safety boundaries, credential redaction rules, and execution models of the tool.

## 1. Local-First Execution Boundary

- **Zero Telemetry**: Env Doctor does not contain any tracking codes, analytics engines, or telemetry reporting. It never phones home.
- **No Network Activity by Default**: All core audits (OS, shell, local tools, virtual environments, configuration files, and credentials) run entirely offline.
- **Controlled Network Operations**: Network calls are only made when explicitly requested (e.g., checking if a private submodule URL is accessible over SSH or HTTPS). These calls are wrapped in strict timeouts to prevent hangs.

## 2. Strong Credential Redaction Rules

Env Doctor scans your `.env` files and Git configurations to ensure they are set up correctly, but it *never* prints or logs raw credentials. All sensitive values are redacted at the boundary before output:

- **Git URLs**: Any username, password, or token embedded in a git remote or submodule URL is automatically redacted.
  - *Input*: `https://ghp_mysecrettoken@github.com/org/repo.git`
  - *Output*: `https://<REDACTED_CREDS>@github.com/org/repo.git`
- **GitHub Personal Access Tokens**: Detects and redacts standard `ghp_` tokens.
- **GitLab Personal Access Tokens**: Detects and redacts standard `glpat-` tokens.
- **Generic Tokens**: Redacts any user/password combinations in URLs.

## 3. Safe Configuration Loading

To prevent arbitrary code execution, Env Doctor does not source `.env-doctor.conf` directly by default. Instead, it uses a custom, injection-proof key-value parser (`_load_config`):

- **Allowlisted Keys**: Only parses explicitly allowed keys (`BRAND`, `ENV_DOCTOR_CORE_REPOS`, `ENV_DOCTOR_PYTHON_DEPS`, `ENV_DOCTOR_HELP_URL`).
- **Strict Charsets**: Validates each value against safe character patterns. Any value containing unsafe shell characters (such as `;`, `&`, `` ` ``, `$`, `(`, `)`, `<`, `>`, `|`) is skipped and a warning is logged.
- **Legacy Opt-In**: Sourcing the configuration file directly is only possible if you pass the explicit `--unsafe-source-config` flag.

## 4. Mutation Safety & Explicit Consent

Env Doctor is read-only by default. It will never modify your filesystem, install packages, or change shell configurations unless you explicitly ask it to:

- **Progressive Init**: System modifications are isolated to the `--init` / `-i` flag.
- **Explicit Consent**: Package installations or environment creations require the `--yes` / `-y` flag or interactive user confirmation.
- **Dry-Run Preview**: You can preview all proposed initialization changes without executing them by appending the `--dry-run` / `-n` flag:
  ```bash
  bash env-doctor.sh --init --tier 1 --dry-run
  ```

## 5. Injection-Proof Outputs

When generating JSON outputs for CI/CD pipelines or AI agents, Env Doctor uses a robust, escaping-safe JSON line generator (`_jline` and `_escape_json_string`). This ensures that control characters, quotes, and backslashes in tool outputs cannot break the JSON structure or lead to downstream parsing vulnerabilities.
