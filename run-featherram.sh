#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"

chmod +x "$script_dir/featherram.command" 2>/dev/null || true
xattr -d com.apple.quarantine "$script_dir/featherram.command" 2>/dev/null || true

exec zsh "$script_dir/featherram.command" "$@"
