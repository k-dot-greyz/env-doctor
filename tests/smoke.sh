#!/usr/bin/env bash
# Integration tests for env-doctor.sh — run from repo root: bash tests/smoke.sh
# shellcheck disable=SC2016

set -euo pipefail

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

# Colors
G=$'\033[32m'; RST=$'\033[0m'

echo "env-doctor smoke/integration tests (script: $CANONICAL_SCRIPT)"

# ── CLI / argv ───────────────────────────────────────────────────────────────
assert_exit "--help exits 0" 0 bash "$CANONICAL_SCRIPT" --help
assert_exit "unknown arg exits 1" 1 bash "$CANONICAL_SCRIPT" --not-a-flag

# Combined short flags: -jq should emit JSON only (no banner noise on stdout)
tmp_json="$(mktemp)"
set +e
bash "$CANONICAL_SCRIPT" -jq >"$tmp_json" 2>/dev/null
code=$?
set -e
assert_eq "-jq exit code" "0" "$code"
assert_json_ok "-jq valid JSON" "$tmp_json"
rm -f "$tmp_json"

# ── Generic standalone behavior (submodule scan off by default) ──────────────
generic_repo="$(make_fixture_repo generic true)"
json_out="$(mktemp)"
run_doctor "$generic_repo" --json >"$json_out"
assert_json_ok "generic repo JSON" "$json_out"
assert_json_contains "generic skips submodule scan by default" "$json_out" "scan skipped"
rm -f "$json_out"
rm -rf "$generic_repo"

# ── Submodule scan opt-in ────────────────────────────────────────────────────
sub_repo="$(make_fixture_repo sub-opt-in bash -c '
  mkdir -p vendor/secret
  cat > .gitmodules <<EOF
[submodule "vendor/secret"]
	path = vendor/secret
	url = https://github.com/org/private/repo.git
EOF
')"
json_out="$(mktemp)"
# By default, submodule scan is skipped in generic standalone env-doctor
run_doctor "$sub_repo" --json -q >"$json_out"
assert_json_contains "standalone skips submodule scan by default" "$json_out" "scan skipped"

# With --with-submodules, submodule scan is executed
run_doctor "$sub_repo" --with-submodules --json -q >"$json_out"
if grep -q "scan skipped" "$json_out"; then
  echo "FAIL: --with-submodules should not skip submodule scan" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
else
  echo "  ${G}[PASS]${RST} --with-submodules runs submodule scan"
  TESTS_RUN=$((TESTS_RUN + 1))
fi
rm -f "$json_out"
rm -rf "$sub_repo"

# ── .env placeholder detection ───────────────────────────────────────────────
env_repo="$(make_fixture_repo env-placeholder bash -c '
  echo "API_KEY=mock-key" > .env
  echo "API_KEY=" > env.example
  git add .env env.example
')"
json_out="$(mktemp)"
run_doctor "$env_repo" --json -q >"$json_out"
assert_json_contains ".env mock-key warns" "$json_out" "placeholder"
rm -f "$json_out"
rm -rf "$env_repo"

# ── .env-doctor.conf BRAND (benign sourced config) ───────────────────────────
brand_repo="$(make_fixture_repo brand-conf bash -c 'echo "BRAND=fixture-brand" > .env-doctor.conf')"
text_out="$(mktemp)"
run_doctor "$brand_repo" >"$text_out" 2>&1 || true
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "fixture-brand" "$text_out"; then
  echo "FAIL: .env-doctor.conf BRAND not reflected in banner" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$brand_repo"

# ── Bug 1: ENV_DOCTOR_PYTHON_DEPS injection guard ────────────────────────────
# Trigger: dep name with shell/Python metacharacters must be rejected, not executed.
inj_repo="$(make_fixture_repo py-inject bash -c "
  echo '[project]' > pyproject.toml
  echo \"ENV_DOCTOR_PYTHON_DEPS='os,123evil'\" > .env-doctor.conf
