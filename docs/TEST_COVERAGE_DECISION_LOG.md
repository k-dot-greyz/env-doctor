# Test coverage decision log — env-doctor

## Latest run (2026-08-18, branch 2a7b)

See [`docs/TEST_COVERAGE_2026-08-18-agentic-security.md`](TEST_COVERAGE_2026-08-18-agentic-security.md) — CI repair for PR #17: merged `_check_python` pin logic, Playwright py314 harness, security.sh fixture isolation.

## Prior run (2026-08-13, branch 92c7)

`k-dot-greyz/env-doctor` on branch `greyzxcursor/agentic-security-test-coverage-92c7`. Automation triggered by CI failure on PR #4 (`greyzxc/critical-correctness-bugs-8ef4`) — shellcheck warnings in an older monolithic `tests/run.sh`. This run adds security/UX coverage for merged Windows venv hardening and agentic boundary paths.

## Attack surface (scoped)

| Surface | Risk | Coverage |
|---------|------|----------|
| `.env-doctor.conf` safe parser | RCE via repo-controlled config | Malicious `touch` blocked; unsafe opt-in executes only with `--unsafe-source-config` |
| `.env-doctor.conf` unsafe sourcing | RCE when user opts in | World-writable file refused; ownership warning path |
| `ENV_DOCTOR_PYTHON_DEPS` → `python -c import` | Command injection | Semicolon/metachar rejection (bash + Playwright) |
| `--brand` argv (agentic callers) | Banner/JSON injection | Semicolon, newline, tab rejected at boundary |
| Config allowlist (`BRAND`, `ENV_DOCTOR_HELP_URL`, …) | Unexpected key execution / bad URLs | Unsafe BRAND skipped; `javascript:` HELP_URL skipped; unknown keys ignored |
| Git remote URLs in JSON | Credential leakage to CI/agent logs | ghp_, glpat-, user:pass redaction |
| Tool version strings (`_check_tool`, zen teaser) | JSON envelope breakage / injection | Hostile PATH `zen` stub; JSON remains parseable |
| `--init` / venv activation | Crash on Windows `Scripts/` layout | Covered in `tests/smoke.sh` (existing branch work) |
| `--tier` / malformed argv | Agent sends invalid tier | Exit 1 for tier 4 and non-numeric |

**Deferred (environment-dependent):** live `git submodule update`, `brew install` consent gates, LM Studio HTTP — documented in `docs/THREAT_MODEL.md`; not isolated in this PR.

## Tests added / updated

| File | Role |
|------|------|
| `tests/harness-config.sh` | Constructor — all runtime values via `HARNESS_*` env overrides (version read from script) |
| `tests/helpers.sh` | Shared assertions + fixture factory (uses harness config) |
| `tests/security.sh` | Expanded boundary suite (config, argv, redaction, hostile tool output) |
| `tests/ux-agent-flow.spec.ts` | Playwright CLI harness — agent cold-boot user stories (US-1..4) |
| `tests/security-boundary.spec.ts` | Playwright — conf injection, mock `.env`, `--brand` rejection |
| `package.json` / `playwright.config.ts` | Optional `npm test` = bash + Playwright |

## Impact vs cost

- **Impact:** High — `env-doctor.sh` is the first diagnostic in `templates/AGENTS.md`; agents and CI depend on stable JSON and safe config parsing. Windows venv regressions had high blast radius for `--init`.
- **Cost:** Low — temp git fixtures, no network; bash suite ~30s; Playwright adds ~5–10s after first `npm install`.
- **Speed:** Bash suite remains the PR gate (`make test`); Playwright documents UX stories and duplicates critical paths for T+7 agent reruns.

## Validation

```bash
bash tests/run.sh
npm install && npm test
make ci   # when shellcheck is available
```

## Follow-ups

- Add `npm test` to CI workflow (optional job) after Playwright install is cached.
- JSON escaping fuzz with embedded `\u0000` in git config values (residual risk in `_escape_json_string`).
- Sync dev-master `dex/09-repos/env-doctor` pointer after merge.
