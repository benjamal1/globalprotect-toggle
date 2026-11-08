# globalprotect-toggle

One command to switch the GlobalProtect VPN client off and back on, on macOS.

```sh
globalprotect off   # stop GlobalProtect; it stays off after reboot
globalprotect on    # start GlobalProtect so you can sign in
```

## Problem

GlobalProtect starts at login and relaunches itself when quit. On portals that use browser sign-in, it can open the sign-in page in your browser over and over until you log in. Some portals also hide the Quit and Disconnect menu items. The only built-in way to stop it is to switch its background items off in System Settings, then back on when you need the VPN.

## Purpose

This tool replaces that trip to System Settings with `globalprotect off` and `globalprotect on`. It doesn't change your VPN configuration or uninstall anything.

## Requirements

- macOS with the GlobalProtect client installed in `/Applications/GlobalProtect.app` (tested with version 6.2.8)
- An admin account, for the one-time install
- Permission from your organization if it requires GlobalProtect to stay on

## Install

1. In System Settings, open Login Items & Extensions and switch GlobalProtect on. Leave it on, because macOS refuses to start services that are switched off there.
2. Clone this repo and `cd` into it.
3. Run `sudo ./globalprotect-install.sh` and enter your password.

The installer does two things:

- Copies `globalprotect.sh` to `/usr/local/bin/globalprotect`, owned by root and read-only to you.
- Adds `/etc/sudoers.d/globalprotect`, which allows exactly `globalprotect on` and `globalprotect off` without a password.

The script is owned by root, so nothing running under your account can edit it to gain admin rights.

## Setup check

1. Run `globalprotect off`, then restart your Mac. No sign-in page should open.
2. Run `globalprotect on`. GlobalProtect should open so you can sign in.

## How it works

The client runs as three launchd services: one system daemon (`com.paloaltonetworks.gp.pangpsd`) and two login agents (`com.paloaltonetworks.gp.pangps` and `com.paloaltonetworks.gp.pangpa`). Running `off` disables each service with `launchctl disable` and stops it with `launchctl bootout`. Running `on` re-enables each service and starts it with `launchctl bootstrap`.

PanGPS ignores the stop signal while the VPN is connected. A killed PanGPS skips its own cleanup. Its tunnel then stays registered as the primary network service with no interface behind it, and Wi-Fi stops working. For that reason `off` gives PanGPS 5 seconds to exit, then kills it. It then removes the leftover `State:/Network/Service/gpd.pan/*` keys, which is the same cleanup PanGPS runs on its next start.

Palo Alto documents the same service-level approach in [How to manually stop and start PanGPS or PanGPA on macOS](https://knowledgebase.paloaltonetworks.com/kCSArticleDetail?id=kA10g0000008UGs).

## Uninstall

```sh
globalprotect on
sudo rm /usr/local/bin/globalprotect /etc/sudoers.d/globalprotect
```
