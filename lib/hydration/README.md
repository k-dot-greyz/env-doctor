# lib/hydration — manifest-driven install layer (scaffold)

**Status:** Planned — see [#12](https://github.com/k-dot-greyz/env-doctor/issues/12) and [ORCHESTRATION.md](../docs/ORCHESTRATION.md).

This directory will host:

- `manifest.json` — tool definitions, tier mapping, platform backends
- `ablation.json` — blocking vs skippable init steps per tier
- `install.sh` — loader invoked from `env-doctor.sh` `phase5_init`
- `retry.sh` — `_retry_init_step` with backoff ([#24](https://github.com/k-dot-greyz/env-doctor/issues/24))

**Do not implement here until Agent B2 (#12) starts** — orchestration epic [#37](https://github.com/k-dot-greyz/env-doctor/issues/37).
