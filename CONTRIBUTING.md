# Contributing to env-doctor

Welcome to the `env-doctor` repository! We are excited to have you contribute.

To ensure a clean, maintainable, and robust codebase, all contributions must strictly adhere to our development standards, repository boundaries, and architectural protocols.

---

## 🌌 1. The Prime Directive: Pure Code in Submodules, Guides in Superproject

If you are developing `env-doctor` as part of a larger monorepo (such as `dev-master`), you must respect the boundary between the monorepo and this submodule:

* **Pure Code Only**: This repository must only contain pure code changes, standard open-source documentation, and configurations that are universally applicable to `env-doctor`.
* **No Monorepo Pollution**: NEVER commit internal monorepo-specific documentation, fork-specific guides, or private environment configurations into this repository.
* **Guides Live in Superproject**: All internal guides, monorepo-specific notes, and fork-specific instructions must live in the superproject under `dex/03-docs/guides/`.

### 🔄 The Submodule Fork-and-PR Workflow

When contributing upstream, follow this precise workflow:

1. **Configure Remotes**:
   Ensure you have both the official `upstream` and your personal fork `origin` configured:

   ```bash
   git remote -v
   # If upstream is missing, add it:
   git remote add upstream https://github.com/k-dot-greyz/env-doctor.git
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
   * Run `git diff` to ensure there are no formatting-only changes, trailing whitespace, or commented-out debug code.

5. **Commit and Push to Your Fork**:
   Commit with a clear, conventional commit message and push to your fork (`origin`):

   ```bash
   git commit -m "feat(doctor): add custom check or fix"
   git push -u origin HEAD
   ```

6. **Create the Pull Request**:
   Create the PR against the upstream repository on GitHub.

### 🛠️ Cleaning Up History After a Boundary Leak

If you accidentally committed internal documentation or unrelated files to this repository, clean up the branch history before pushing:

```bash
# Soft reset to upstream/main (keeps your changes staged)
git reset --soft upstream/main

# Move internal files out of the submodule to the superproject, or discard unwanted files
git restore <file>

# Re-commit the clean diff
git commit -m "feat(doctor): clean implementation"

# Force-push to rewrite remote history
git push origin feat/your-feature-name --force
```

---

## 🏛️ 2. GlitchWorks Agnostic Architecture Protocol

All development within `env-doctor` must strictly adhere to the **GlitchWorks Agnostic Architecture Protocol**. This ensures that `env-doctor` remains completely decoupled, self-contained, and highly maintainable across any environment.

### 2.1. Zero Hardcoding (Dynamic State Configuration)

* **Rule**: No magic strings, static network ports, or fixed directory paths shall exist within the domain logic.
* **Application**: `env-doctor` must never contain hardcoded hostnames, ports, or superproject-specific paths. All configurations must be dynamically configured via environment variables, configuration files, or command-line arguments.

### 2.2. Polymorphism by Default (Interface-Driven Contracts)

* **Rule**: Depend on abstractions, not concretions.
* **Application**: Interact with external dependencies through abstract interfaces or standard contracts. You must be able to swap out real services/tools with mocks at initialization without altering internal logic.

### 2.3. Open Piping (Strict Inter-Process Communication)

* **Rule**: Modules must communicate via strictly typed, isolated message events rather than direct state mutation.
* **Application**: Output data must follow a strict, predictable format (e.g., standard JSON schemas). Utilize standard streams (`stdout`/`stderr`) or APIs to transfer data. A CLI run and an automated agent run must trigger identical system behaviors by sending/receiving the same data.

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

## 📋 3. Pre-Commit Checklist

Before submitting your PR, please verify:

* Are all variables and paths initialized dynamically or via configuration?
* Is the module entirely decoupled from any specific monorepo or superproject?
* Are the input/output pipes strictly typed and isolated?
* Can this logic be triggered headlessly without refactoring?
* Is incoming data validated at the boundary before processing?
* Can the current state/report be dehydrated and cleanly rehydrated?
* Does the system fail predictably without crashing the host process?
