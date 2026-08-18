#!/usr/bin/env bash
# Shared helpers for env-doctor integration tests (deterministic, no network).

set -euo pipefail

# shellcheck source=tests/harness-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/harness-config.sh"
init_harness

REPO_ROOT="$HARNESS_REPO_ROOT"
export REPO_ROOT
CANONICAL_SCRIPT="$HARNESS_SCRIPT"

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
  local msg="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $msg (expected=$expected actual=$actual)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_exit() {
  local msg="$1" expected_code="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e
  "$@" >/dev/null 2>&1
  local code=$?
  set -e
  if [[ "$code" -ne "$expected_code" ]]; then
    echo "FAIL: $msg (expected exit $expected_code, got $code)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_json_ok() {
  local msg="$1" json_file="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
    echo "FAIL: $msg (invalid JSON in $json_file)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return
  fi
  python3 -c "
import json, sys
d = json.load(open('$json_file'))
for k in ('results', 'issues', 'warnings', 'ok'):
    if k not in d:
        print('FAIL: $msg missing key', k, file=sys.stderr)
        sys.exit(1)
" || TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_json_contains() {
  local msg="$1" json_file="$2" needle="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ! python3 -c "
import json, sys
raw = json.dumps(json.load(open('$json_file')))
if '''$needle''' not in raw:
    sys.exit(1)
" 2>/dev/null; then
    echo "FAIL: $msg (JSON missing substring: $needle)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Copy env-doctor into an isolated git repo so REPO_ROOT resolves to the fixture.
make_fixture_repo() {
  local name="$1"
  shift
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/${HARNESS_FIXTURE_PREFIX}-${name}-XXXXXX")"
  cp "$CANONICAL_SCRIPT" "$dir/env-doctor.sh"
  chmod +x "$dir/env-doctor.sh"
  (
    cd "$dir"
    git init -q
    git config user.email "$HARNESS_GIT_USER_EMAIL"
    git config user.name "$HARNESS_GIT_USER_NAME"
    "$@"
    git add -A
    git commit -q -m "fixture $name" --allow-empty 2>/dev/null || git commit -q -m "fixture $name"
  )
  printf '%s' "$dir"
}

assert_contains() {
  local msg="$1" haystack="$2" needle="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $msg (expected substring: $needle)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_not_contains() {
  local msg="$1" haystack="$2" needle="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "FAIL: $msg (unexpected substring: $needle)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_exit_not_gt() {
  local msg="$1" max_code="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$actual" -gt "$max_code" ]]; then
    echo "FAIL: $msg (exit $actual > max $max_code)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_absent() {
  local msg="$1" path="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -e "$path" ]]; then
    echo "FAIL: $msg (unexpected file: $path)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_present() {
  local msg="$1" path="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -e "$path" ]]; then
    echo "FAIL: $msg (missing file: $path)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

run_doctor() {
  local repo="$1"
  shift
  (
    cd "$repo"
    bash ./env-doctor.sh "$@"
  )
}

# Stub python3.14 on PATH for tests that require the 3.14+ floor on hosts without it.
# Reports 3.14.0 for --version only; all other invocations delegate to host python3.
# Do NOT use this stub to validate Python 3.14-specific semantics.
_setup_test_python314() {
  local stub_dir
  stub_dir="$(mktemp -d "${TMPDIR:-/tmp}/env-doctor-py314-stub-XXXXXX")"
  export ENV_DOCTOR_PY314_STUB_DIR="$stub_dir"
  trap '[[ -n "${ENV_DOCTOR_PY314_STUB_DIR:-}" ]] && rm -rf "$ENV_DOCTOR_PY314_STUB_DIR"' EXIT
  cat >"$stub_dir/python3.14" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "Python 3.14.0"
  exit 0
fi
if [[ "${1:-}" == "-m" && "${2:-}" == "venv" ]]; then
  rm -rf "${@:3}" 2>/dev/null || true
  if python3 -m venv "${@:3}" 2>/dev/null; then
    exit 0
  fi
  rm -rf "${@:3}" 2>/dev/null || true
  if command -v virtualenv &>/dev/null; then
    virtualenv "${@:3}" --quiet 2>/dev/null
    exit $?
  fi
  exit 1
fi
exec python3 "$@"
STUB
  chmod +x "$stub_dir/python3.14"
  export PATH="$stub_dir:${PATH}"
}