")"
json_out="$(mktemp)"
run_doctor "$inj_repo" --json -q >"$json_out" 2>/dev/null || true
assert_json_contains "invalid python dep name rejected" "$json_out" "invalid import name"
rm -f "$json_out"
rm -rf "$inj_repo"

# Injected Python expression must not execute arbitrary code.
inj_exec_repo="$(make_fixture_repo py-inject-exec bash -c "
  echo '[project]' > pyproject.toml
  echo \"ENV_DOCTOR_PYTHON_DEPS='os;__import__(chr(111)+chr(115)).system(chr(105)+chr(100))'\" > .env-doctor.conf
")"
marker_file="$(mktemp)"
json_out2="$(mktemp)"
INJECT_MARKER="$marker_file" run_doctor "$inj_exec_repo" --json -q >"$json_out2" 2>/dev/null || true
if [[ -s "$marker_file" ]]; then
  echo "FAIL: injection guard did not prevent Python code execution" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
rm -f "$json_out2" "$marker_file"
rm -rf "$inj_exec_repo"

# ── Bug 2: zen --version crash (broken zen binary) ───────────────────────────
# Trigger: a `zen` stub that exits non-zero must not abort the entire run.
zen_repo="$(make_fixture_repo zen-broken bash -c '
  # Create a stub `zen` that fails with exit 1
  mkdir -p bin
  printf "#!/usr/bin/env bash\nexit 1\n" > bin/zen
  chmod +x bin/zen
')"
text_out="$(mktemp)"
set +e
PATH="$zen_repo/bin:$PATH" run_doctor "$zen_repo" -q >"$text_out" 2>&1
zen_code=$?
set -e
# Script must not crash (exit code 0 = no failures, or 1 = failures but no abort)
# The key: we must not get an uncontrolled crash (exit code 141/SIGPIPE etc.)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$zen_code" -gt 1 ]]; then
  echo "FAIL: broken zen crashed env-doctor (exit $zen_code, expected 0 or 1)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$zen_repo"

# ── Bug 3a: Non-Python repo --init dry-run must not attempt pip install -e . ─
# Trigger: repo has only Cargo.toml; running --init --tier 0 --dry-run must exit 0
# and NOT plan `pip install -e .` (which would crash the real run).
rust_repo="$(make_fixture_repo rust-init bash -c 'printf "[package]\nname = \"foo\"\nversion = \"0.1.0\"\n" > Cargo.toml')"
text_out="$(mktemp)"
set +e
export PKG_MANAGER="pip"
run_doctor "$rust_repo" -it0n >"$text_out" 2>&1
rust_code=$?
unset PKG_MANAGER
set -e
assert_eq "non-Python repo --init dry-run exits 0" "0" "$rust_code"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "pip install -e \." "$text_out"; then
  echo "FAIL: non-Python repo dry-run should not plan 'pip install -e .'" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$rust_repo"

# ── Bug 3b: requirements.txt-only repo --init dry-run uses pip install -r ────
# Trigger: Python project with only requirements.txt (no pyproject.toml/setup.py)
# must use 'pip install -r requirements.txt', not 'pip install -e .'.
req_repo="$(make_fixture_repo req-only bash -c 'echo "requests" > requirements.txt')"
text_out="$(mktemp)"
set +e
export PKG_MANAGER="pip"
run_doctor "$req_repo" -it0n >"$text_out" 2>&1
req_code=$?
unset PKG_MANAGER
set -e
assert_eq "requirements.txt-only dry-run exits 0" "0" "$req_code"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "pip install -e \." "$text_out"; then
  echo "FAIL: requirements.txt-only dry-run must not plan 'pip install -e .'" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "requirements.txt" "$text_out"; then
  echo "FAIL: requirements.txt-only dry-run should plan 'pip install -r requirements.txt'" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$req_repo"

# ── Private submodule URL heuristic (--submodules only) ──────────────────────
priv_repo="$(make_fixture_repo private-sub bash -c '
  cat > .gitmodules <<EOF
