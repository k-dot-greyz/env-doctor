# Test coverage decision log — env-doctor

## Latest run (2026-08-18, branch 2a7b)

See [`docs/TEST_COVERAGE_2026-08-18-agentic-security.md`](TEST_COVERAGE_2026-08-18-agentic-security.md) — CI repair for PR #17: merged `_check_python` pin logic, Playwright py314 harness, security.sh fixture isolation.

## Prior run (2026-08-13, branch 92c7)

`k-dot-greyz/env-doctor` branch `greyzxcursor/agentic-security-test-coverage-7db4`. Merges dinit auth blocker coverage (PR #14 / #15) with main's hydration and security harness work (PR #6).

## Attack surface (scoped)

| Surface | Risk | Coverage |
|---------|------|----------|
| `.env-doctor.conf` safe parser | RCE via repo-controlled config | Malicious `touch` blocked; unsafe opt-in executes only with `--unsafe-source-config` |
| `.env-doctor.conf` unsafe sourcing | RCE when user opts in | World-writable file refused; ownership warning path |
| `ENV_DOCTOR_PYTHON_DEPS` → `python -c import` | Command injection | Semicolon/metachar rejection (bash + Playwright) |
| `--brand` argv (agentic callers) | Banner/JSON injection | Semicolon, pipe, shell expansion rejected at boundary |
| Config allowlist (`BRAND`, `ENV_DOCTOR_HELP_URL`, …) | Unexpected key execution / bad URLs | Unsafe BRAND skipped; `javascript:` HELP_URL skipped |
| Git remote URLs in JSON | Credential leakage to CI/agent logs | ghp_, glpat-, user:pass redaction |
| Tool version strings (`_check_tool`) | JSON envelope breakage / injection | Hostile PATH `rg` stub; JSON remains parseable |
| **HTTPS GitHub `origin` remote** | Submodule init prompts / credential phishing | Warn + `ENV_DOCTOR_NEXT_CMD=dinit auth` blocker footer |
| **`git config url.*.insteadOf` poison** | HTTPS override hijacks SSH remotes | Global config scan warns + suggests `dinit auth`; legitimate HTTPS→SSH rewrite excluded |
| **`gh auth status` (stale / missing scopes)** | Agent assumes auth is fine, submodule init fails opaquely | Stubbed `gh` modes incl. quoted scopes (real `gh` format) |
| **`_gh_has_scope` parsing** | False pass/miss on quoted or comma-separated scopes | Strips quotes; comma-delimited scope match |
| Summary blocker footer | Agent parses human text from JSON stdout | JSON mode verified free of `blocker:` footer on stdout |
| `--init` / venv activation | Crash on Windows `Scripts/` layout | Covered in `tests/smoke.sh` |
| `--tier` / malformed argv | Agent sends invalid tier | Exit 1 for tier 4 and non-numeric |

**Deferred (environment-dependent):** live `git submodule update`, `brew install` consent gates, submodule init failure stderr path — require network/credentials; documented in `docs/THREAT_MODEL.md`.

## Tests added / updated

| File | Role |
|------|------|
| `tests/harness-config.sh` | Constructor — runtime values via `HARNESS_*` env overrides (version read from script) |
| `tests/helpers.sh` | Shared assertions, fixture factory, `make_gh_stub` for auth modes |
| `tests/security.sh` | Expanded boundary suite (config, argv, redaction, hostile tool output) |
| `tests/auth-blockers.sh` | dinit auth blocker paths (HTTPS remote, config poison, gh stubs, quoted scopes, legit insteadOf) |
| `tests/ubuntu-hydration.sh` | Tier 2–3 hydration dry-run checks |
| `tests/run.sh` | Runs smoke + security + auth-blockers + ubuntu-hydration |
| `tests/ux-agent-flow.spec.ts` | Playwright CLI harness — agent cold-boot user stories (US-1..5) |
| `tests/security-boundary.spec.ts` | Playwright — conf injection, mock `.env`, `--brand` rejection |
| `env-doctor.sh` | Shellcheck-safe blocker `printf`; `_gh_has_scope` quote stripping; insteadOf poison key-only match |

## Impact vs cost

- **Impact:** High — `ENV_DOCTOR_NEXT_CMD` / dinit auth guidance is on the primary agent diagnostic path (`templates/AGENTS.md` step 2). Wrong or missing signals cause agents to loop on submodule/auth failures.
- **Cost:** Low — temp git fixtures + stubbed `gh`; no network. Bash suite ~50s; Playwright adds ~5–10s after `npm install`.
- **Speed:** Bash suite remains the PR gate (`make test`); Playwright documents UX stories for T+7 agent reruns.

## Validation

```bash
bash tests/run.sh
npm install && npm test
make ci   # when shellcheck is available
```

## Follow-ups

Tracked as GitHub issues (see PR #15 merge prep):

- Emit `next_cmd` in JSON envelope for agents (avoid parsing human blocker footer).
- Add optional `npm test` / Playwright job to CI after cache wiring.
- Submodule init failure path (`_submodule_init_hint`) — controllable failing `git submodule` stub.
- JSON escaping fuzz with embedded `\u0000` in git config values.
- Sync dev-master `dex/09-repos/env-doctor` pointer after merge.
