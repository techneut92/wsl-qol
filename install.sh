#!/bin/bash
# install.sh — wsl-qol entry point.
#
# Layered, mostly opt-out via env. Each tier is independently useful:
# enable the WSLInterop binfmt drop-in even on a headless terminal-only
# WSL distro, install flatpak Start-Menu sync even without a desktop
# environment, etc.
#
# Env knobs:
#   QOL_BINFMT=0/1          [default 1] /etc/binfmt.d/WSLInterop.conf + reload
#   QOL_WSLU=0/1            [default 1] wslu (provides wslview — forwards
#                                       xdg-open URLs to Windows browser, fixes
#                                       az login / gh auth login on stripped WSL).
#                                       Auto-enables atim/wslu COPR on Fedora.
#   QOL_XDG_DIRS=0/1        [default 1] populate ~/.config/user-dirs.dirs with
#                                       the standard XDG dirs + create a
#                                       ~/Projects folder. Desktop-agnostic —
#                                       no Nautilus/sidebar bookmarks here.
#   QOL_FLATPAK=0/1         [default 1] flathub remotes (system+user) + /tmp deny
#   QOL_FLATPAK_SYNC=0/1    [default 1] .desktop+icon mirror to /usr/share via 1min timer
#   QOL_PULSE_DETACH=0/1    [default 1] user oneshot to detach WSLg's pulse symlink
#   QOL_THEME_SYNC=0/1      [default 0] Continuous-polling .timer that mirrors
#                                       Windows light/dark into GTK/gsettings/.ini
#                                       every minute. Off by default because it
#                                       overwrites a user-customized RDP theme
#                                       on every fire. Note: the ONE-SHOT
#                                       mirror at install time always runs
#                                       regardless of this knob — fresh installs
#                                       still get a first-launch theme matching
#                                       Windows, just without ongoing tracking.
#                                       Enable with QOL_THEME_SYNC=1.
#
#   QOL_NONINTERACTIVE=1    suppress prompts (none today; reserved)

set -eo pipefail

PROJECT_ROOT="${WSL_QOL_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export PROJECT_ROOT

# shellcheck source=lib/ui.sh
. "$PROJECT_ROOT/lib/ui.sh"
# shellcheck source=lib/common.sh
. "$PROJECT_ROOT/lib/common.sh"
# shellcheck source=lib/binfmt.sh
. "$PROJECT_ROOT/lib/binfmt.sh"
# shellcheck source=lib/flatpak.sh
. "$PROJECT_ROOT/lib/flatpak.sh"
# shellcheck source=lib/pulse_detach.sh
. "$PROJECT_ROOT/lib/pulse_detach.sh"
# shellcheck source=lib/theme_sync.sh
. "$PROJECT_ROOT/lib/theme_sync.sh"
# shellcheck source=lib/wslu.sh
. "$PROJECT_ROOT/lib/wslu.sh"
# shellcheck source=lib/xdg_dirs.sh
. "$PROJECT_ROOT/lib/xdg_dirs.sh"

SYSTEMD_USER_DIR="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"
export SYSTEMD_USER_DIR

# Sanity: this is for WSL2.
[ -n "${WSL_DISTRO_NAME:-}" ] || \
  ui_warn "WSL_DISTRO_NAME unset — script assumes WSL2; continuing anyway."

ui_phase "Preflight"
detect_distro
ui_ok    "Detect distro"
ui_detail "$DISTRO_ID ($DISTRO_FAMILY)"

ui_phase "WSL QOL"

[ "${QOL_BINFMT:-1}" = "1" ]       && install_wslinterop_binfmt
[ "${QOL_WSLU:-1}" = "1" ]         && install_wslu
[ "${QOL_XDG_DIRS:-1}" = "1" ]     && setup_xdg_user_dirs
[ "${QOL_FLATPAK:-1}" = "1" ]      && setup_flatpak_remotes
[ "${QOL_FLATPAK_SYNC:-1}" = "1" ] && install_wslg_flatpak_sync
[ "${QOL_PULSE_DETACH:-1}" = "1" ] && install_wslg_pulse_detach

# Theme sync — always do the one-shot install-time mirror so fresh
# installs match Windows light/dark on first GUI launch. The continuous
# polling timer is opt-in via QOL_THEME_SYNC=1.
oneshot_theme_sync
[ "${QOL_THEME_SYNC:-0}" = "1" ]   && install_theme_sync_timer

# Initial fire of the sync units so the user sees results without a reboot.
[ "${QOL_FLATPAK_SYNC:-1}" = "1" ] && initial_flatpak_sync_run

ui_phase "Done"
ui_ok "WSL QOL installed"
ui_detail "Re-run install.sh any time to refresh."
