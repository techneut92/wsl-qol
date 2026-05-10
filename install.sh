#!/bin/bash
# install.sh — wsl-qol entry point.
#
# REGRESSION-TEST BRANCH (regression-test/no-features) — every feature
# defaults OFF so the bootstrap is a structural no-op. Re-enable one at a
# time via QOL_*=1 to bisect which feature triggers the pop-shell flake.
# See docs/QOL-FEATURES.md for the catalog and suggested re-enable order.
#
# Env knobs (all default to 0 on this branch):
#   QOL_BINFMT=0/1          /etc/binfmt.d/WSLInterop.conf + reload
#   QOL_FLATPAK=0/1         flathub remotes (system+user) + /tmp deny
#   QOL_FLATPAK_SYNC=0/1    .desktop+icon mirror to /usr/share via .path unit
#   QOL_PULSE_DETACH=0/1    user oneshot to detach WSLg's pulse symlink
#
# (theme-sync removed pending rework — see docs/QOL-FEATURES.md §5)
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

SYSTEMD_USER_DIR="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"
export SYSTEMD_USER_DIR

# Sanity: this is for WSL2.
[ -n "${WSL_DISTRO_NAME:-}" ] || \
  ui_warn "WSL_DISTRO_NAME unset — script assumes WSL2; continuing anyway."

ui_phase "Preflight"
detect_distro
ui_ok    "Detect distro"
ui_detail "$DISTRO_ID ($DISTRO_FAMILY)"

ui_phase "WSL QOL (regression-test: all features default OFF)"

[ "${QOL_BINFMT:-0}" = "1" ]       && install_wslinterop_binfmt
[ "${QOL_FLATPAK:-0}" = "1" ]      && setup_flatpak_remotes
[ "${QOL_FLATPAK_SYNC:-0}" = "1" ] && install_wslg_flatpak_sync
[ "${QOL_PULSE_DETACH:-0}" = "1" ] && install_wslg_pulse_detach

# Initial fire of the sync units (only if the unit was installed this run).
[ "${QOL_FLATPAK_SYNC:-0}" = "1" ] && initial_flatpak_sync_run

ui_phase "Done"
ui_ok "WSL QOL installed (no-op on this branch unless QOL_*=1 set)"
ui_detail "Re-run install.sh any time to refresh."
