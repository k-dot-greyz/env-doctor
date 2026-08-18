#!/usr/bin/env bash
# Ubuntu/Linux hydration tests for env-doctor — run via tests/run.sh
# shellcheck disable=SC2016

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

_setup_test_python314

echo "env-doctor ubuntu-hydration tests (script: $CANONICAL_SCRIPT)"

# ── --print-profile-template exits 0 ─────────────────────────────────────────
assert_exit "--print-profile-template exits 0" 0 bash "$CANONICAL_SCRIPT" --print-profile-template

# ── Profile template contains hydration markers ──────────────────────────────
profile_out="$(mktemp)"
bash "$CANONICAL_SCRIPT" --print-profile-template >"$profile_out"
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "env-doctor hydrate" "$profile_out"; then
  echo "FAIL: --print-profile-template missing hydration markers" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$profile_out"

# ── Tier 3 dry-run mentions PATH hydration ───────────────────────────────────
dry_repo="$(make_fixture_repo tier3-dry bash -c 'echo "[project]" > pyproject.toml')"
text_out="$(mktemp)"
set +e
run_doctor "$dry_repo" -it3n >"$text_out" 2>&1
dry_code=$?
set -e
assert_eq "tier 3 dry-run exits 0" "0" "$dry_code"
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "PATH\|hydrate\|docker" "$text_out"; then
  echo "FAIL: tier 3 dry-run should mention PATH or Docker planning" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$dry_repo"

# ── compose.yaml discovery (tier 3 dry-run) ──────────────────────────────────
compose_repo="$(make_fixture_repo compose-yaml bash -c 'printf "services:\n  web:\n    image: nginx\n" > compose.yaml')"
text_out="$(mktemp)"
run_doctor "$compose_repo" -it3n >"$text_out" 2>&1 || true
if command -v docker &>/dev/null; then
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -qi "compose" "$text_out"; then
    echo "FAIL: tier 3 dry-run should detect compose.yaml" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
else
  echo "  [info] skipping compose discovery test (docker not installed)"
fi
rm -f "$text_out"
rm -rf "$compose_repo"

# ── Persistent PATH: no write without --yes ──────────────────────────────────
persist_repo="$(make_fixture_repo persist-no-yes bash -c '
  echo "ENV_DOCTOR_PERSIST_PATH=true" > .env-doctor.conf
  echo "[project]" > pyproject.toml
')"
fake_home="$(mktemp -d)"
touch "$fake_home/.bashrc"
text_out="$(mktemp)"
set +e
HOME="$fake_home" run_doctor "$persist_repo" -it3 >"$text_out" 2>&1
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "env-doctor hydrate" "$fake_home/.bashrc" 2>/dev/null; then
  echo "FAIL: tier 3 without --yes should not write profile hydration block" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$persist_repo" "$fake_home"

# ── Persistent PATH: idempotent with --yes (temp HOME) ───────────────────────
persist_yes_repo="$(make_fixture_repo persist-yes bash -c '
  echo "ENV_DOCTOR_PERSIST_PATH=true" > .env-doctor.conf
  echo "# no deps" > requirements.txt
')"
# Minimal venv so tier 0 does not abort before tier 3 PATH persistence
mkdir -p "$persist_yes_repo/.venv/bin"
printf '%s\n' '# stub venv activate' >"$persist_yes_repo/.venv/bin/activate"
fake_home2="$(mktemp -d)"
touch "$fake_home2/.bashrc"
text_out="$(mktemp)"
set +e
HOME="$fake_home2" PKG_MANAGER=pip run_doctor "$persist_yes_repo" -it3y >"$text_out" 2>&1
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "env-doctor hydrate" "$fake_home2/.bashrc" 2>/dev/null; then
  echo "FAIL: tier 3 with --yes should write profile hydration block" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
count=0
count="$(grep -c "env-doctor hydrate" "$fake_home2/.bashrc" 2>/dev/null)" || count=0
if [[ "$count" -gt 2 ]]; then
  echo "FAIL: profile hydration block should be idempotent (found $count markers)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$persist_yes_repo" "$fake_home2"

