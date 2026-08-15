# Follow-up backlog (hydration & agentic dev)

Tracked as GitHub issues tagged **`hydration-follow-up`** in the issue body (label creation pending repo permissions — use `enhancement` filter).

## How to use

1. Read [`docs/STATUS.md`](STATUS.md) for current capabilities.
2. Pick an issue from the table below.
3. Branch: `greyzxcursor/<issue#>-short-description-6557`
4. TDD: add tests in `tests/ubuntu-hydration.sh` or new `tests/hydration-*.sh` first.

## Issue index

| # | Title | Area |
|---|-------|------|
| [#8](https://github.com/k-dot-greyz/env-doctor/issues/8) | Multi-distro native package backends (dnf, pacman) | Platform |
| [#9](https://github.com/k-dot-greyz/env-doctor/issues/9) | Modern stack tier-2 hydration (Rust, Node, TS, Astro) | Stack |
| [#10](https://github.com/k-dot-greyz/env-doctor/issues/10) | Agentic development quickstart pack | Agents |
| [#11](https://github.com/k-dot-greyz/env-doctor/issues/11) | CI distro matrix for hydration integration tests | CI |
| [#12](https://github.com/k-dot-greyz/env-doctor/issues/12) | Extract lib/hydration manifest-driven install layer | Refactor |
| [#13](https://github.com/k-dot-greyz/env-doctor/issues/13) | zsh default shell + portable profile hydration | Shell |

## Suggested order

1. **#12** scaffold (enables #8 and #9 without spaghetti)
2. **#8** multi-distro backends (biggest reusability win)
3. **#9** modern stack hydration
4. **#10** agentic quickstarts (depends on stable hydration story)
5. **#11** CI matrix (validates #8/#9)
6. **#13** shell portability polish

## Search on GitHub

```text
repo:k-dot-greyz/env-doctor hydration-follow-up in:body
```
