#!/bin/bash
# install.sh — wsl-qol entry point.
#
# Layered, opt-out via env; runs everything by default. Each tier is
# independently useful: enable the WSLInterop binfmt drop-in even on a
# headless terminal-only WSL distro, install flatpak Start-Menu sync
# even without a desktop environment, etc.
#
# Env knobs (all default to 1):
#   QOL_BINFMT=0/1          /etc/binfmt.d/WSLInterop.conf + reload
#   QOL_FLATPAK=0/1         flathub remotes (system+user) + /tmp deny
#   QOL_FLATPAK_SYNC=0/1    .desktop+icon mirror to /usr/share via 5min timer
#   QOL_PULSE_DETACH=0/1    user oneshot to detach WSLg's pulse symlink
#   QOL_THEME_SYNC=0/1      systemd user .timer that mirrors Windows theme
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
[ "${QOL_FLATPAK:-1}" = "1" ]      && setup_flatpak_remotes
[ "${QOL_FLATPAK_SYNC:-1}" = "1" ] && install_wslg_flatpak_sync
[ "${QOL_PULSE_DETACH:-1}" = "1" ] && install_wslg_pulse_detach
[ "${QOL_THEME_SYNC:-1}" = "1" ]   && install_theme_sync

# Initial fire of the sync units so the user sees results without a reboot.
[ "${QOL_FLATPAK_SYNC:-1}" = "1" ] && initial_flatpak_sync_run
[ "${QOL_THEME_SYNC:-1}" = "1" ]   && initial_theme_sync_run

ui_phase "Done"
ui_ok "WSL QOL installed"
ui_detail "Re-run install.sh any time to refresh."
