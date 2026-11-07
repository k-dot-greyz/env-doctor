#!/usr/bin/env bash
# zenclip-bugcard/1 contract + redaction policy (PR #41 agents_ram blueprint).
# User stories:
#   US-Z1 happy — sample-bugcard.json validates
#   US-Z2 sad  — agentic extra top-level property rejected
#   US-Z3 sad  — path-shaped report_id rejected
#   US-Z4 sad  — wrong schema const rejected
#   US-Z5 security — gh token in hydration record fails export policy
#   US-Z6 sad  — absolute artifact path rejected
# Licensed under GPL-3.0 — (c) 2026 greyZ

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/helpers.sh
source "$(cd "$SCRIPT_DIR/.." && pwd)/helpers.sh"

REPO_ROOT="${REPO_ROOT:-$HARNESS_REPO_ROOT}"
VALIDATOR="$SCRIPT_DIR/lib/validate_bugcard.py"
SAMPLE="$REPO_ROOT/agents_ram/zenclip-bug-forensics/examples/sample-bugcard.json"
FIXTURES="$SCRIPT_DIR/fixtures"

echo "Running zenclip bugcard contract suite (validator: $VALIDATOR)"

assert_validator_ok() {
  local msg="$1"
  local file="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e
  local out
  out="$(python3 "$VALIDATOR" "$file" "$@" 2>&1)"
  local code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    echo "FAIL: $msg (expected success, got $code: $out)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_validator_fail() {
  local msg="$1"
  local file="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e
  python3 "$VALIDATOR" "$file" "$@" >/dev/null 2>&1
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    echo "FAIL: $msg (expected validation failure)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ── US-Z1: sample card is canonical happy path ──────────────────────────────
assert_validator_ok "US-Z1 sample bugcard validates" "$SAMPLE" --policy

# ── US-Z2: agentic injection via extra property ─────────────────────────────
assert_validator_fail "US-Z2 extra agent_instruction property rejected" \
  "$FIXTURES/hostile-extra-property.json"

# ── US-Z3: naive store path traversal via report_id ─────────────────────────
assert_validator_fail "US-Z3 path-shaped report_id rejected" \
  "$FIXTURES/hostile-report-id.json"

# ── US-Z4: schema version mismatch ───────────────────────────────────────────
assert_validator_fail "US-Z4 wrong schema const rejected" \
  "$FIXTURES/hostile-wrong-schema.json"

# ── US-Z5: export policy blocks gh token in records (schema alone would pass) ─
assert_validator_fail "US-Z5 gh token in hydration fails export policy" \
  "$FIXTURES/hostile-gh-token-in-record.json" --policy

TESTS_RUN=$((TESTS_RUN + 1))
if python3 "$VALIDATOR" "$FIXTURES/hostile-gh-token-in-record.json" 2>/dev/null; then
  : # structural validation should pass without --policy
else
  echo "FAIL: US-Z5a hostile token card should pass structural validation without policy" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ── US-Z6: absolute paths in artifacts ───────────────────────────────────────
ABS_FIXTURE="$(mktemp)"
trap 'rm -f "$ABS_FIXTURE"' EXIT
python3 - <<'PY' "$SAMPLE" "$ABS_FIXTURE"
import json, sys
from pathlib import Path
doc = json.loads(Path(sys.argv[1]).read_text())
doc["artifacts"][0]["path"] = "/home/user/.ssh/id_rsa"
Path(sys.argv[2]).write_text(json.dumps(doc, indent=2))
PY
assert_validator_fail "US-Z6 absolute artifact path rejected" "$ABS_FIXTURE"

# ── DX: agents_ram zenclip blueprint files present ───────────────────────────
for rel in \
  "agents_ram/README.md" \
  "agents_ram/zenclip-bug-forensics/README.md" \
  "agents_ram/zenclip-bug-forensics/TRUST_TOUCHPOINTS.md" \
  "agents_ram/zenclip-bug-forensics/schemas/zenclip-bugcard-1.schema.json" \
  "agents_ram/zenclip-bug-forensics/tasks.md"; do
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -f "$REPO_ROOT/$rel" ]]; then
    echo "FAIL: agents_ram blueprint missing $rel" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
done

# ── Graceful ablation: tasks.md lists gate tests for future zenclip CLI ────────
TASKS="$REPO_ROOT/agents_ram/zenclip-bug-forensics/tasks.md"
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q 'tests/zenclip/redact-secrets.sh' "$TASKS"; then
  echo "FAIL: tasks.md must reference G1 redact-secrets gate" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
