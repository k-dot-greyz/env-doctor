# env-doctor UX Audit (Reusability)

## Problem

Initially, the script had hardcoded repository assumptions, custom Python dependency imports, hardcoded submodule suffixes, and help text pointing at local paths. Dropped into a random repository or copied to a different environment, it produced noise (false warnings) or wrong roots.

## Before / After (High Level)

| Area | Before | After (v1.2.x) |
|------|--------|----------------|
| **Repo Root** | Hardcoded relative paths | `git rev-parse --show-toplevel` first, then fallbacks |
| **Python Deps** | Hardcoded lists | `ENV_DOCTOR_PYTHON_DEPS` via `.env-doctor.conf` |
| **Python version** | 3.10+ warn | **3.14+ required** (configurable floor) |
| **Node / Rust / Go** | Always checked | Only when matching manifests at repo root |
| **Submodule Scan** | Always on | Default off; `--with-submodules` |
| **Core Submodules** | Hardcoded regex | `ENV_DOCTOR_CORE_REPOS` |
| **Windows venv** | `bin/` only | `bin/` + `Scripts/` layout |
| **Linux tier 2** | brew-first, brittle apt | apt-preferred on Linux; `rg` binary fix |
| **Tier 3** | Docker only | PATH session + profile + boot audit + compose |
| **Private Submodule Hint** | Local path only | `ENV_DOCTOR_HELP_URL` |

## Plug-and-Play Estimate (honest)

| Target | Read-only audit | Full tier 3 hydration |
|--------|-----------------|-------------------------|
| Ubuntu / Debian / Mint + sudo | **~99%** | **~85%** (Python 3.14 may need PPA/uv) |
| Fedora / Arch / other Linux | **~99%** | **~40%** (no native tier-2 backend yet) |
| macOS + Homebrew | **~99%** | **~70%** (no Python 3.14 auto-install) |
| Windows Git Bash | **~95%** | **~50%** (no profile/boot hooks) |
| Cloud agent / CI runner | **~99%** JSON | **~30%** (no runner-specific profiles) |

## Remaining reusability gaps

Documented in [`STATUS.md`](STATUS.md) and tracked as GitHub issues (`hydration-follow-up` label):

1. **Multi-distro** — only `apt` for Linux tier 2; need `dnf`, `pacman`
2. **Stack hydration** — Rust/Node/TS/Astro detected but not installed by init
3. **Agent quickstarts** — generic `AGENTS.md` exists; no per-target (Cursor cloud, Copilot, devcontainer) packs
4. **Profile portability** — `ENV_DOCTOR_REPO` breaks when repo moves; no re-bootstrap hint automation
5. **Monolithic script** — hydration logic embedded in `env-doctor.sh`; needs `lib/hydration/` manifest

## Next steps

See [`FOLLOW_UPS.md`](FOLLOW_UPS.md) for the issue backlog.
