# Test coverage decision log — 2026-08-18 (agentic-security-test-coverage-2a7b)

## Trigger

CI failure on PR #17 (`greyzxcursor/critical-correctness-bugs-208f`) — 3 failed checks:
- Shellcheck & Bash Tests (ubuntu + macos): `python pin match` regression + `security.sh` helper typos
- Playwright UX & security: exit code 1 on Python 3.14 floor without native 3.14

## Root cause

Merge of `main` into correctness branch overwrote `_check_python` pin logic (d26c7df) with min-minor-only checks (84d644c). Tests from both branches landed without the merged production behavior.

Secondary: `security.sh` used `_assert_*` helpers that do not exist; Bug #51/#53 tests wrote to repo root instead of fixtures.

## Attack surface (scoped)

| Surface | Risk | Coverage |
|---------|------|----------|
| `ENV_DOCTOR_PYTHON_PIN` explicit override | Agent pins wrong Python; stub passes min floor instead of pin | Explicit pin mode: only pin-prefix match passes; min floor ignored when pin set |
| `ENV_DOCTOR_PYTHON_PIN` in config | Injection via config file | Allowlisted with `major.minor` charset validation |
| Playwright on 3.12 CI runners | False CI red on pyproject fixtures | `playwright-harness.ts` python3.14 stub (mirrors bash `_setup_test_python314`) |
| Bug #51 git url poison false positive | Agent misconfigures git | Fixture-isolated `GIT_CONFIG_GLOBAL` SSH-forcing test |
| Bug #53 config metachar | RCE via profile hydration path | Fixture `.env-doctor.conf` + absent inject marker |

**Deferred:** JSON fuzz with embedded null bytes in git config; live `brew install` consent gates.

## Tests added / updated

| File | Change |
|------|--------|
| `env-doctor.sh` | Restored pin + min_minor merged `_check_python`; `ENV_DOCTOR_PYTHON_PIN` allowlist |
| `tests/security.sh` | Fixed `assert_*` helpers; Bug #51/#53 use fixtures (no repo-root pollution) |
| `tests/playwright-harness.ts` | Constructor-injected harness: py314 stub, `runDoctor` via spawnSync |
| `tests/ux-agent-flow.spec.ts` | Uses harness; asserts exit codes on agent flows |
| `tests/security-boundary.spec.ts` | Uses harness; non-throwing runner for boundary checks |

## Impact vs cost

- **Impact:** High — unblocks CI on correctness + security PRs; restores agent pin semantics for `ENV_DOCTOR_PYTHON_PIN`.
- **Cost:** Low — no network; bash ~70s; Playwright ~10s after `npm ci`.
- **Speed:** Same CI gates; harness reusable for T+7 agent reruns.

## Validation

```bash
make lint && make test
npm ci && npm run test:pw
```

All passed locally (ubuntu 24.04, Python 3.12 host + py314 stub).

## Follow-ups

- Add `ENV_DOCTOR_PYTHON_PIN` to `.env-doctor.conf.example` and `docs/README.md`
- CI matrix job with native Python 3.14 (no stub) per issue #11
- Pin-match unit test in Playwright for explicit `ENV_DOCTOR_PYTHON_PIN` env override
