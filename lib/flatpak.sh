# lib/flatpak.sh — flatpak setup + WSLg Start-Menu auto-publish wiring.
#
# Two helpers:
#   setup_flatpak_remotes — flathub remote on both --system and --user
#                           (system path init is required for any
#                           bare `flatpak run` to succeed; .desktop
#                           Exec lines never include --user) plus a
#                           global `--nofilesystem=/tmp` override that
#                           keeps WSLg's /tmp/.X11-unix bug from
#                           crashing flatpaks like ONLYOFFICE.
#
#   install_wslg_flatpak_sync — root-side sync script + sudoers + user
#                               .path watcher + .service. Mirrors
#                               flatpak .desktop+icon exports into
#                               /usr/share so WSLg's Start-Menu
#                               publisher (which only walks /usr/share
#                               and only reads regular files) sees them.

setup_flatpak_remotes() {
  ui_step "Flatpak remotes (flathub)"
  if ! command -v flatpak >/dev/null 2>&1; then
    # Auto-install flatpak rather than skipping silently — Fedora's
    # minimal WSL image (and Debian's, depending on tasksel) doesn't
    # include it. detect_distro has already populated DISTRO_FAMILY.
    case "${DISTRO_FAMILY:-}" in
      fedora-like)
        ui_spin "Install flatpak (dnf)" \
          sudo dnf -y install flatpak
        ;;
      debian-like)
        ui_spin "Install flatpak (apt)" \
          sudo apt-get install -y --no-install-recommends flatpak
        ;;
      *)
        ui_skip "flatpak not installed and distro family unknown — skipping"
        return 0
        ;;
    esac
  fi

  # See companion comment in install_wslg_flatpak_sync for why the
  # system remote matters even when the user installs apps as --user.
  ui_spin "Add flathub --system (init repo)" \
    sudo flatpak remote-add --system --if-not-exists \
      flathub https://flathub.org/repo/flathub.flatpakrepo

  ui_spin "Add flathub --user" \
    flatpak remote-add --user --if-not-exists \
      flathub https://flathub.org/repo/flathub.flatpakrepo

  # Global flatpak override: deny host /tmp to every user flatpak.
  # On WSLg, /tmp/.X11-unix is a symlink to /mnt/wslg/.X11-unix.
  # Any flatpak whose manifest declares filesystems=/tmp causes bwrap
  # to bind-mount the host /tmp into the sandbox and then attempt a
  # tmpfs mount on /tmp/.X11-unix. The symlink target /mnt/wslg/
  # isn't bound into the sandbox, so the tmpfs mount fails with
  # "Can't mount tmpfs on /newroot/tmp/.X11-unix: No such file or
  # directory" and the app exits before main(). Confirmed affected:
  # org.onlyoffice.desktopeditors. Setting this globally (no APP-ID)
  # means any future flatpak inherits the deny and just works.
  ui_spin "Global flatpak override: --nofilesystem=/tmp" \
    flatpak override --user --nofilesystem=/tmp

  # Pin XCURSOR_SIZE for every flatpak. Wayland-native flatpaks
  # ignore this. Xwayland-via-flatpak ones (CEF apps like ONLYOFFICE,
  # Electron-X11, Java AWT) read XCURSOR_SIZE from env and end up
  # with a ~4x cursor when the compositor scales it up for HiDPI.
  # 24 is the GTK/GNOME default cursor-size.
  ui_spin "Global flatpak override: XCURSOR_SIZE=24" \
    flatpak override --user --env=XCURSOR_SIZE=24
}

install_wslg_flatpak_sync() {
  # WSLg's Start-Menu publisher walks /usr/share/applications +
  # /usr/share/icons at distro startup, and reads only regular files —
  # symlinks are silently skipped (verified WSL 2.7.3.0). Flatpak's
  # per-user installs land in ~/.local/share/flatpak/exports/share/...
  # which the publisher ignores. Sync those files into /usr/share so
  # they appear in the Windows Start Menu.
  #
  # Mechanism: a 1-min systemd user timer fires the sync service. The
  # script is manifest-diffed and near-instant when nothing changed
  # (typically <50ms no-op), so steady-state cost is negligible.
  # Trade-off: a newly-installed flatpak takes up to 1 min to appear
  # in the Start Menu.
  #
  # An earlier version used a `.path` watcher on the flatpak exports
  # dir. That stormed the sudo'd sync service during flatpak installs
  # and gnome-shell XDG churn — it contended with pop-shell verification
  # and caused regressions in the wsl-gnome-rdp-installer pipeline. The
  # timer is debounced by construction.
  ui_step "WSLg flatpak auto-publish"
  ui_spin "Install /usr/local/bin/wsl-flatpak-wslg-sync" \
    sudo install -m 755 \
      "$PROJECT_ROOT/extras/wslg-flatpak-sync/wsl-flatpak-wslg-sync" \
      /usr/local/bin/wsl-flatpak-wslg-sync
  ui_spin "Install /etc/sudoers.d/wsl-flatpak-wslg-sync" \
    sudo install -m 440 \
      "$PROJECT_ROOT/extras/wslg-flatpak-sync/sudoers.wsl-flatpak-wslg-sync" \
      /etc/sudoers.d/wsl-flatpak-wslg-sync

  install -d -m 755 "$SYSTEMD_USER_DIR"

  # Migration: any prior install enabled wsl-flatpak-wslg-sync.path.
  # Disable + remove it so the new timer is the sole trigger. Quiet
  # output — first install on a clean distro has nothing to clean up.
  if [ -f "$SYSTEMD_USER_DIR/wsl-flatpak-wslg-sync.path" ]; then
    ui_spin "Migrate: disable obsolete .path watcher" \
      systemctl --user disable --now wsl-flatpak-wslg-sync.path
    rm -f "$SYSTEMD_USER_DIR/wsl-flatpak-wslg-sync.path" \
          "$SYSTEMD_USER_DIR/default.target.wants/wsl-flatpak-wslg-sync.path"
  fi

  install -m 644 \
    "$PROJECT_ROOT/units/wsl-flatpak-wslg-sync.service" \
    "$SYSTEMD_USER_DIR/wsl-flatpak-wslg-sync.service"
  install -m 644 \
    "$PROJECT_ROOT/units/wsl-flatpak-wslg-sync.timer" \
    "$SYSTEMD_USER_DIR/wsl-flatpak-wslg-sync.timer"

  systemctl --user daemon-reload
  ui_spin "Enable wsl-flatpak-wslg-sync.timer (1min)" \
    systemctl --user enable --now wsl-flatpak-wslg-sync.timer
}

# Initial run after install. Drives the "wsl -t" hint export so the
# RDP installer's verify summary surfaces it.
initial_flatpak_sync_run() {
  ui_step "Initial flatpak → /usr/share sync"
  local manifest=/var/lib/wsl-flatpak-wslg-sync/$USER.list
  local before=0 after=0
  [ -s "$manifest" ] && before=$(sudo wc -l < "$manifest" 2>/dev/null || echo 0)
  ui_spin "wsl-flatpak-wslg-sync $USER" \
    sudo /usr/local/bin/wsl-flatpak-wslg-sync "$USER"
  [ -s "$manifest" ] && after=$(sudo wc -l < "$manifest" 2>/dev/null || echo 0)
  if [ "$after" -gt "$before" ]; then
    export FLATPAKS_NEWLY_LINKED=1
  fi
}
