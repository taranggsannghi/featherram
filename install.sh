#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"

echo "FeatherRAM setup"
echo
echo "Checking launcher files..."

for target in \
  "$script_dir/featherram.command" \
  "$script_dir/run-featherram.sh" \
  "$script_dir/install.sh"
do
  if [[ -f "$target" ]]; then
    chmod +x "$target"
    xattr -d com.apple.quarantine "$target" 2>/dev/null || true
  fi
done

echo "Setup finished."
echo
echo "Next step:"
echo "  zsh \"$script_dir/run-featherram.sh\""
