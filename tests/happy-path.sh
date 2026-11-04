#!/usr/bin/env bash
# Hardening for the rust-astro-vite happy path. No network. No writes outside a temp HOME.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helpers.sh"
_setup_test_python314

ORIG_HOME="${HOME}"
ORIG_PATH="${PATH}"

restore_env() {
  HOME="$ORIG_HOME"
  PATH="$ORIG_PATH"
  unset CARGO_HOME STUB_LOG PATH_LOG
}
trap restore_env EXIT

isolate_home() {
  HOME="$(mktemp -d)"
  CARGO_HOME="${HOME}/.cargo"
  export HOME CARGO_HOME
}

stub_bin() {
  local dir
  dir="$(mktemp -d)"
  cat >"${dir}/rustup" <<'EOF'
#!/usr/bin/env bash
printf 'rustup %s\n' "$*" >> "${STUB_LOG:?}"
exit "${RUSTUP_RC:-0}"
EOF
  cat >"${dir}/cargo" <<'EOF'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >> "${STUB_LOG:?}"
printf '%s\n' "$PATH" > "${PATH_LOG:?}"
if [[ "${1:-}" == "new" ]]; then
  dest=""
  for arg in "$@"; do
    case "$arg" in
      new|--*) ;;
      *) dest="$arg" ;;
    esac
  done
  mkdir -p "${dest}/src"
  printf '[package]\nname = "hello"\nversion = "0.0.0"\nedition = "2024"\n' > "${dest}/Cargo.toml"
fi
exit 0
EOF
  cat >"${dir}/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "${STUB_LOG:?}"
exit 1
EOF
  cat >"${dir}/node" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'v%s\n' "${NODE_VER:-22.0.0}"
elif [[ "${1:-}" == "-p" ]]; then
  printf '%s\n' "${NODE_VER%%.*}"
fi
exit 0
EOF
  cat >"${dir}/npm" <<'EOF'
#!/usr/bin/env bash
printf '10.9.9\n'
exit 0
EOF
  cat >"${dir}/rustc" <<'EOF'
#!/usr/bin/env bash
printf 'rustc %s\n' "${RUSTC_VER:-1.99.1}"
exit 0
EOF
  cat >"${dir}/rust-analyzer" <<'EOF'
#!/usr/bin/env bash
printf 'rust-analyzer %s\n' "${ANALYZER_VER:-1.99.1}"
exit 0
EOF
  chmod +x "${dir}/rustup" "${dir}/cargo" "${dir}/curl" "${dir}/node" "${dir}/npm" "${dir}/rustc" "${dir}/rust-analyzer"
  STUB_LOG="$(mktemp)"
  PATH_LOG="$(mktemp)"
  export STUB_LOG PATH_LOG
  PATH="${dir}:/usr/bin:/bin"
  export PATH
  printf '%s' "$dir"
}

