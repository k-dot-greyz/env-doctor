#!/usr/bin/env bash
# path-guard.sh — reject paths unsafe for embedding in shell profile snippets.
# Licensed under GPL-3.0 — (c) 2026 greyZ
#
# Returns 0 (true) when path contains shell metacharacters that could break
# out of double-quoted assignments written to ~/.bashrc / ~/.zshrc.

_path_unsafe_for_profile_embed() {
  local path="${1:-}"
  [[ "$path" =~ [\$\`\;\&\|\<\>\(\)\\\"] ]] || [[ "$path" =~ $'\n' ]]
}
