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

# Stub gh CLI for auth-blocker tests (mode: ok|invalid|unauth|missing-repo|missing-ssh).
make_gh_stub() {
  local bin_dir="$1"
  local mode="${2:-${HARNESS_GH_MODE:-ok}}"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/gh" <<EOF
#!/usr/bin/env bash
case "\$1:\$2" in
  auth:status)
    case "${mode}" in
      invalid) echo "token in keyring is invalid"; exit 1 ;;
      unauth) echo "You are not logged into any GitHub hosts"; exit 1 ;;
      missing-repo)
        echo "Logged in to github.com"
        echo "Token scopes: gist, read:org"
        exit 0 ;;
      missing-ssh)
        echo "Logged in to github.com"
        echo "Token scopes: repo"
        exit 0 ;;
      *)
        echo "Logged in to github.com"
        echo "Token scopes: repo, admin:public_key"
        exit 0 ;;
    esac
    ;;
  *)
    echo "gh stub: unsupported \$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$bin_dir/gh"
}

assert_file_contains() {
  local msg="$1" path="$2" needle="$3"
  assert_contains "$msg" "$(cat "$path")" "$needle"
}

assert_file_not_contains() {
  local msg="$1" path="$2" needle="$3"
  assert_not_contains "$msg" "$(cat "$path")" "$needle"
}

run_doctor() {
  local repo="$1"
  shift
  local global_cfg="${HARNESS_GIT_CONFIG_GLOBAL:-}"
  local cleanup_cfg=false
  if [[ -z "$global_cfg" ]]; then
    global_cfg="$(mktemp)"
    : >"$global_cfg"
    cleanup_cfg=true
  fi
  (
    cd "$repo"
    GIT_CONFIG_GLOBAL="$global_cfg" GIT_CONFIG_SYSTEM=/dev/null \
      bash ./env-doctor.sh "$@"
  )
  if [[ "$cleanup_cfg" == true ]]; then
    rm -f "$global_cfg"
  fi
}
