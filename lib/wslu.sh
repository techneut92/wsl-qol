# lib/wslu.sh — install wslu so wslview is on PATH.
#
# wslu provides `wslview` and friends. The headline use case:
# anything inside WSL that calls xdg-open / Python's webbrowser /
# `gio open` (az login, gh auth login, OAuth device flows, etc.)
# fails with "no handler for text/html" on a stripped WSL distro
# because there's no Linux-side browser to launch. wslview catches
# those calls and forwards the URL to the Windows default browser
# via interop.
#
# Distribution:
#   debian-like  — `wslu` is in main; straight install
#   fedora-like  — not in default repos. Use the community-maintained
#                  atim/wslu COPR. Auto-enable + install.
#   anything else — skip with a hint
#
# Skipped silently on non-WSL hosts (no $WSL_DISTRO_NAME).

install_wslu() {
  ui_step "wslu"

  if [ -z "${WSL_DISTRO_NAME:-}" ]; then
    ui_skip "not running under WSL"
    return 0
  fi

  if command -v wslview >/dev/null 2>&1; then
    ui_skip "wslu already installed"
    local v
    v=$(wslview --version 2>/dev/null | head -1) || true
    [ -n "$v" ] && ui_detail "$v"
    return 0
  fi

  case "$DISTRO_FAMILY" in
    debian-like)
      ui_spin "Install wslu (apt)" \
        sudo apt-get install -y -qq wslu
      ;;
    fedora-like)
      if ! command -v dnf >/dev/null 2>&1; then
        ui_skip "wslu (no dnf — install manually)"
        return 0
      fi
      ui_spin "Enable atim/wslu COPR" \
        sudo dnf -y -q copr enable atim/wslu
      ui_spin "Install wslu (dnf)" \
        sudo dnf -y -q install wslu
      ;;
    *)
      ui_skip "wslu (no $DISTRO_FAMILY recipe — install manually if az login fails)"
      ;;
  esac
}
