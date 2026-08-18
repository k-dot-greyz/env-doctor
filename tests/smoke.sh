#!/usr/bin/env bash
# Integration tests for env-doctor.sh — run from repo root: bash tests/smoke.sh
# shellcheck disable=SC2016

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

_setup_test_python314

# Colors
G=$'\033[32m'; RST=$'\033[0m'

echo "env-doctor smoke/integration tests (script: $CANONICAL_SCRIPT)"

# ── CLI / argv ───────────────────────────────────────────────────────────────
assert_exit "--help exits 0" 0 bash "$CANONICAL_SCRIPT" --help
assert_exit "unknown arg exits 1" 1 bash "$CANONICAL_SCRIPT" --not-a-flag
assert_exit "--safety exits 0" 0 bash "$CANONICAL_SCRIPT" --safety
assert_exit "--about exits 0" 0 bash "$CANONICAL_SCRIPT" --about
assert_exit "--print-config-template exits 0" 0 bash "$CANONICAL_SCRIPT" --print-config-template
assert_exit "--print-agent-template exits 0" 0 bash "$CANONICAL_SCRIPT" --print-agent-template

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

# ── Bug 5: venv activation crashes on Windows (Scripts/ layout vs bin/) ──────
# Trigger: native Windows Python creates .venv/Scripts/activate, not .venv/bin/activate.
# Running --init after the Windows commit would crash with "No such file or directory"
# from `source .venv/bin/activate` under set -e.
# Fix: _venv_activate() probes Scripts/activate first, then bin/activate.
# Simulate on Linux: build a real venv, move activate to Scripts/, remove from bin/.
_make_venv() {
  local dest="$1"
  if python3 -m venv "$dest" 2>/dev/null; then
    return 0
  fi
  rm -rf "$dest"
  local _venv_bin
  _venv_bin="$(command -v virtualenv 2>/dev/null || echo "$HOME/.local/bin/virtualenv")"
  if [[ -x "$_venv_bin" ]]; then
    "$_venv_bin" "$dest" --quiet 2>/dev/null
    return 0
  fi
  return 1
}

_make_scripts_layout_venv() {
  local dest="$1" bindir
  _make_venv "$dest" || return 1
  bindir="${dest:?}/bin"
  if [[ -f "$bindir/activate" ]]; then
    mkdir -p "${dest:?}/Scripts"
    for entry in activate python python3 pip; do
      [[ -f "$bindir/$entry" ]] && cp "$bindir/$entry" "${dest:?}/Scripts/$entry"
    done
    rm -rf "$bindir"
  fi
}

win_venv_repo="$(make_fixture_repo win-venv-activate bash -c 'echo "# no deps" > requirements.txt')"
if _make_scripts_layout_venv "$win_venv_repo/.venv"; then
  text_out="$(mktemp)"
  set +e
  PKG_MANAGER=pip run_doctor "$win_venv_repo" --init >"$text_out" 2>&1
  win_code=$?
  set -e
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$win_code" -ne 0 ]]; then
    echo "FAIL: --init with Scripts-layout venv failed (exit $win_code, expected 0) — venv activation did not fall back to Scripts/activate" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "Unexpected script failure" "$text_out"; then
    echo "FAIL: --init with Scripts-layout venv hit unexpected error (likely venv activation crash)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -f "$text_out"
else
  echo "  [info] skipping Scripts-layout venv test (no venv tool available)"
fi
rm -rf "$win_venv_repo"

# ── Bug 6: Phase 2 python/tool discovery on Windows Scripts/ layout ─────────
py_scripts_repo="$(make_fixture_repo py-scripts-layout bash -c "
  echo '[project]' > pyproject.toml
  echo \"ENV_DOCTOR_PYTHON_DEPS='os'\" > .env-doctor.conf
")"
if _make_scripts_layout_venv "$py_scripts_repo/.venv"; then
  json_out="$(mktemp)"
  run_doctor "$py_scripts_repo" --json -q >"$json_out"
  assert_json_contains "Scripts-layout venv python resolves for dep check" "$json_out" "all importable"
  rm -f "$json_out"
else
  echo "  [info] skipping Scripts-layout Phase 2 test (no venv tool available)"
fi
rm -rf "$py_scripts_repo"

# ── Bug 7: missing activate script reports clearly (no generic trap) ─────────
broken_venv_repo="$(make_fixture_repo broken-venv bash -c 'echo "# no deps" > requirements.txt')"
mkdir -p "$broken_venv_repo/.venv"
text_out="$(mktemp)"
set +e
PKG_MANAGER=pip run_doctor "$broken_venv_repo" --init >"$text_out" 2>&1
broken_code=$?
set -e
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "no activate script" "$text_out"; then
  echo "FAIL: broken venv should report missing activate script clearly" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "Unexpected script failure" "$text_out"; then
  echo "FAIL: broken venv should not hit generic error trap" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$broken_code" -eq 0 ]]; then
  echo "FAIL: broken venv --init should fail (exit $broken_code, expected non-zero)" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$text_out"
rm -rf "$broken_venv_repo"

