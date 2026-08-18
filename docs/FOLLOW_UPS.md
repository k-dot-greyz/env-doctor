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
| [#18](https://github.com/k-dot-greyz/env-doctor/issues/18) | T3 submodule hydration + guided TUI quickstart | UX |
| [#20](https://github.com/k-dot-greyz/env-doctor/issues/20) | Post-init verify loop — re-ping deps after heal | Correctness |
| [#21](https://github.com/k-dot-greyz/env-doctor/issues/21) | Zero-flag smart bootstrap (tier 1 deps by default) | UX |
| [#22](https://github.com/k-dot-greyz/env-doctor/issues/22) | Tier 1 recommended tool hydration (gh, pre-commit, docker) | Stack |
| [#23](https://github.com/k-dot-greyz/env-doctor/issues/23) | Init step transparency — stop silent `\|\| true` passes | Correctness |
| [#24](https://github.com/k-dot-greyz/env-doctor/issues/24) | Graceful ablation matrix + polymorphic retry loop | Architecture |

## Suggested order

### Heal correctness (do first — unblocks white-glove UX)

1. **#23** init transparency (stop false-green `_pass` on failed installs)
2. **#20** post-init verify loop (re-ping deps after heal)
3. **#24** ablation matrix + retry loop (predictable failure + transient recovery)

### Onboarding UX (tier 1 by default)

4. **#22** tier 1 tool hydration (gh, pre-commit, docker CLI)
5. **#21** zero-flag smart bootstrap (common-sense tier 1 without flags)
6. **#18** guided TUI / developer capability matrix (interactive flavor picker)

### Platform & stack expansion

7. **#12** scaffold (enables #8, #9, #24 without spaghetti)
8. **#8** multi-distro backends (biggest reusability win)
9. **#9** modern stack hydration
10. **#10** agentic quickstarts (depends on stable hydration story)
11. **#11** CI matrix (validates #8/#9)
12. **#13** shell portability polish

## Search on GitHub

```text
repo:k-dot-greyz/env-doctor hydration-follow-up in:body
```
