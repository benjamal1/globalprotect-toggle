#!/bin/bash
# Toggle GlobalProtect's launchd services so it stays quiet until needed.
# Usage: globalprotect on|off
# Installed root-owned at /usr/local/bin/globalprotect by globalprotect-install.sh.
set -euo pipefail

readonly SELF=/usr/local/bin/globalprotect
readonly DAEMON=com.paloaltonetworks.gp.pangpsd
readonly AGENTS=(com.paloaltonetworks.gp.pangps com.paloaltonetworks.gp.pangpa)
# Network state PanGPS publishes for its tunnel. It removes these keys itself on a clean exit.
readonly TUNNEL_STATE_KEYS='State:/Network/Service/gpd\.pan/.*'
# launchd kills PanGPS 20 seconds after asking it to quit (ExitTimeOut in its plist).
readonly EXIT_WAIT_SECONDS=30

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

# bootout returns before PanGPS exits, so poll for it.
wait_for_pangps_exit() {
  local waited=0
  while pgrep -x PanGPS >/dev/null; do
    if ((waited >= EXIT_WAIT_SECONDS)); then
      echo "PanGPS still running after ${EXIT_WAIT_SECONDS}s" >&2
      return 1
    fi
    sleep 1
    ((waited += 1))
  done
}

# A killed PanGPS leaves its tunnel as the primary network service with no
# interface behind it, so nothing can reach the network. Do the cleanup that
# PanGPS would otherwise do on its next start.
remove_stale_tunnel_state() {
  local key
  scutil <<<"list $TUNNEL_STATE_KEYS" | awk '/subKey/ {print $NF}' |
    while read -r key; do
      scutil <<<"remove $key"
    done
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
    wait_for_pangps_exit
    remove_stale_tunnel_state
    echo "GlobalProtect off. It stays off after reboot."
    ;;
esac