# ── Bug: _check_python min — installed Python meeting minimum should PASS ─────
# Regression for: fallback selection picked the lowest available Python because
# loop order was used instead of comparing reported versions.
if command -v python3 &>/dev/null; then
  current_py_ver="$(python3 --version 2>&1 | awk '{print $2}')"
  current_py_minor="$(echo "$current_py_ver" | cut -d. -f2)"
  pin_repo="$(make_fixture_repo py-min-pass bash -c 'echo "[project]" > pyproject.toml')"
  json_out="$(mktemp)"
  ENV_DOCTOR_MIN_PYTHON_MINOR="$current_py_minor" run_doctor "$pin_repo" --json -q >"$json_out" 2>/dev/null || true
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! python3 -c "
import json, sys
d = json.load(open('$json_out'))
for row in d.get('results', []):
    if row.get('type') == 'pass' and 'python' in row.get('key',''):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "FAIL: python meeting ENV_DOCTOR_MIN_PYTHON_MINOR should emit a [PASS]" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  rm -f "$json_out"
  rm -rf "$pin_repo"
fi

# ── Bug: _check_python must pick highest version, not first loop match ────────
# When python3 reports a newer version than an earlier versioned binary (e.g.
# python3=3.15 while python3.12 exists but python3.15 is not in the candidate
# list), BEST_PYTHON must follow the reported version, not loop order.
py_best_repo="$(make_fixture_repo py-best-version bash -c 'echo "[project]" > pyproject.toml')"
py_stub_dir="$(mktemp -d)"
mkdir -p "$py_stub_dir/bin"
cat >"$py_stub_dir/bin/python3.12" <<'PYSTUB'
#!/usr/bin/env bash
[[ "${1:-}" == "--version" ]] && { echo "Python 3.12.0"; exit 0; }
exit 1
PYSTUB
cat >"$py_stub_dir/bin/python3" <<'PYSTUB'
#!/usr/bin/env bash
[[ "${1:-}" == "--version" ]] && { echo "Python 3.15.0"; exit 0; }
exit 1
PYSTUB
chmod +x "$py_stub_dir/bin/"*
json_out="$(mktemp)"
PATH="$py_stub_dir/bin:/usr/bin:/bin" ENV_DOCTOR_MIN_PYTHON_MINOR=14 run_doctor "$py_best_repo" --json -q >"$json_out" 2>/dev/null || true
TESTS_RUN=$((TESTS_RUN + 1))
if ! python3 -c "
import json, sys
d = json.load(open('$json_out'))
for row in d.get('results', []):
    if 'python' in row.get('key','') and '3.15' in row.get('value',''):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  echo "FAIL: _check_python should pick python3 (3.15) over python3.12 when newer" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$json_out"
rm -rf "$py_best_repo" "$py_stub_dir"

# ── Bug: _check_github_git_urls — IFS= broke key/val split (false positive) ──
# SSH-forcing override url.git@github.com:.insteadOf https://github.com/ is a
# common legitimate config.  With IFS=, the whole line ended up in $key and
# "https://github.com" (from the value) triggered a false "poison" warning.
# After the fix, no warning should appear for this config.
git_urls_repo="$(make_fixture_repo git-url-no-fp bash -c 'true')"
tmp_global_cfg="$(mktemp)"
cat >"$tmp_global_cfg" <<'GITCFG'
[user]
	name = Test
	email = test@example.com
[url "git@github.com:"]
	insteadOf = https://github.com/
GITCFG
json_out="$(mktemp)"
GIT_CONFIG_GLOBAL="$tmp_global_cfg" run_doctor "$git_urls_repo" --json -q >"$json_out" 2>/dev/null || true
TESTS_RUN=$((TESTS_RUN + 1))
if python3 -c "
import json, sys
d = json.load(open('$json_out'))
for row in d.get('results', []):
    if 'poison' in row.get('value','').lower():
        sys.exit(1)
" 2>/dev/null; then
  : # no poison warning — expected
else
  echo "FAIL: SSH-forcing git url override should NOT trigger 'HTTPS override poison' warning" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$json_out" "$tmp_global_cfg"
rm -rf "$git_urls_repo"

# Real HTTPS-forcing override (genuine poison) MUST warn.
git_urls_poison_repo="$(make_fixture_repo git-url-poison bash -c 'true')"
tmp_poison_cfg="$(mktemp)"
cat >"$tmp_poison_cfg" <<'GITCFG'
[user]
	name = Test
	email = test@example.com
[url "https://github.com/"]
	insteadOf = git@github.com:
GITCFG
json_out="$(mktemp)"
GIT_CONFIG_GLOBAL="$tmp_poison_cfg" run_doctor "$git_urls_poison_repo" --json -q >"$json_out" 2>/dev/null || true
TESTS_RUN=$((TESTS_RUN + 1))
if python3 -c "
import json, sys
d = json.load(open('$json_out'))
for row in d.get('results', []):
    if 'poison' in row.get('value','').lower():
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  : # poison warning found — expected
else
  echo "FAIL: HTTPS-forcing git url override should trigger 'HTTPS override poison' warning" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$json_out" "$tmp_poison_cfg"
rm -rf "$git_urls_poison_repo"

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
