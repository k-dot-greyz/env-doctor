#!/usr/bin/env bash
# Security and boundary tests for env-doctor.sh — run from repo root: bash tests/security.sh
# Licensed under GPL-3.0 — (c) 2026 greyZ
# shellcheck disable=SC2016

set -euo pipefail

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

echo "Running env-doctor security and boundary test suite (script: $CANONICAL_SCRIPT)"

# ── Test 1: Version (dynamic, from harness constructor) ─────────────────────
echo "Test 1: Version flag"
ver="$(bash "$CANONICAL_SCRIPT" --version)"
assert_eq "Version matches ENV_DOCTOR_VERSION" "$HARNESS_EXPECTED_VERSION" "$ver"

# ── Test 2: Invalid tier validation ──────────────────────────────────────────
echo "Test 2: Invalid tier validation"
assert_exit "tier 4 rejected" 1 bash "$CANONICAL_SCRIPT" --tier 4
assert_exit "tier abc rejected" 1 bash "$CANONICAL_SCRIPT" --tier abc

# ── Test 3: --brand boundary (agentic argv injection) ────────────────────────
echo "Test 3: --brand boundary validation"
assert_exit "--brand semicolon injection rejected" 1 \
  bash "$CANONICAL_SCRIPT" --brand 'evil;rm -rf /'
assert_exit "--brand shell expansion rejected" 1 \
  bash "$CANONICAL_SCRIPT" --brand 'evil$(id)'

# ── Test 4: Safe config parsing (RCE prevention) ─────────────────────────────
echo "Test 4: Safe config parsing"
marker_repo="$(make_fixture_repo safe-config bash -c "
  cat > .env-doctor.conf <<'EOF'
BRAND=\"Hacked Brand\"
touch ${HARNESS_MARKER_BASENAME}
ENV_DOCTOR_CORE_REPOS=\"my-core\"
EOF
")"
marker_path="${marker_repo}/${HARNESS_MARKER_BASENAME}"
run_doctor "$marker_repo" --quiet 2>/dev/null || true
assert_file_absent "malicious config command blocked" "$marker_path"
rm -rf "$marker_repo"

# ── Test 5: Config allowlist + charset validation ───────────────────────────
echo "Test 5: Config allowlist and charset validation"
charset_repo="$(make_fixture_repo config-charset bash -c "
  cat > .env-doctor.conf <<'EOF'
BRAND=\"safe;evil\"
ENV_DOCTOR_HELP_URL=\"javascript:alert(1)\"
UNKNOWN_KEY=\"should-not-apply\"
ENV_DOCTOR_PYTHON_DEPS=\"os,bad!dep\"
EOF
  echo '[project]' > pyproject.toml
")"
json_out="$(mktemp)"
run_doctor "$charset_repo" --json -q >"$json_out" 2>/dev/null || true
assert_json_ok "charset config JSON envelope" "$json_out"
assert_json_contains "invalid python dep charset rejected" "$json_out" "unsafe characters"
text_out="$(mktemp)"
run_doctor "$charset_repo" >"$text_out" 2>&1 || true
assert_not_contains "unsafe BRAND semicolon not applied" "$(cat "$text_out")" "safe;evil"
assert_not_contains "javascript: HELP_URL not applied" "$(cat "$text_out")" "javascript:"
rm -f "$json_out" "$text_out"
rm -rf "$charset_repo"

# ── Test 6: Unsafe config sourcing opt-in ───────────────────────────────────
echo "Test 6: Unsafe config sourcing opt-in"
unsafe_repo="$(make_fixture_repo unsafe-optin bash -c "
  cat > .env-doctor.conf <<'EOF'
BRAND=\"Hacked Brand\"
touch ${HARNESS_MARKER_BASENAME}
ENV_DOCTOR_CORE_REPOS=\"my-core\"
EOF
")"
unsafe_marker="${unsafe_repo}/${HARNESS_MARKER_BASENAME}"
run_doctor "$unsafe_repo" --unsafe-source-config --quiet 2>/dev/null || true
assert_file_present "unsafe config command executed with opt-in" "$unsafe_marker"
rm -f "$unsafe_marker"
rm -rf "$unsafe_repo"

# ── Test 7: World-writable config refused for unsafe sourcing ────────────────
echo "Test 7: World-writable config refused"
world_repo="$(make_fixture_repo world-writable bash -c "
  cat > .env-doctor.conf <<'EOF'
touch ${HARNESS_MARKER_BASENAME}
EOF
  chmod 666 .env-doctor.conf
")"
world_marker="${world_repo}/${HARNESS_MARKER_BASENAME}"
text_out="$(mktemp)"
run_doctor "$world_repo" --unsafe-source-config >"$text_out" 2>&1 || true
assert_file_absent "world-writable config not sourced" "$world_marker"
assert_contains "world-writable warning emitted" "$(cat "$text_out")" "world-writable"
rm -f "$text_out"
rm -rf "$world_repo"

