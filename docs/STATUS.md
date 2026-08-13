# env-doctor — Current Reality (v1.2.x + hydration branch)

Last updated: 2026-08-13. This document is the **source of truth** for what works today, what is partial, and what is planned. See [open follow-up issues](https://github.com/k-dot-greyz/env-doctor/issues?q=is%3Aissue+label%3Ahydration-follow-up) for next steps.

## Platform support matrix

| Capability | Ubuntu / Debian / Mint | Fedora / RHEL / Arch | macOS | Windows (Git Bash) |
|------------|------------------------|----------------------|-------|---------------------|
| Read-only audit (Phases 1–4) | Yes | Yes | Yes | Yes |
| Tier 0 venv + pip deps | Yes (Python **3.14+** required) | Yes (manual Python 3.14) | Yes | Yes (`Scripts/` layout) |
| Tier 1 submodules + dev extras | Yes | Yes | Yes | Yes |
| Tier 2 **native** pkg install | **apt only** | Not yet — use manual install | brew | winget / choco / scoop |
| Tier 2 Python 3.14 install | deadsnakes PPA → uv fallback | Not automated | brew / manual | winget / manual |
| Tier 3 session PATH | Yes | Yes | Yes | Yes (Scripts layout) |
| Tier 3 persistent profile | Yes (`ENV_DOCTOR_PERSIST_PATH`) | Yes | Yes | Limited (Git Bash) |
| Tier 3 boot/login audit | Yes (`scripts/env-config.sh`) | Yes | Yes (no launchd yet) | No |
| Tier 3 Docker Compose | Yes (4 compose filenames) | Yes | Yes | Yes |

**Bottom line:** Tier 2–3 hydration is **production-ready on Ubuntu/Debian/Mint with apt + sudo**. Other Linux distros get audit + tier 0–1 + tier 3 PATH/Docker; native package installs are follow-up work.

## Init tier reference (actual behavior)

| Tier | What it does today | Requires `--yes` for system changes |
|------|-------------------|-------------------------------------|
| **0** | `.venv` + pip/poetry/requirements install | venv only (no sudo) |
| **1** | Core submodules (`--with-submodules` + `ENV_DOCTOR_CORE_REPOS`), `pip install -e ".[dev]"`, pre-commit | pip only |
| **2** | All submodules; apt/brew/winget dev tools; Python 3.14 on apt Linux | apt/brew/winget installs |
| **3** | Session PATH; optional profile block; optional boot audit; `docker compose up -d` | profile + boot hooks |

### Tier 2 apt packages (Linux)

Installed when missing and `--yes` is set:

- `git`, `curl`, `ca-certificates`
- `ripgrep` (binary checked as `rg`)
- `shellcheck`, `yamllint`
- `python3.14`, `python3.14-venv`, `python3-pip` (Ubuntu: deadsnakes PPA first)

### Tier 3 opt-in flags (`.env-doctor.conf`)

| Variable | Default | Effect |
|----------|---------|--------|
| `ENV_DOCTOR_MIN_PYTHON_MINOR` | `14` | Discovery + init floor |
| `ENV_DOCTOR_PERSIST_PATH` | `false` | Append PATH block to `~/.bashrc` / `~/.zshrc` |
| `ENV_DOCTOR_BOOT_AUDIT` | `false` | Run `scripts/env-config.sh install` |
| `ENV_DOCTOR_REPO` | repo root at init | Path baked into persistent profile block |

**Consent model:** Profile writes and boot hooks require `--yes` **and** the config flag. Preview with `--dry-run` or `--print-profile-template`.

## Python 3.14 requirement

As of the hydration branch, discovery **fails** (not warns) when the best available Python is below 3.14. This is intentional — no legacy Python life support.

- Ubuntu: `bash env-doctor.sh --init --tier 2 --yes` attempts deadsnakes + uv
- Other platforms: install Python 3.14 manually before `--init`

## Agentic development (today)

What agents can rely on **now**:

```bash
# Read-only — always safe, no mutations
bash env-doctor.sh --json --quiet

# Preview fixes
bash env-doctor.sh --init --tier 3 --dry-run

# Heal (requires human or explicit agent consent)
bash env-doctor.sh --init --tier 3 --yes
```

Templates in `templates/`:

| File | Purpose |
|------|---------|
| `AGENTS.md` | Agent protocol (generate via `--print-agent-template`) |
| `pre-commit-config.yaml` | Fast audit on commit |
| `github-actions-env-doctor.yml` | CI JSON gate |
| `env-doctor-profile.snippet` | Manual PATH persistence |
| `systemd-user-env-doctor.service` | Login audit unit template |

**Not yet:** distro-specific agent quickstarts, cloud-agent VM bootstrap, multi-repo hydration profiles, or auto-tier selection from JSON audit.

## Makefile targets

```bash
make smoke        # CLI smoke checks
make test         # smoke + security + ubuntu-hydration tests
make lint         # shellcheck
make ci           # lint + test
make setup        # --init --tier 3 --yes
make hydrate-dry  # --init --tier 3 --dry-run
```

## Known limitations

1. **Single-file script** — hydration helpers live in `env-doctor.sh` (~1.7k lines); manifest-driven `lib/hydration/` is planned.
2. **apt-only on Linux** — Fedora (`dnf`) and Arch (`pacman`) not implemented for tier 2.
3. **No Rust/Node/TS/Astro auto-install** — detected in audit, not hydrated in init.
4. **Boot audit** — bash/zsh profile snippet + systemd user unit; no macOS launchd, no Windows Task Scheduler.
5. **Python 3.14** — may require deadsnakes PPA or `uv`; not in default Ubuntu repos on all releases.
6. **Tier 0 failure** — if venv activation fails at tier 0 only, init aborts; higher tiers can continue if tier > 0.

## What to do next

See GitHub issues [#8](https://github.com/k-dot-greyz/env-doctor/issues/8)–[#13](https://github.com/k-dot-greyz/env-doctor/issues/13) (tagged `hydration-follow-up` in body). Full index: [`docs/FOLLOW_UPS.md`](FOLLOW_UPS.md).

1. **#8** Multi-distro native backends (dnf, pacman)
2. **#9** Modern stack hydration (Rust, Node, TypeScript, Astro)
3. **#10** Agentic quickstart pack for Cursor / cloud agents
4. **#11** CI distro matrix + integration tests
5. **#12** Manifest-driven hydration refactor (`lib/hydration/`)
6. **#13** zsh default shell + cross-env profile portability
