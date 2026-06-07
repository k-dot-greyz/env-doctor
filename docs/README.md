# env-doctor

Single-file Bash **environment discovery** and optional **progressive init** for any git checkout. No extra dependencies for the read-only pass.

## Quick Start

From any repository root:

```bash
bash env-doctor.sh
```

- **Submodule scan**: Off by default for fast, CI-friendly runs. Use `--with-submodules` to enable full git submodule classification and private-URL hints.

## Configuration (optional)

Create `.env-doctor.conf` in your **repository root** (sourced as shell). Typical variables:

| Variable | Purpose |
|----------|---------|
| `BRAND` | Custom banner title displayed at the top of the output (default: script name) |
| `ENV_DOCTOR_CORE_REPOS` | Extended regex for "core" submodule path suffixes (Tier 1 targeted init) |
| `ENV_DOCTOR_PYTHON_DEPS` | Comma-separated Python import names to verify when a Python manifest exists |
| `ENV_DOCTOR_HELP_URL` | Custom URL printed next to private submodule warnings to guide developers |

See [ARCHITECTURE.md](ARCHITECTURE.md) for phases, exit codes, and JSON output, and [PLAYBOOK.md](PLAYBOOK.md) for full integration patterns (Git hooks, CI/CD, and AI agents).

## Flags (summary)

| Flag | Meaning |
|------|---------|
| `--with-submodules` | Run submodule scan + private URL heuristics |
| `--brand NAME` | Override banner brand |
| `--json` | Emit machine-readable JSON output (GW-AAP Open Piping) |
| `--quiet` | Silent output (exit code only) |
| `--version` / `-v` | Print script version |
| `--submodules` | Only run private-submodule + SSH check, then exit |
| `--init` / `--tier N` / `--dry-run` | Progressive setup (see `--help`) |
