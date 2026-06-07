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

echo ""
echo "Test Summary: ${PASSED} passed, ${FAILED} failed."
if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
