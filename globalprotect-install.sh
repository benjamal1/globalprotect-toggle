#!/bin/bash
# One-time setup: install the globalprotect toggle root-owned and allow it without a password.
# Usage: sudo ./globalprotect-install.sh
set -euo pipefail

readonly TARGET=/usr/local/bin/globalprotect
readonly RULE_FILE=/etc/sudoers.d/globalprotect

[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
readonly OWNER=${SUDO_USER:?run with sudo from your user account}
SOURCE="$(cd "$(dirname "$0")" && pwd)/globalprotect.sh"
readonly SOURCE

install -o root -g wheel -m 755 "$SOURCE" "$TARGET"

rule_tmp=$(mktemp)
trap 'rm -f "$rule_tmp"' EXIT
echo "$OWNER ALL=(root) NOPASSWD: $TARGET on, $TARGET off" >"$rule_tmp"
visudo -cf "$rule_tmp"
install -o root -g wheel -m 440 "$rule_tmp" "$RULE_FILE"

echo "Installed $TARGET and $RULE_FILE."
