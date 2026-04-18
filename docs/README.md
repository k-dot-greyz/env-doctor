# env-doctor

Single-file Bash **environment discovery** and optional **progressive init** for any git checkout. No extra dependencies for the read-only pass (beyond optional `python3` for LM Studio model counts).

## Quick start

From a repository root:

```bash
bash dex/04-scripts/env-doctor.sh
# or
./env-doctor.sh
```

- **Generic repos**: submodule scan is off by default (fast CI-friendly runs). Use `--with-submodules` to enable full git submodule classification and private-URL hints.
- **dev-master-style trees** (auto-detected: `dex/` + `.gitmodules` mentioning `dex/09-repos`): submodule scan defaults **on** unless you pass `--skip-submodules`.

## Configuration (optional)

Create `.env-doctor.conf` in the **repository root** (sourced as shell). Typical variables:

| Variable | Purpose |
|----------|---------|
| `BRAND` | Banner title (default: script basename) |
| `ENV_DOCTOR_CORE_REPOS` | Extended regex for “core” submodule path suffixes (Tier 0 / targeted init) |
| `ENV_DOCTOR_PYTHON_DEPS` | Comma-separated Python import names to verify when a Python manifest exists |
| `ENV_DOCTOR_SHOW_AGENT_RAM` | Set to `true` to enable the `dex/10-tasks/active` check outside dev-master |
| `ENV_DOCTOR_HELP_URL` | URL printed after private-submodule SSH hints |

See [ARCHITECTURE.md](ARCHITECTURE.md) for phases, exit codes, and JSON output.

## Flags (summary)

| Flag | Meaning |
|------|---------|
| `--with-submodules` | Run submodule scan + private URL heuristics |
| `--skip-submodules` | Force skip (even in dev-master profile) |
| `--profile dev-master\|generic` | Override auto-detected profile |
| `--brand NAME` | Override banner brand |
| `--json` / `--quiet` | Machine / silent output |
| `--submodules` | Only run private-submodule + SSH check, then exit |
| `--init` / `--tier N` / `--dry-run` | Progressive setup (see `--help`) |

## Standalone / spin-off

Upstream mirror: [github.com/k-dot-greyz/env-doctor](https://github.com/k-dot-greyz/env-doctor) (sync from this tree when releasing).
