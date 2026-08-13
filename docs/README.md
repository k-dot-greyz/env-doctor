# env-doctor

Single-file Bash **environment discovery** and optional **progressive init** for any git checkout. No extra dependencies for the read-only pass.

> **Start here:** [`docs/STATUS.md`](STATUS.md) — platform matrix, tier behavior, and known limitations.

## Quick Start

From any repository root:

```bash
bash env-doctor.sh              # read-only audit
bash env-doctor.sh --json -q    # machine-readable (agents / CI)
bash env-doctor.sh --init --tier 3 --dry-run   # preview hydration
```

- **Submodule scan**: Off by default. Use `--with-submodules` for full submodule classification.
- **Full Linux hydration** (Ubuntu/Debian/Mint): see [QUICKSTART.md](../QUICKSTART.md#full-ubuntu--linux-hydration-tier-23).

## Configuration (optional)

Create `.env-doctor.conf` in your **repository root**. Generate a template:

```bash
bash env-doctor.sh --print-config-template > .env-doctor.conf
```

| Variable | Purpose |
|----------|---------|
| `BRAND` | Custom banner title |
| `ENV_DOCTOR_CORE_REPOS` | Regex for Tier 1 core submodule path suffixes |
| `ENV_DOCTOR_PYTHON_DEPS` | Comma-separated Python import names to verify |
| `ENV_DOCTOR_HELP_URL` | URL for private submodule setup hints |
| `ENV_DOCTOR_MIN_PYTHON_MINOR` | Minimum Python minor version (default: **14**) |
| `ENV_DOCTOR_PERSIST_PATH` | Tier 3: append PATH block to shell profile (`true`/`false`) |
| `ENV_DOCTOR_BOOT_AUDIT` | Tier 3: install login audit hooks (`true`/`false`) |
| `ENV_DOCTOR_REPO` | Repo path for persistent profile block |

## Init tiers (summary)

| Tier | Scope |
|------|--------|
| 0 | Python 3.14+ venv + pip/poetry/requirements |
| 1 | Core submodules, dev extras, pre-commit |
| 2 | All submodules + native dev tools (**apt on Linux**, brew on macOS) |
| 3 | Session PATH, optional profile/boot hooks, Docker Compose |

All system mutations require `--init` and package/profile changes require `--yes`. See [`docs/STATUS.md`](STATUS.md) for per-platform details.

## Flags (summary)

| Flag | Meaning |
|------|---------|
| `--with-submodules` | Submodule scan + private URL heuristics |
| `--brand NAME` | Override banner brand |
| `--json` / `-j` | Machine-readable JSON (`env-doctor/1` schema) |
| `--quiet` / `-q` | Exit code only |
| `--init` / `-i` | Enable progressive init |
| `--tier N` / `-t N` | Init tier 0–3 (default: 1) |
| `--dry-run` / `-n` | Preview init without changes |
| `--yes` / `-y` | Consent for apt/brew installs and profile writes |
| `--print-profile-template` | Emit shell PATH hydration snippet |
| `--print-agent-template` | Emit `AGENTS.md` protocol |
| `--safety` / `--about` | Product and safety model |

Full list: `bash env-doctor.sh --help`

## Follow-up work

Planned hardening for multi-distro targets, agentic quickstarts, and reusable hydration profiles: [`docs/FOLLOW_UPS.md`](FOLLOW_UPS.md) and GitHub issues labeled `hydration-follow-up`.

See [ARCHITECTURE.md](ARCHITECTURE.md) for phases and JSON output, and [PLAYBOOK.md](PLAYBOOK.md) for integration patterns.