[submodule "vendor/secret"]
	path = vendor/secret
	url = https://github.com/org/private/repo.git
EOF
')"
text_out="$(mktemp)"
run_doctor "$priv_repo" --submodules >"$text_out" 2>&1 || true
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "private" "$text_out"; then
  echo "FAIL: --submodules should mention private submodule detection" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$priv_repo"

# ── Dry-run init does not require mutating tier-2 submodules ─────────────────
dry_repo="$(make_fixture_repo dry-init bash -c 'echo "[project]" > pyproject.toml')"
text_out="$(mktemp)"
set +e
run_doctor "$dry_repo" -it0n >"$text_out" 2>&1
dry_code=$?
set -e
assert_eq "dry-run tier0 exits 0" "0" "$dry_code"
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "dry-run" "$text_out"; then
  echo "FAIL: -it0n should mention dry-run" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$dry_repo"

# ── MCP placeholder scan (isolated HOME) ─────────────────────────────────────
mcp_home="$(mktemp -d)"
mkdir -p "$mcp_home/.cursor"
printf '%s\n' '{"mcpServers":{"x":{"env":{"KEY":"CHANGE_ME"}}}}' >"$mcp_home/.cursor/mcp.json"
mcp_repo="$(make_fixture_repo mcp-placeholder true)"
json_out="$(mktemp)"
HOME="$mcp_home" run_doctor "$mcp_repo" --json -q >"$json_out"
assert_json_contains "MCP CHANGE_ME placeholder warns" "$json_out" "placeholder"
rm -f "$json_out"
rm -rf "$mcp_repo" "$mcp_home"

# ── Bug 4: color-vars crash before _setup_colors (unbound variable under set -u) ──
# Trigger: invalid chars in ENV_DOCTOR_PYTHON_DEPS env var cause _warn to be called
# from _bootstrap_env before _setup_colors runs, crashing with "Y: unbound variable".
# After the fix: script must emit a warning and continue (exit 0 or 1, never >1).
color_repo="$(make_fixture_repo color-crash true)"
text_out="$(mktemp)"
set +e
ENV_DOCTOR_PYTHON_DEPS='invalid!dep' run_doctor "$color_repo" >"$text_out" 2>&1
color_code=$?
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$color_code" -gt 1 ]]; then
  echo "FAIL: invalid ENV_DOCTOR_PYTHON_DEPS crashed env-doctor (exit $color_code, expected 0 or 1)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "unsafe characters" "$text_out"; then
  echo "FAIL: invalid ENV_DOCTOR_PYTHON_DEPS should warn about unsafe characters" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$color_repo"

# Same crash path via ENV_DOCTOR_CORE_REPOS with shell metacharacters.
core_repo="$(make_fixture_repo core-crash true)"
text_out="$(mktemp)"
set +e
ENV_DOCTOR_CORE_REPOS='repo;malicious' run_doctor "$core_repo" >"$text_out" 2>&1
core_code=$?
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$core_code" -gt 1 ]]; then
  echo "FAIL: invalid ENV_DOCTOR_CORE_REPOS crashed env-doctor (exit $core_code, expected 0 or 1)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "unsafe characters" "$text_out"; then
  echo "FAIL: invalid ENV_DOCTOR_CORE_REPOS should warn about unsafe characters" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$core_repo"

# Same crash path via malformed .env-doctor.conf.
conf_crash_repo="$(make_fixture_repo conf-crash bash -c "echo 'ENV_DOCTOR_PYTHON_DEPS=bad!chars' > .env-doctor.conf")"
text_out="$(mktemp)"
set +e
run_doctor "$conf_crash_repo" >"$text_out" 2>&1
conf_code=$?
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$conf_code" -gt 1 ]]; then
  echo "FAIL: malformed .env-doctor.conf crashed env-doctor (exit $conf_code, expected 0 or 1)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -qi "unsafe characters" "$text_out"; then
  echo "FAIL: malformed .env-doctor.conf should warn about unsafe characters" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$conf_crash_repo"

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
