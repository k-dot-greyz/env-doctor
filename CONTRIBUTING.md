# Contributing to env-doctor

Welcome to the `env-doctor` repository! We are excited to have you contribute.

`env-doctor` is a **single-file Bash CLI** (`env-doctor.sh`) for environment discovery and optional progressive init. It has zero extra dependencies on the read-only pass. To keep it portable across generic repositories, all contributions must respect repository boundaries and the architectural protocols below.

## Repository Layout

| Path | Purpose |
|------|---------|
| `env-doctor.sh` | Canonical script — all runtime logic lives here |
| `docs/README.md` | Flags, config variables, quickstart |
| `docs/ARCHITECTURE.md` | Phases, JSON envelope, extension points |
| `docs/UX_AUDIT.md` | Reusability notes and UX history |
| `README.md` | Top-level overview |
| `SECURITY.md` | Vulnerability reporting policy |

---

## 🌌 1. The Prime Directive: Pure Code in Submodules

* **Pure Code Only**: This repository must only contain pure code changes, standard open-source documentation, and configurations that are universally applicable to `env-doctor`.
* **No Monorepo Pollution**: NEVER commit internal monorepo-specific documentation, fork-specific guides, or private environment configurations into this repository.

### 🔄 The Fork-and-PR Workflow

When contributing upstream, follow this precise workflow:

1. **Configure Remotes**:
   Ensure you have both the official `upstream` and your personal fork `origin` configured:

   ```bash
   git remote -v
   # If upstream is missing, add it:
   git remote add upstream https://github.com/greyz/env-doctor.git
   ```

2. **Create a Clean Feature Branch**:
   Always branch off the latest `upstream/main`:

   ```bash
   git fetch upstream
   git checkout -b feat/your-feature-name upstream/main
   ```

3. **Implement Pure Code Changes**:
   Write clean, modular code. Ensure no temporary files, local logs, or environment files are tracked.

4. **Run Pre-Commit Audit Checks**:
   Check for misplaced files or "diff noise" before staging or committing:
   * Run `git status` and verify that no internal workflow or fork-specific files are staged.
   * Run `git diff` and ensure there are no formatting-only changes, trailing whitespace, or commented-out debug code.
   * Run the [local verification commands](#-4-local-development--verification) below.

5. **Commit and Push to Your Fork**:
   Commit with a clear, conventional commit message and push to your fork (`origin`):

   ```bash
   git commit -m "feat(doctor): add custom check or fix"
   git push -u origin HEAD
   ```

6. **Create the Pull Request**:
   Create the PR against the upstream repository on GitHub.

---

## 🏛️ 2. GlitchWorks Agnostic Architecture Protocol

All development within `env-doctor` must strictly adhere to the **GlitchWorks Agnostic Architecture Protocol**. This ensures that `env-doctor` remains completely decoupled, self-contained, and highly maintainable across any environment.

### 2.1. Zero Hardcoding (Dynamic State Configuration)

* **Rule**: No magic strings, static network ports, or fixed directory paths shall exist within the domain logic.
* **Application**: `env-doctor` must never contain hardcoded hostnames, ports, or monorepo-specific paths. All configurations must be dynamically configured via environment variables, configuration files, or command-line arguments.

### 2.2. Polymorphism by Default (Interface-Driven Contracts)

* **Rule**: Depend on abstractions, not concretions.
* **Application**: External tools (`git`, `python3`, `gh`, Docker) are invoked through small helper functions (`_check_tool`, `_pass`, `_warn`, etc.) so behavior stays consistent across human and agent callers. Prefer config-driven branches (`ENV_DOCTOR_*`, `.env-doctor.conf`) over hardcoded repo-specific logic.

### 2.3. Open Piping (Strict Inter-Process Communication)

* **Rule**: Modules must communicate via strictly typed, isolated message events rather than direct state mutation.
* **Application**: Human and agent callers must get identical behavior from the same flags. Machine output uses the `--json` envelope documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Human output uses `_pass` / `_warn` / `_fail` / `_info` on `stdout`; errors and hints go to `stderr` when appropriate. Never embed credentials or tokens in JSON rows.

### 2.4. Boundary Validation (The "Hostile Edge")

* **Rule**: Never trust incoming payloads. The core logic must be protected by a rigorous validation layer.
* **Application**: Validate all inputs (such as CLI flags, environment variables, or config files) at the boundary before processing them in the core logic. Malformed inputs must result in clean, typed error responses, not runtime panics.

### 2.5. State Hydration & Dehydration

* **Rule**: Systems must be capable of pausing, exporting their truth, and resuming from a snapshot.
* **Application**: Support serializing any state or report data into standard formats (JSON, etc.) and cleanly restoring or parsing them, allowing seamless teardown and reconstruction.

### 2.6. Graceful Degradation (Predictable Failure)

* **Rule**: When a pipe breaks or a dependency fails, the system must fail safely and transparently.
* **Application**: Avoid unhandled exceptions or shell crashes. Handle missing commands, offline APIs, or uninitialized states gracefully. If a tool is missing, catch the failure, log it clearly, and return a safe fallback state/exit code.

### 2.7. Agnostic Telemetry & Observability

* **Rule**: Domain logic must emit its telemetry without knowing where the logs are going.
* **Application**: Emit structured logs and telemetry via standard output streams or injected logging interfaces without knowing whether they are running inside a local terminal, a Docker container, or a cloud VM.

---

## 🧪 4. Local Development & Verification

From this repository root:

```bash
# Smoke: help and agent-safe JSON (no submodule scan)
bash env-doctor.sh --help
bash env-doctor.sh --json --quiet

# Optional static analysis (recommended when editing env-doctor.sh)
shellcheck env-doctor.sh
```

---

## 📋 5. Pre-Commit Checklist

Before submitting your PR, please verify:

* Are all variables and paths initialized dynamically or via configuration (`.env-doctor.conf`, `ENV_DOCTOR_*`)?
* Is the script decoupled from any specific monorepo path (no hardcoded monorepo paths in core logic)?
* Does `--json --quiet` exit 0 and produce parseable JSON?
* Does output avoid leaking credentials, tokens, or private URLs with embedded secrets?
* Can this logic be triggered headlessly (`--json`, `--quiet`) without refactoring?
* Are CLI flags and env vars validated at the boundary before use?
* Does the system fail predictably (`set -euo pipefail`, typed exit codes) without crashing the host shell?
* If `shellcheck` is available, does it report no new errors on `env-doctor.sh`?

Report security issues per [`SECURITY.md`](SECURITY.md), not public issues.
