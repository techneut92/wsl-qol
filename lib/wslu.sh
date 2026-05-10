# lib/wslu.sh — make `wslview` available so xdg-open / az login etc.
# can forward URLs to the Windows default browser.
#
# The full wslu toolkit (github.com/wslutilities/wslu) provides
# wslview, wslvar, wslsys, wsldl, wslfetch. Only `wslview` is
# actually consumed by the wsl-qol + wsl-gnome-rdp-installer
# ecosystem — the others are nice-to-have for terminal use.
#
# Distribution:
#   debian-like  — `wslu` is in main; straight apt install.
#   fedora-like  — wslutilities/wslu COPR lags behind Fedora releases
#                  (e.g. no fedora-44 chroot built as of 2026-05).
#                  Ship a minimal /usr/local/bin/wslview shim that
#                  forwards URLs/files to the Windows default handler
#                  via `cmd.exe /c start`. Zero external repo deps.
#                  Users who need the full wslu suite can build it
#                  from source (`git clone … && make install`).
#   anything else — skip with a hint.
#
# Skipped silently on non-WSL hosts.

install_wslu() {
  ui_step "wslu"

  # WSL_DISTRO_NAME is set by /init at WSL session start, but `sudo`
  # strips it by default. Fall back to the kernel signal so this
  # works whether wsl-qol was invoked from a login shell, a sudo
  # boundary, or an upstream installer that loses the var on the
  # way through.
  if [ -z "${WSL_DISTRO_NAME:-}" ] \
     && ! grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
    ui_skip "not running under WSL"
    return 0
  fi

  if command -v wslview >/dev/null 2>&1; then
    ui_skip "wslview already on PATH"
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
      _install_wslview_shim
      ;;
    *)
      ui_skip "wslu (no $DISTRO_FAMILY recipe — install manually if az login fails)"
      ;;
  esac
}

# Drop a minimal wslview at /usr/local/bin. Covers URL / file forwarding
# only; full wslu is available via `make install` from upstream if the
# user wants the rest of the toolkit.
_install_wslview_shim() {
  local dst=/usr/local/bin/wslview
  sudo tee "$dst" >/dev/null <<'SHIM'
#!/usr/bin/env bash
# wsl-qol minimal wslview shim. Forwards URLs and files to the Windows
# default handler via cmd.exe /c start. For the full wslu toolkit (wslvar,
# wslsys, wsldl, wslfetch) build upstream: `git clone
# https://github.com/wslutilities/wslu && make -C wslu install`.

# `cd /` before invoking cmd.exe — binfmt-launched Windows binaries
# return "Invalid argument" when cwd is under a dot-prefixed segment
# (~/.config, ~/.local, etc.), which is wherever xdg-open callers
# typically run from.
cd /

case "${1:-}" in
  '')
    exec /mnt/c/Windows/System32/cmd.exe /c start ""
    ;;
  -V|--version)
    echo "wslview-shim 0.1 (wsl-qol minimal — full wslu not installed)"
    ;;
  -h|--help)
    echo "Usage: wslview <URL | file>"
    echo "  Forwards the argument to the Windows default handler."
    echo "  Minimal shim. For the full wslu suite, install upstream."
    ;;
  *)
    arg="$1"
    if [ -e "$arg" ]; then
      arg=$(wslpath -w "$arg" 2>/dev/null) || arg="$1"
    fi
    exec /mnt/c/Windows/System32/cmd.exe /c start "" "$arg"
    ;;
esac
SHIM
  sudo chmod 0755 "$dst"
  ui_ok "Install $dst (minimal shim — no COPR)"
  ui_detail "covers xdg-open / az login / gh auth login forwarding"
}
