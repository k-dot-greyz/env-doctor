#!/usr/bin/env bash
# Security and boundary tests for env-doctor.sh — run from repo root: bash tests/security.sh
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_DOCTOR="${REPO_DIR}/env-doctor.sh"

# Colors
G=$'\033[32m'; R=$'\033[31m'; RST=$'\033[0m'

PASSED=0
FAILED=0

_assert_equals() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ${G}[PASS]${RST} ${name}"
    PASSED=$((PASSED+1))
  else
    echo "  ${R}[FAIL]${RST} ${name}"
    echo "    Expected: '${expected}'"
    echo "    Actual:   '${actual}'"
    FAILED=$((FAILED+1))
  fi
}

_assert_contains() {
  local name="$1" substring="$2" haystack="$3"
  if [[ "$haystack" == *"$substring"* ]]; then
    echo "  ${G}[PASS]${RST} ${name}"
    PASSED=$((PASSED+1))
  else
    echo "  ${R}[FAIL]${RST} ${name}"
    echo "    Expected to contain: '${substring}'"
    echo "    Actual:             '${haystack}'"
    FAILED=$((FAILED+1))
  fi
}

_assert_not_contains() {
  local name="$1" substring="$2" haystack="$3"
  if [[ "$haystack" != *"$substring"* ]]; then
    echo "  ${G}[PASS]${RST} ${name}"
    PASSED=$((PASSED+1))
  else
    echo "  ${R}[FAIL]${RST} ${name}"
    echo "    Expected NOT to contain: '${substring}'"
    echo "    Actual:                 '${haystack}'"
    FAILED=$((FAILED+1))
  fi
}

# Create a temp workspace for testing
TEST_WS="$(mktemp -d 2>/dev/null || mktemp -d -t 'env_doctor_test')"
trap 'rm -rf "${TEST_WS}"' EXIT

cd "${TEST_WS}"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

# Copy env-doctor.sh to the temp workspace
cp "${ENV_DOCTOR}" ./env-doctor.sh

echo "Running env-doctor security and boundary test suite..."

# ── Test 1: Version ──
echo "Test 1: Version flag"
ver="$(bash ./env-doctor.sh --version)"
_assert_equals "Version is 1.1.0" "1.1.0" "$ver"

# ── Test 2: Invalid Tier Validation ──
echo "Test 2: Invalid tier validation"
if bash ./env-doctor.sh --tier 4 >/dev/null 2>&1; then
  _assert_equals "Tier 4 should fail" "fail" "pass"
else
  _assert_equals "Tier 4 failed as expected" "fail" "fail"
fi

if bash ./env-doctor.sh --tier abc >/dev/null 2>&1; then
  _assert_equals "Tier abc should fail" "fail" "pass"
else
  _assert_equals "Tier abc failed as expected" "fail" "fail"
fi

# ── Test 3: Safe Config Parsing (Arbitrary Code Execution Prevention) ──
echo "Test 3: Safe config parsing"
cat <<'EOF' > .env-doctor.conf
BRAND="Hacked Brand"
# This malicious command should NOT execute
touch HACKED_FILE
ENV_DOCTOR_CORE_REPOS="my-core"
EOF

# Run env-doctor.sh (safe-parse is default)
bash ./env-doctor.sh --quiet 2>/dev/null || true
if [[ -f HACKED_FILE ]]; then
  _assert_equals "Malicious config command executed!" "no HACKED_FILE" "HACKED_FILE exists"
  rm -f HACKED_FILE
else
  _assert_equals "Malicious config command was blocked" "no HACKED_FILE" "no HACKED_FILE"
fi

# ── Test 4: Unsafe Config Sourcing Opt-in ──
echo "Test 4: Unsafe config sourcing opt-in"
# Make sure it sources if we explicitly opt-in with --unsafe-source-config
# (and the file is safe/owned by us)
bash ./env-doctor.sh --unsafe-source-config --quiet 2>/dev/null || true
if [[ -f HACKED_FILE ]]; then
  _assert_equals "Unsafe config command executed with opt-in" "HACKED_FILE exists" "HACKED_FILE exists"
  rm -f HACKED_FILE
