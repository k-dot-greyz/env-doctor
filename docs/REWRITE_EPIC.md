# Epic: Heal pipeline rewrite (post PR #19)

**Status:** Planning — draft umbrella PR open  
**Orchestration playbook:** [ORCHESTRATION.md](ORCHESTRATION.md)

## Why now

PR #19 review + Bugbot identified:

1. **Security** — `ENV_DOCTOR_REPO` injection partially mitigated; `"` still breaks quoted profile embed ([#36](https://github.com/k-dot-greyz/env-doctor/issues/36)).
2. **Correctness** — tier init claims success when pip/pre-commit/submodule steps fail ([#23](https://github.com/k-dot-greyz/env-doctor/issues/23)).
3. **Verification** — no post-heal re-probe ([#20](https://github.com/k-dot-greyz/env-doctor/issues/20)).
4. **UX** — tier 1 recommended tools never installed; zero-flag run is audit-only ([#21](https://github.com/k-dot-greyz/env-doctor/issues/21), [#22](https://github.com/k-dot-greyz/env-doctor/issues/22)).
5. **Architecture** — no ablation/retry policy ([#24](https://github.com/k-dot-greyz/env-doctor/issues/24)); monolithic script ([#12](https://github.com/k-dot-greyz/env-doctor/issues/12)).

## Child issues (hydrated backlog)

| # | Title | Stream | Priority | Blocks |
|---|-------|--------|----------|--------|
| [#36](https://github.com/k-dot-greyz/env-doctor/issues/36) | Quote metachar in `ENV_DOCTOR_REPO` denylist (Bug #54) | Security | P0 | profile writes |
| [#23](https://github.com/k-dot-greyz/env-doctor/issues/23) | Init step transparency | Correctness | P0 | #20, #24 |
| [#20](https://github.com/k-dot-greyz/env-doctor/issues/20) | Post-init verify loop | Correctness | P0 | #21, #22 |
| [#24](https://github.com/k-dot-greyz/env-doctor/issues/24) | Ablation matrix + retry loop | Architecture | P1 | — |
| [#12](https://github.com/k-dot-greyz/env-doctor/issues/12) | `lib/hydration/` manifest layer | Architecture | P1 | #8, #9 |
| [#22](https://github.com/k-dot-greyz/env-doctor/issues/22) | Tier 1 tool hydration | UX | P1 | #21 |
| [#21](https://github.com/k-dot-greyz/env-doctor/issues/21) | Zero-flag smart bootstrap | UX | P1 | — |
| [#18](https://github.com/k-dot-greyz/env-doctor/issues/18) | Guided TUI / capability matrix | UX | P2 | — |
| [#8](https://github.com/k-dot-greyz/env-doctor/issues/8) | Multi-distro backends | Platform | P2 | — |
| [#9](https://github.com/k-dot-greyz/env-doctor/issues/9) | Modern stack tier 2 | Platform | P2 | — |

## Upgrade path summary

```
Merge PR #19
  → #36 quote guard (can cherry-pick to #19 or first sub-PR)
  → #23 honest init steps
  → #20 verify loop (+ --verify-only)
  → #24 ablation/retry ∥ #12 manifest scaffold
  → #22 tier 1 tools
  → #21 zero-flag bootstrap
  → #18 guided TUI
  → #8 / #9 platform expansion
```

## Multi-agent orchestration

See [ORCHESTRATION.md](ORCHESTRATION.md) for:

- Parallel workstreams and branch names
- Per-issue agent briefs (files, tests, acceptance criteria)
- Mermaid dependency graph
- Epic definition of done

**Search GitHub:**

```text
repo:k-dot-greyz/env-doctor orchestration-epic in:body
repo:k-dot-greyz/env-doctor hydration-follow-up in:body
```
