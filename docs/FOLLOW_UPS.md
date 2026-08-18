# Follow-up backlog (hydration & agentic dev)

## Orchestration epic

**Major rewrite planning:** [#37](https://github.com/k-dot-greyz/env-doctor/issues/37) — heal pipeline orchestration.  
**Playbook:** [`docs/ORCHESTRATION.md`](ORCHESTRATION.md) · [`docs/REWRITE_EPIC.md`](REWRITE_EPIC.md)  
**Draft umbrella PR:** branch `greyzxcursor/heal-orchestration-major-rewrite-4c79`

Tracked issues use tags in the body: **`hydration-follow-up`** + **`orchestration-epic`**.

## How to use

1. Read [`docs/STATUS.md`](STATUS.md) for current capabilities.
2. Read [`docs/ORCHESTRATION.md`](ORCHESTRATION.md) for multi-agent assignments.
3. Pick an issue from the table below.
4. Branch: `greyzxcursor/<issue#>-short-slug-4c79`
5. TDD: add tests in `tests/ubuntu-hydration.sh` or new `tests/init-*.sh` / `tests/ablation-*.sh` first.

## Issue index

| # | Title | Area |
|---|-------|------|
| [#37](https://github.com/k-dot-greyz/env-doctor/issues/37) | **Epic:** heal pipeline orchestration | Epic |
| [#36](https://github.com/k-dot-greyz/env-doctor/issues/36) | Bug #54 — quote metachar in ENV_DOCTOR_REPO denylist | Security |
| [#23](https://github.com/k-dot-greyz/env-doctor/issues/23) | Init step transparency — stop silent `\|\| true` passes | Correctness |
| [#20](https://github.com/k-dot-greyz/env-doctor/issues/20) | Post-init verify loop — re-ping deps after heal | Correctness |
| [#24](https://github.com/k-dot-greyz/env-doctor/issues/24) | Graceful ablation matrix + polymorphic retry loop | Architecture |
| [#22](https://github.com/k-dot-greyz/env-doctor/issues/22) | Tier 1 recommended tool hydration (gh, pre-commit, docker) | Stack |
| [#21](https://github.com/k-dot-greyz/env-doctor/issues/21) | Zero-flag smart bootstrap (tier 1 deps by default) | UX |
| [#18](https://github.com/k-dot-greyz/env-doctor/issues/18) | T3 submodule hydration + guided TUI quickstart | UX |
| [#8](https://github.com/k-dot-greyz/env-doctor/issues/8) | Multi-distro native package backends (dnf, pacman) | Platform |
| [#9](https://github.com/k-dot-greyz/env-doctor/issues/9) | Modern stack tier-2 hydration (Rust, Node, TS, Astro) | Stack |
| [#10](https://github.com/k-dot-greyz/env-doctor/issues/10) | Agentic development quickstart pack | Agents |
| [#11](https://github.com/k-dot-greyz/env-doctor/issues/11) | CI distro matrix for hydration integration tests | CI |
| [#12](https://github.com/k-dot-greyz/env-doctor/issues/12) | Extract lib/hydration manifest-driven install layer | Refactor |
| [#13](https://github.com/k-dot-greyz/env-doctor/issues/13) | zsh default shell + portable profile hydration | Shell |

## Suggested order

See [`docs/ORCHESTRATION.md`](ORCHESTRATION.md) for parallel lanes. Critical path:

1. **#36** quote guard (Bug #54) — can land on PR #19
2. **#23** init transparency
3. **#20** post-init verify
4. **#24** ablation + retry ∥ **#12** manifest scaffold
5. **#22** tier 1 tools → **#21** zero-flag → **#18** TUI
6. **#8** / **#9** platform expansion

## Search on GitHub

```text
repo:k-dot-greyz/env-doctor orchestration-epic in:body
repo:k-dot-greyz/env-doctor hydration-follow-up in:body
```
