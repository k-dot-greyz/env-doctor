#!/usr/bin/env bash
# Shared helpers for env-doctor integration tests (deterministic, no network).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
CANONICAL_SCRIPT="$REPO_ROOT/env-doctor.sh"

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
  dir="$(mktemp -d "${TMPDIR:-/tmp}/env-doctor-${name}-XXXXXX")"
  cp "$CANONICAL_SCRIPT" "$dir/env-doctor.sh"
  chmod +x "$dir/env-doctor.sh"
  (
    cd "$dir"
    git init -q
    git config user.email "test@users.noreply.github.com"
    git config user.name "env-doctor-test"
    "$@"
    git add -A
    git commit -q -m "fixture $name" --allow-empty 2>/dev/null || git commit -q -m "fixture $name"
  )
  printf '%s' "$dir"
}

run_doctor() {
  local repo="$1"
  shift
  (
    cd "$repo"
    bash ./env-doctor.sh "$@"
  )
}

# Stub python3.14 on PATH for tests (env-doctor requires 3.14+); delegates venv to real python3/virtualenv.
_setup_test_python314() {
  local stub_dir
  stub_dir="$(mktemp -d "${TMPDIR:-/tmp}/env-doctor-py314-stub-XXXXXX")"
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
_setup_test_python314
