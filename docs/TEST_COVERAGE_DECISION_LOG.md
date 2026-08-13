# Test coverage decision log — env-doctor (2026-08-13)

## Target

`k-dot-greyz/env-doctor` branch `greyzxcursor/agentic-security-test-coverage-7db4`. Automation triggered by CI failure on PR #14 (`feat/dinit-auth-blockers`) — shellcheck SC2059 on summary blocker `printf`, plus missing tests for new dinit auth blocker paths merged at `114e1b1`.

## Attack surface (scoped)

| Surface | Risk | Coverage |
|---------|------|----------|
| `.env-doctor.conf` safe parser | RCE via repo-controlled config | Malicious `touch` blocked; unsafe opt-in executes only with `--unsafe-source-config` |
| `.env-doctor.conf` unsafe sourcing | RCE when user opts in | World-writable file refused |
| `ENV_DOCTOR_PYTHON_DEPS` → `python -c import` | Command injection | Semicolon/metachar rejection (bash + Playwright) |
| `--brand` argv (agentic callers) | Banner/JSON injection | Semicolon, pipe, shell expansion rejected at boundary |
| Config allowlist (`BRAND`, `ENV_DOCTOR_HELP_URL`, …) | Unexpected key execution / bad URLs | Unsafe BRAND skipped; `javascript:` HELP_URL skipped |
| Git remote URLs in JSON | Credential leakage to CI/agent logs | ghp_, glpat-, user:pass redaction |
| Tool version strings (`_check_tool`) | JSON envelope breakage / injection | Hostile PATH `rg` stub; JSON remains parseable |
| **HTTPS GitHub `origin` remote** | Submodule init prompts / credential phishing | Warn + `ENV_DOCTOR_NEXT_CMD=dinit auth` blocker footer |
| **`git config url.*.insteadOf` poison** | HTTPS override hijacks SSH remotes | Global config scan warns + suggests `dinit auth` |
| **`gh auth status` (stale / missing scopes)** | Agent assumes auth is fine, submodule init fails opaquely | Stubbed `gh` modes: invalid token, unauth, missing `repo`, missing `admin:public_key` |
| **`_gh_has_scope` parsing** | False pass when `Token scopes:` line matched any scope check | Fixed to parse comma-separated scopes on the scopes line only |
| Summary blocker footer | Agent parses human text from JSON stdout | JSON mode verified free of `blocker:` footer on stdout |

**Deferred (environment-dependent):** live `git submodule update`, `brew install` consent gates, submodule init failure stderr path — require network/credentials; documented in `docs/THREAT_MODEL.md`.

## Tests added / updated

| File | Role |
|------|------|
| `tests/harness-config.sh` | Constructor — runtime values via `HARNESS_*` env overrides (version read from script) |
| `tests/helpers.sh` | Shared assertions, fixture factory, `make_gh_stub` for auth modes |
| `tests/security.sh` | Expanded boundary suite (config, argv, redaction, hostile tool output) |
| `tests/auth-blockers.sh` | **New** — dinit auth blocker paths (HTTPS remote, config poison, gh stubs) |
| `tests/run.sh` | Runs smoke + security + auth-blockers |
| `tests/ux-agent-flow.spec.ts` | Playwright CLI harness — agent cold-boot user stories (US-1..5) |
| `tests/security-boundary.spec.ts` | Playwright — conf injection, mock `.env`, `--brand` rejection |
| `env-doctor.sh` | Shellcheck fix: blocker `printf` uses `%s` format args; `_gh_has_scope` parses scopes line correctly |

## Impact vs cost

- **Impact:** High — PR #14 adds `ENV_DOCTOR_NEXT_CMD` / dinit auth guidance on the primary agent diagnostic path (`templates/AGENTS.md` step 2). Wrong or missing signals cause agents to loop on submodule/auth failures.
- **Cost:** Low — temp git fixtures + stubbed `gh`; no network. Bash suite ~45s; Playwright adds ~5–10s after `npm install`.
- **Speed:** Bash suite remains the PR gate (`make test`); Playwright documents UX stories for T+7 agent reruns.

## Validation

```bash
bash tests/run.sh
npm install && npm test
make ci   # when shellcheck is available
```

## Follow-ups

- Add optional `npm test` job to CI after Playwright cache is wired.
- Emit `next_cmd` in JSON envelope for agents (avoid parsing human blocker footer).
- Submodule init failure path (`_submodule_init_hint`) — needs controllable failing `git submodule` stub.
