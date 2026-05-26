#!/usr/bin/env bash
# Integration tests for env-doctor.sh — run from repo root: bash tests/run.sh

set -euo pipefail

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

echo "env-doctor tests (script: $CANONICAL_SCRIPT)"

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

# ── Generic profile (no dex monorepo markers) ────────────────────────────────
generic_repo="$(make_fixture_repo generic true)"
json_out="$(mktemp)"
run_doctor "$generic_repo" --json --skip-submodules >"$json_out"
assert_json_ok "generic repo JSON" "$json_out"
assert_json_contains "generic skips submodule scan" "$json_out" "scan skipped"
rm -f "$json_out"
rm -rf "$generic_repo"

# ── dev-master profile auto-detect ───────────────────────────────────────────
dm_repo="$(make_fixture_repo dev-master bash -c '
  mkdir -p dex/09-repos/demo
  cat > .gitmodules <<EOF
[submodule "dex/09-repos/demo"]
	path = dex/09-repos/demo
	url = https://github.com/example/demo.git
EOF
')"
json_out="$(mktemp)"
run_doctor "$dm_repo" --json -q >"$json_out"
assert_json_ok "dev-master-like JSON" "$json_out"
# Submodule scan should run (not the generic skip message as the only submodules line)
if grep -q "scan skipped" "$json_out"; then
  echo "FAIL: dev-master-like repo should not skip submodule scan by default" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
fi
rm -f "$json_out"
rm -rf "$dm_repo"

# ── Profile override ─────────────────────────────────────────────────────────
dm_repo="$(make_fixture_repo dm-override bash -c '
  mkdir -p dex/09-repos/demo
  echo "[submodule \"dex/09-repos/demo\"]" > .gitmodules
  echo "	path = dex/09-repos/demo" >> .gitmodules
  echo "	url = https://github.com/example/demo.git" >> .gitmodules
')"
json_out="$(mktemp)"
run_doctor "$dm_repo" --profile generic --json -q >"$json_out"
assert_json_contains "profile generic forces submodule skip" "$json_out" "scan skipped"
rm -f "$json_out"
rm -rf "$dm_repo"

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

# ── ENV_DOCTOR_PYTHON_DEPS injection guard ─────────────────────────────────
inj_repo="$(make_fixture_repo py-inject bash -c "
  echo '[project]' > pyproject.toml
  echo \"ENV_DOCTOR_PYTHON_DEPS='os;evil'\" > .env-doctor.conf
")"
json_out="$(mktemp)"
run_doctor "$inj_repo" --json -q >"$json_out" 2>/dev/null || true
assert_json_contains "invalid python dep name rejected" "$json_out" "invalid import name"
rm -f "$json_out"
rm -rf "$inj_repo"

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

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
