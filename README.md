# env-doctor

Bash **environment discovery** and optional **progressive init** for any git repo. Zero extra dependencies for the read-only pass (optional `python3` for LM Studio model counts).

Canonical implementation: `env-doctor.sh` in this repository.

## Quick start

```bash
git clone https://github.com/k-dot-greyz/env-doctor.git
cd env-doctor
bash env-doctor.sh --help
```

Optional repo-local config: **`.env-doctor.conf`** in the target repository root (see `docs/README.md` in this repo for variables).

## Consume from dev-master

When vendored under [dev-master](https://github.com/k-dot-greyz/dev-master):

- Submodule path: `dex/09-repos/env-doctor` (after superproject registers the submodule).
- Convenience wrapper at repo root: `./env-doctor.sh` → execs `dex/04-scripts/env-doctor.sh` (same script content is kept in sync with this repo).

## Documentation

- [`docs/README.md`](docs/README.md) — flags, config, quickstart
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — phases, JSON, profiles
- [`docs/UX_AUDIT.md`](docs/UX_AUDIT.md) — reusability notes

## Develop upstream

Edit `env-doctor.sh` here, push to `main`, then bump the submodule pointer in dev-master (see dev-master `dex/03-docs/guides/SUBMODULE_BUMP.md`).
