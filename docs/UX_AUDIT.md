# env-doctor UX audit (reusability)

## Problem

The script lived under `dex/04-scripts/` with a fixed `REPO_ROOT="$(dirname)/../.."` assumption, dev-master-specific Python dep imports, hardcoded submodule suffixes, and help text pointing at `dex/03-docs/...` paths. Dropped into a random repo or copied to `/tmp`, it produced **noise** (false warnings) or **wrong roots**.

## Before / after (high level)

| Area | Before | After |
|------|--------|-------|
| Repo root | Two levels up from script | `git rev-parse --show-toplevel` first |
| Python deps | Always `click rich …` | Only when `ENV_DOCTOR_PYTHON_DEPS` set (dev-master via `.env-doctor.conf`) |
| Node / Rust / Go | Always checked | Only when manifest at repo root |
| Submodule scan | Always on | Default off in generic profile; `--with-submodules` / profile auto |
| Core submodule names | Hardcoded regex | `ENV_DOCTOR_CORE_REPOS` from config |
| Agent RAM | Always warned | `dev-master` profile or `ENV_DOCTOR_SHOW_AGENT_RAM` |
| `zen` CLI | Missing → warn | Missing → **info** (teaser) |
| `.env` missing | Warn always | **Info** if no `env.example` |
| Banner | “dev-master” hardcoded | `BRAND` or script name |
| Private submodule hint | Local path only | Optional `ENV_DOCTOR_HELP_URL` |

## Plug-and-play estimate

- **~60%** before this pass for “random repo, script copied anywhere”.
- **~95%** after: remaining gaps are policy choices (e.g. still recommending Docker/`gh`, optional LM Studio `python3` dependency).

## Follow-ups (not this PR)

- Sync canonical script to [env-doctor](https://github.com/k-dot-greyz/env-doctor) submodule + `.gitmodules`.
- Tier-2 polish: JSON escaping, `printf` SC2059, richer per-language checks (`npm ls`, `cargo check`).