# ── env-config.sh install/uninstall (temp HOME) ─────────────────────────────
if [[ -x "$REPO_ROOT/scripts/env-config.sh" ]]; then
  cfg_home="$(mktemp -d)"
  touch "$cfg_home/.bashrc"
  ENV_DOCTOR_REPO="$REPO_ROOT" HOME="$cfg_home" bash "$REPO_ROOT/scripts/env-config.sh" install
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! grep -q "env-doctor boot audit" "$cfg_home/.bashrc"; then
    echo "FAIL: env-config.sh install should add boot audit snippet" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  ENV_DOCTOR_REPO="$REPO_ROOT" HOME="$cfg_home" bash "$REPO_ROOT/scripts/env-config.sh" uninstall
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "env-doctor boot audit" "$cfg_home/.bashrc" 2>/dev/null; then
    echo "FAIL: env-config.sh uninstall should remove boot audit snippet" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -rf "$cfg_home"
else
  echo "  [info] skipping env-config.sh test (script not found)"
fi

# ── _tool_present semantics: rg counts as ripgrep ────────────────────────────
# Indirect test: tier 2 dry-run should not plan ripgrep install when rg is on PATH
rg_repo="$(make_fixture_repo rg-present bash -c 'echo "[project]" > pyproject.toml')"
text_out="$(mktemp)"
PATH="$(dirname "$(command -v rg 2>/dev/null || echo /nonexistent)"):${PATH}"
if command -v rg &>/dev/null; then
  run_doctor "$rg_repo" -it2n >"$text_out" 2>&1 || true
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -qi "apt install ripgrep\|brew install ripgrep" "$text_out"; then
    echo "FAIL: tier 2 dry-run should not plan ripgrep when rg is present" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
else
  echo "  [info] skipping rg-present test (rg not installed)"
fi
rm -f "$text_out"
rm -rf "$rg_repo"


# ── Bug #53 regression: ENV_DOCTOR_REPO metachar blocked by runtime guard ────
metachar_repo="$(make_fixture_repo metachar-inject bash -c '
  echo "ENV_DOCTOR_PERSIST_PATH=true" > .env-doctor.conf
  echo "# no deps" > requirements.txt
')"
mkdir -p "$metachar_repo/.venv/bin"
printf '%s\n' '# stub' >"$metachar_repo/.venv/bin/activate"
fake_home_mc="$(mktemp -d)"
touch "$fake_home_mc/.bashrc"
text_out_mc="$(mktemp)"
set +e
# ENV_DOCTOR_REPO passed as env var — bypasses _load_config; runtime guard must catch it
ENV_DOCTOR_REPO='/tmp/$(touch /tmp/ED53_RUNTIME_INJECTED)' \
  HOME="$fake_home_mc" PKG_MANAGER=pip \
  run_doctor "$metachar_repo" -it3y >"$text_out_mc" 2>&1
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "unsafe characters" "$text_out_mc"; then
  echo "FAIL: metachar in ENV_DOCTOR_REPO (env var) should emit 'unsafe characters' warning" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if [[ -f /tmp/ED53_RUNTIME_INJECTED ]]; then
  echo "FAIL: ENV_DOCTOR_REPO shell injection was not blocked by runtime guard (file created)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q '\$(touch' "$fake_home_mc/.bashrc" 2>/dev/null; then
  echo "FAIL: runtime injection payload written to bashrc" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out_mc" /tmp/ED53_RUNTIME_INJECTED
rm -rf "$metachar_repo" "$fake_home_mc"

# ── Bug #53 regression: env-config.sh rejects metachar ENV_DOCTOR_REPO ───────
if [[ -x "$REPO_ROOT/scripts/env-config.sh" ]]; then
  fake_home_cfgmc="$(mktemp -d)"
  touch "$fake_home_cfgmc/.bashrc"
  cfgmc_exit=0
  set +e
  ENV_DOCTOR_REPO='/tmp/$(touch /tmp/ED53_CFGSCRIPT_INJECTED)' HOME="$fake_home_cfgmc" \
    bash "$REPO_ROOT/scripts/env-config.sh" install >/dev/null 2>&1
  cfgmc_exit=$?
  set -e
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$cfgmc_exit" -eq 0 ]]; then
    echo "FAIL: env-config.sh with metachar ENV_DOCTOR_REPO should exit non-zero" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -f /tmp/ED53_CFGSCRIPT_INJECTED ]]; then
    echo "FAIL: env-config.sh metachar injection was not blocked (file created)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -rf "$fake_home_cfgmc" /tmp/ED53_CFGSCRIPT_INJECTED
fi

echo ""
echo "ubuntu-hydration: ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
