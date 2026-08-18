#!/usr/bin/env bash
# dinit auth blocker tests — GitHub auth / HTTPS remote / config poison paths.
# Run from repo root: bash tests/auth-blockers.sh

set -euo pipefail

# shellcheck source=tests/helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"

echo "Running env-doctor dinit auth blocker suite (script: $CANONICAL_SCRIPT)"

# ── Test 1: HTTPS GitHub origin suggests dinit auth blocker ─────────────────
echo "Test 1: HTTPS GitHub origin triggers blocker UX"
https_repo="$(make_fixture_repo https-origin bash -c "
  git remote add origin '${HARNESS_GITHUB_HTTPS_REMOTE}'
")"
text_out="$(mktemp)"
run_doctor "$https_repo" >"$text_out" 2>&1 || true
assert_file_contains "HTTPS origin warns about submodule prompts" "$text_out" "uses HTTPS"
assert_file_contains "summary blocker mentions auth" "$text_out" "blocker"
assert_file_contains "next command is dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out"
rm -rf "$https_repo"

# ── Test 2: git config url poison (insteadOf) triggers blocker ───────────────
echo "Test 2: git config HTTPS override poison"
poison_repo="$(make_fixture_repo config-poison true)"
global_cfg="$(mktemp)"
cat >"$global_cfg" <<EOF
[url "https://github.com/"]
	insteadOf = git@github.com:
EOF
HARNESS_GIT_CONFIG_GLOBAL="$global_cfg"
text_out="$(mktemp)"
run_doctor "$poison_repo" >"$text_out" 2>&1 || true
unset HARNESS_GIT_CONFIG_GLOBAL
assert_file_contains "HTTPS override poison warned" "$text_out" "HTTPS override poison"
assert_file_contains "poison path suggests dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out" "$global_cfg"
rm -rf "$poison_repo"

# ── Test 3: stale gh token (invalid keyring) ─────────────────────────────────
echo "Test 3: stale gh token warns and sets next command"
gh_invalid_repo="$(make_fixture_repo gh-invalid bash -c "
  mkdir -p bin
")"
make_gh_stub "${gh_invalid_repo}/bin" invalid
text_out="$(mktemp)"
PATH="${gh_invalid_repo}/bin:${PATH}" run_doctor "$gh_invalid_repo" >"$text_out" 2>&1 || true
assert_file_contains "invalid gh token warned" "$text_out" "token invalid"
assert_file_contains "invalid token suggests dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out"
rm -rf "$gh_invalid_repo"

# ── Test 4: gh not authenticated ─────────────────────────────────────────────
echo "Test 4: unauthenticated gh warns"
gh_unauth_repo="$(make_fixture_repo gh-unauth bash -c "mkdir -p bin")"
make_gh_stub "${gh_unauth_repo}/bin" unauth
text_out="$(mktemp)"
PATH="${gh_unauth_repo}/bin:${PATH}" run_doctor "$gh_unauth_repo" >"$text_out" 2>&1 || true
assert_file_contains "unauthenticated gh warned" "$text_out" "not authenticated"
assert_file_contains "unauth suggests dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out"
rm -rf "$gh_unauth_repo"

# ── Test 5: gh missing repo scope ────────────────────────────────────────────
echo "Test 5: gh missing repo scope"
gh_scope_repo="$(make_fixture_repo gh-scope bash -c "mkdir -p bin")"
make_gh_stub "${gh_scope_repo}/bin" missing-repo
text_out="$(mktemp)"
PATH="${gh_scope_repo}/bin:${PATH}" run_doctor "$gh_scope_repo" >"$text_out" 2>&1 || true
assert_file_contains "missing repo scope warned" "$text_out" "missing repo scope"
assert_file_contains "scope gap suggests dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out"
rm -rf "$gh_scope_repo"

