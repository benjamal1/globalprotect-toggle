#!/bin/bash
# Toggle GlobalProtect's launchd services so it stays quiet until needed.
# Usage: globalprotect on|off
# Installed root-owned at /usr/local/bin/globalprotect by globalprotect-install.sh.
set -euo pipefail

readonly SELF=/usr/local/bin/globalprotect
readonly DAEMON=com.paloaltonetworks.gp.pangpsd
readonly AGENTS=(com.paloaltonetworks.gp.pangps com.paloaltonetworks.gp.pangpa)

usage() {
  echo "usage: globalprotect on|off" >&2
  exit 2
}

[[ $# -eq 1 && ($1 == on || $1 == off) ]] || usage
[[ $EUID -eq 0 ]] || exec sudo "$SELF" "$@"

readonly USER_DOMAIN="gui/${SUDO_UID:?run this as your user, not as root}"

is_loaded() {
  launchctl print "$1" >/dev/null 2>&1
}

# $1 = domain, $2 = label, $3 = plist path
start_service() {
  launchctl enable "$1/$2"
  is_loaded "$1/$2" || launchctl bootstrap "$1" "$3"
}

# $1 = domain, $2 = label
stop_service() {
  launchctl disable "$1/$2"
  if is_loaded "$1/$2"; then launchctl bootout "$1/$2"; fi
}

case $1 in
  on)
    start_service system "$DAEMON" "/Library/LaunchDaemons/$DAEMON.plist"
    for agent in "${AGENTS[@]}"; do
      start_service "$USER_DOMAIN" "$agent" "/Library/LaunchAgents/$agent.plist"
    done
    echo "GlobalProtect on. Sign in from the menu bar icon."
    ;;
  off)
    for agent in "${AGENTS[@]}"; do
      stop_service "$USER_DOMAIN" "$agent"
    done
    stop_service system "$DAEMON"
    echo "GlobalProtect off. It stays off after reboot."
    ;;
esac