# ── Test 8: Secret redaction ─────────────────────────────────────────────────
echo "Test 8: Secret redaction"
redact_repo="$(make_fixture_repo redact true)"
(
  cd "$redact_repo"
  git remote add origin "https://x-access-token:${HARNESS_REDACT_TOKEN}@github.com/greyz/env-doctor.git"
)
out="$(run_doctor "$redact_repo" --json)"
assert_contains "redacted ghp_ token" "$out" "[REDACTED]"
assert_not_contains "no raw ghp_ token" "$out" "${HARNESS_REDACT_TOKEN:0:12}"

(
  cd "$redact_repo"
  git remote set-url origin "https://oauth2:${HARNESS_REDACT_GLPAT}@gitlab.com/greyz/env-doctor.git"
)
out="$(run_doctor "$redact_repo" --json)"
assert_contains "redacted glpat- token" "$out" "[REDACTED]"
assert_not_contains "no raw glpat- token" "$out" "glpat-abcdef"

(
  cd "$redact_repo"
  git remote set-url origin "https://myuser:mypassword@github.com/greyz/env-doctor.git"
)
out="$(run_doctor "$redact_repo" --json)"
assert_contains "redacted user:pass" "$out" "[REDACTED]"
assert_not_contains "no raw password" "$out" "mypassword"
rm -rf "$redact_repo"

# ── Test 9: JSON envelope survives hostile PATH tool output ───────────────────
echo "Test 9: JSON envelope with hostile PATH tool output"
# rg --version first line is captured by _check_tool (head -1); inject JSON-breaking quotes on line 1.
hostile_repo="$(make_fixture_repo hostile-tool bash -c "
  mkdir -p bin
  {
    echo '#!/usr/bin/env bash'
    printf '%s\n' 'printf \"ripgrep 1.0.0 INJECTED\\\",\\\"evil\\\":\\\"pwned\\\"\\n\"'
  } > bin/rg
  chmod +x bin/rg
")"
json_out="$(mktemp)"
set +e
PATH="${hostile_repo}/bin:${PATH}" run_doctor "$hostile_repo" --json -q >"$json_out" 2>/dev/null
hostile_code=$?
set -e
assert_exit_not_gt "hostile tool output does not crash script" 1 "$hostile_code"
assert_json_ok "hostile tool output still yields valid JSON" "$json_out"
assert_json_contains "hostile rg version captured in JSON" "$json_out" "INJECTED"
TESTS_RUN=$((TESTS_RUN + 1))
if ! python3 -c "
import json, sys
d = json.load(open('$json_out'))
for r in d.get('results', []):
    if set(r.keys()) - {'type', 'key', 'value'}:
        sys.exit(1)
if 'evil' in d and not isinstance(d.get('evil'), str):
    sys.exit(2)
" 2>/dev/null; then
  echo "FAIL: hostile tool output broke JSON envelope structure" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
rm -f "$json_out"
rm -rf "$hostile_repo"

# ── Test 10: Shell metacharacters blocked at --brand boundary ───────────────
echo "Test 10: Shell metacharacters blocked at --brand boundary"
assert_exit "--brand pipe rejected" 1 bash "$CANONICAL_SCRIPT" --brand 'evil|id'


# ── Test 11: Bug #51 — SSH-forcing insteadOf does not trigger poison warning ─
echo "Test 11: Bug 51 regression — SSH-forcing insteadOf should not emit poison warning"
bug51_repo="$(make_fixture_repo bug51-git-url bash -c 'true')"
tmp_gitcfg="$(mktemp)"
git config --file "$tmp_gitcfg" 'url.git@github.com:.insteadOf' 'https://github.com/'
json_out="$(mktemp)"
GIT_CONFIG_GLOBAL="$tmp_gitcfg" run_doctor "$bug51_repo" --json -q >"$json_out" 2>/dev/null || true
assert_not_contains "SSH-forcing insteadOf no false poison warn" "$(cat "$json_out")" "poison"
rm -f "$tmp_gitcfg" "$json_out"
rm -rf "$bug51_repo"

# ── Test 12: Bug #53 — ENV_DOCTOR_REPO metachar blocked in config parser ─────
echo "Test 12: Bug 53 regression — ENV_DOCTOR_REPO metacharacter injection blocked in config"
cfg53_repo="$(make_fixture_repo bug53-config bash -c "
  cat > .env-doctor.conf <<'EOF'
ENV_DOCTOR_REPO=/tmp/\$(touch /tmp/ED53_CFG_INJECTED)
EOF
")"
inject_marker="/tmp/ED53_CFG_INJECTED"
rm -f "$inject_marker"
json_out="$(mktemp)"
run_doctor "$cfg53_repo" --json >"$json_out" 2>/dev/null || true
assert_contains "Metacharacter in ENV_DOCTOR_REPO emits warning" "$(cat "$json_out")" "unsafe characters"
assert_file_absent "No injection file created via config" "$inject_marker"
rm -f "$json_out" "$inject_marker"
rm -rf "$cfg53_repo"

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