# ── Test 6: gh missing admin:public_key scope ────────────────────────────────
echo "Test 6: gh missing SSH key scope"
gh_ssh_repo="$(make_fixture_repo gh-ssh bash -c "mkdir -p bin")"
make_gh_stub "${gh_ssh_repo}/bin" missing-ssh
text_out="$(mktemp)"
PATH="${gh_ssh_repo}/bin:${PATH}" run_doctor "$gh_ssh_repo" >"$text_out" 2>&1 || true
assert_file_contains "missing admin:public_key warned" "$text_out" "admin:public_key"
assert_file_contains "ssh scope gap suggests dinit auth" "$text_out" "$HARNESS_NEXT_CMD"
rm -f "$text_out"
rm -rf "$gh_ssh_repo"

# ── Test 7: healthy gh + SSH remote does not emit blocker footer ───────────
echo "Test 7: clean auth path has no blocker footer"
clean_repo="$(make_fixture_repo clean-auth bash -c "
  mkdir -p bin
  git remote add origin 'git@github.com:example/acme.git'
")"
make_gh_stub "${clean_repo}/bin" ok
text_out="$(mktemp)"
PATH="${clean_repo}/bin:${PATH}" run_doctor "$clean_repo" >"$text_out" 2>&1 || true
assert_file_contains "gh authenticated passes" "$text_out" "gh auth"
assert_file_not_contains "no blocker when auth is clean" "$text_out" "blocker:"
rm -f "$text_out"
rm -rf "$clean_repo"

# ── Test 8: quoted gh scopes (real gh auth status format) ───────────────────
echo "Test 8: quoted gh token scopes accepted"
quoted_repo="$(make_fixture_repo gh-quoted bash -c "
  mkdir -p bin
  git remote add origin 'git@github.com:example/acme.git'
")"
make_gh_stub "${quoted_repo}/bin" quoted-ok
text_out="$(mktemp)"
PATH="${quoted_repo}/bin:${PATH}" run_doctor "$quoted_repo" >"$text_out" 2>&1 || true
assert_file_contains "quoted scopes authenticate" "$text_out" "authenticated"
assert_file_not_contains "quoted scopes do not false-positive blocker" "$text_out" "blocker:"
rm -f "$text_out"
rm -rf "$quoted_repo"

# ── Test 9: legitimate HTTPS→SSH insteadOf rewrite is not poison ────────────
echo "Test 9: legitimate git url rewrite not flagged as poison"
legit_repo="$(make_fixture_repo legit-insteadof bash -c "
  mkdir -p bin
  git remote add origin 'git@github.com:example/acme.git'
")"
make_gh_stub "${legit_repo}/bin" ok
global_cfg="$(mktemp)"
cat >"$global_cfg" <<EOF
[url "git@github.com:"]
	insteadOf = https://github.com/
EOF
HARNESS_GIT_CONFIG_GLOBAL="$global_cfg"
text_out="$(mktemp)"
PATH="${legit_repo}/bin:${PATH}" run_doctor "$legit_repo" >"$text_out" 2>&1 || true
unset HARNESS_GIT_CONFIG_GLOBAL
assert_file_not_contains "legitimate insteadOf not poison" "$text_out" "HTTPS override poison"
assert_file_not_contains "legitimate insteadOf no blocker" "$text_out" "blocker:"
rm -f "$text_out" "$global_cfg"
rm -rf "$legit_repo"

# ── Test 10: JSON mode must not leak blocker footer to stdout ────────────────
echo "Test 10: JSON output stays machine-parseable (no human blocker footer)"
json_repo="$(make_fixture_repo json-auth bash -c "
  git remote add origin '${HARNESS_GITHUB_HTTPS_REMOTE}'
")"
json_out="$(mktemp)"
run_doctor "$json_repo" --json -q >"$json_out" 2>/dev/null || true
assert_json_ok "auth warnings still produce valid JSON" "$json_out"
assert_not_contains "blocker footer absent from JSON stdout" "$(cat "$json_out")" "blocker:"
rm -f "$json_out"
rm -rf "$json_repo"

echo ""
echo "Ran $TESTS_RUN assertions; failures: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