else
  _assert_equals "Unsafe config command did not execute with opt-in" "HACKED_FILE exists" "no HACKED_FILE"
fi

# ── Test 5: Secret Redaction ──
echo "Test 5: Secret redaction"
git remote add origin "https://x-access-token:ghp_1234567890abcdefghijklmnopqrstuv@github.com/greyz/env-doctor.git"
out="$(bash ./env-doctor.sh --json)"
_assert_contains "Redacted ghp_ token" "[REDACTED]" "$out"
_assert_not_contains "No raw ghp_ token" "ghp_1234567890" "$out"

# Test GitLab token redaction
git remote set-url origin "https://oauth2:glpat-abcdefghijklmnopqrst@gitlab.com/greyz/env-doctor.git"
out="$(bash ./env-doctor.sh --json)"
_assert_contains "Redacted glpat- token" "[REDACTED]" "$out"
_assert_not_contains "No raw glpat- token" "glpat-abcdef" "$out"

# Test generic user:pass redaction
git remote set-url origin "https://myuser:mypassword@github.com/greyz/env-doctor.git"
out="$(bash ./env-doctor.sh --json)"
_assert_contains "Redacted user:pass" "[REDACTED]" "$out"
_assert_not_contains "No raw password" "mypassword" "$out"

# ── Test 6: Control Character Escaping in JSON ──
echo "Test 6: Control character escaping in JSON"
if command -v python3 &>/dev/null; then
  if python3 -c "import json; json.loads('''$out''')" 2>/dev/null; then
    _assert_equals "JSON is valid" "valid" "valid"
  else
    _assert_equals "JSON is invalid" "valid" "invalid"
  fi
fi

# ── Test 7: SSH-forcing insteadOf does not trigger false poison warning (Bug #51) ──
echo "Test 7: Bug 51 regression — SSH-forcing insteadOf should not emit poison warning"
tmp_gitcfg="$(mktemp)"
# A legitimate SSH-forcing url rewrite: HTTPS → SSH (common developer best practice)
git config --file "$tmp_gitcfg" 'url.git@github.com:.insteadOf' 'https://github.com/'
out_51="$(GIT_CONFIG_GLOBAL="$tmp_gitcfg" bash ./env-doctor.sh --json 2>&1 || true)"
_assert_not_contains "SSH-forcing insteadOf no false poison warn" "poison" "$out_51"
rm -f "$tmp_gitcfg"

# ── Test 8: Bug 57 — _check_python selects highest available Python (not lowest) ──
echo "Test 8: Bug 57 regression — _check_python picks highest available Python when multiple exist"
tmp_pybin_57="$(mktemp -d)"
# Stubs: python3.13 (high, 3.13.0) and python3.11 + python3 (low, 3.11.9), pin=3.14 absent
printf '#!/usr/bin/env bash\necho "Python 3.13.0"\n' > "$tmp_pybin_57/python3.13"
printf '#!/usr/bin/env bash\necho "Python 3.11.9"\n' > "$tmp_pybin_57/python3.11"
printf '#!/usr/bin/env bash\necho "Python 3.11.9"\n' > "$tmp_pybin_57/python3"
chmod +x "$tmp_pybin_57/python3.13" "$tmp_pybin_57/python3.11" "$tmp_pybin_57/python3"
# Need a pyproject.toml so _project_has python is true and _check_python actually runs
echo '[project]' > pyproject.toml
out_57="$(PATH="$tmp_pybin_57:$PATH" bash ./env-doctor.sh --json 2>&1 || true)"
rm -f pyproject.toml
# Fixed: warns with python3.13 (highest/first found in highest-to-lowest loop)
_assert_contains "Bug 57: highest python3.13 selected" '"python (python3.13)"' "$out_57"
# Buggy: would warn with python3 (generic, last loop iteration overwrote python3.13)
_assert_not_contains "Bug 57: generic python3 not selected as best" '"python (python3)"' "$out_57"
rm -rf "$tmp_pybin_57"

echo ""
echo "Test Summary: ${PASSED} passed, ${FAILED} failed."
if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