assert_no_abort() {
  local msg="$1" file="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q "Unexpected script failure" "$file"; then
    echo "FAIL: $msg (doctor aborted)" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ── dry-run and consent do not touch HOME ───────────────────────────────────
isolate_home
repo="$(make_fixture_repo rav-dry bash -c 'printf "[package]\nname = \"foo\"\nversion = \"0.1.0\"\n" > Cargo.toml')"
out="$(mktemp)"
set +e
run_doctor "$repo" -it0n >"$out" 2>&1
code=$?
set -e
assert_eq "dry-run exits 0" "0" "$code"
assert_no_abort "dry-run" "$out"
text="$(cat "$out")"
assert_contains "dry-run plans rustup" "$text" "rustup update stable"
assert_contains "dry-run plans bashrc" "$text" "RUST_BACKTRACE=1"
assert_file_absent "dry-run writes no bashrc" "${HOME}/.bashrc"
assert_file_absent "dry-run writes no cargo config" "${CARGO_HOME}/config.toml"
rm -rf "$repo" "$out"

isolate_home
repo="$(make_fixture_repo rav-consent bash -c 'true')"
out="$(mktemp)"
set +e
run_doctor "$repo" --init --tier 0 >"$out" 2>&1
code=$?
set -e
assert_eq "init without --yes exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "consent warning" "$text" "Consent required"
assert_file_absent "consent writes no bashrc" "${HOME}/.bashrc"
assert_file_absent "consent writes no cargo config" "${CARGO_HOME}/config.toml"
rm -rf "$repo" "$out"

# ── --yes uses stubs, survives rustup failure, stays idempotent ─────────────
isolate_home
stub_bin >/dev/null
export RUSTUP_RC=1
repo="$(make_fixture_repo rav-yes bash -c 'true')"
out="$(mktemp)"
set +e
run_doctor "$repo" --init --tier 0 --yes >"$out" 2>&1
code=$?
set -e
assert_eq "yes with failing rustup exits 0" "0" "$code"
assert_no_abort "failing rustup" "$out"
text="$(cat "$out")"
assert_contains "rustup failure is a warning" "$text" "update stable failed"
assert_contains "nextest install failure is a warning" "$text" "install failed"
assert_contains "compile still passes via cargo" "$text" "throwaway bin"
assert_file_present "yes writes cargo config" "${CARGO_HOME}/config.toml"
assert_file_present "yes writes bashrc" "${HOME}/.bashrc"
if ! grep -q "${CARGO_HOME}/bin" "$PATH_LOG"; then
  echo "FAIL: cargo check PATH missing cargo bin" >&2
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

set +e
run_doctor "$repo" --init --tier 0 --yes >"$out" 2>&1
code=$?
set -e
assert_eq "second yes exits 0" "0" "$code"
backtrace_n="$(grep -c 'RUST_BACKTRACE=1' "${HOME}/.bashrc" || true)"
assert_eq "bashrc export is written once" "1" "$backtrace_n"
rm -rf "$repo" "$out"
unset RUSTUP_RC

# ── selection ────────────────────────────────────────────────────────────────
isolate_home
PATH="$ORIG_PATH"
export PATH
repo="$(make_fixture_repo mixed bash -c 'printf "[package]\nname=\"foo\"\nversion=\"0.1.0\"\n" > Cargo.toml; printf "[project]\nname=\"foo\"\n" > pyproject.toml')"
out="$(mktemp)"
set +e
run_doctor "$repo" -it0n >"$out" 2>&1
code=$?
set -e
assert_eq "mixed repo dry-run exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "mixed repo stays on rust" "$text" "rust-astro-vite"
assert_not_contains "mixed repo does not pip install -e" "$text" "pip install -e ."
assert_not_contains "mixed repo does not abort on python" "$text" "Init aborted"
rm -rf "$repo" "$out"

repo="$(make_fixture_repo astro bash -c 'printf "{\"dependencies\":{\"astro\":\"7.4.5\"}}\n" > package.json')"
out="$(mktemp)"
set +e
run_doctor "$repo" -it0n >"$out" 2>&1
code=$?
set -e
assert_eq "astro package dry-run exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "astro package selects rust-astro-vite" "$text" "rust-astro-vite"
rm -rf "$repo" "$out"

repo="$(make_fixture_repo force-py bash -c 'printf "[package]\nname=\"foo\"\nversion=\"0.1.0\"\n" > Cargo.toml')"
out="$(mktemp)"
set +e
ENV_DOCTOR_HAPPY_PATH=python run_doctor "$repo" -it0n >"$out" 2>&1
code=$?
set -e
text="$(cat "$out")"
assert_eq "forced python dry-run exits 0" "0" "$code"
assert_contains "forced python path" "$text" "Happy path"
assert_not_contains "forced python does not rustup" "$text" "rustup update stable"
rm -rf "$repo" "$out"

repo="$(make_fixture_repo bad-path bash -c 'true')"
out="$(mktemp)"
set +e
ENV_DOCTOR_HAPPY_PATH=nope run_doctor "$repo" --json -q >"$out" 2>&1
code=$?
set -e
assert_eq "unknown happy path exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "unknown happy path warns" "$text" "unknown value"
assert_contains "unknown happy path falls back" "$text" "rust-astro-vite"
rm -rf "$repo" "$out"

# ── node floor and toolchain mismatch are warnings, not aborts ──────────────
stub_bin >/dev/null
export NODE_VER=18.20.0
repo="$(make_fixture_repo node18 bash -c 'true')"
out="$(mktemp)"
set +e
run_doctor "$repo" --json -q >"$out" 2>&1
code=$?
set -e
assert_eq "node 18 audit exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "node 18 warns" "$text" "need 22+"
assert_no_abort "node 18" "$out"
rm -rf "$repo" "$out"
unset NODE_VER

export RUSTC_VER=1.0.0 ANALYZER_VER=9.9.9
repo="$(make_fixture_repo mismatch bash -c 'true')"
out="$(mktemp)"
set +e
run_doctor "$repo" --json -q >"$out" 2>&1
code=$?
set -e
assert_eq "version mismatch exits 0" "0" "$code"
text="$(cat "$out")"
assert_contains "version mismatch warns" "$text" "rustc 1.0.0 vs rust-analyzer 9.9.9"
rm -rf "$repo" "$out"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  echo "happy-path: ${TESTS_FAILED} failed / ${TESTS_RUN} checks" >&2
  exit 1
fi
echo "happy-path: ${TESTS_RUN} checks, 0 failed"
