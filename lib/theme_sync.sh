# lib/theme_sync.sh — install the Windows ↔ Linux-toolkits theme sync.
#
# The script at /usr/local/bin/wsl-theme-sync is DE-agnostic — it
# writes to whichever toolkit config files exist on this distro:
# gsettings (only if GNOME), GTK 3+4 settings.ini (any GTK), qt6ct
# (any Qt with qt6ct), and an env.d GTK_THEME fallback. Polls Windows
# every minute via reg.exe interop and updates whatever needs updating.
# No-op on idle ticks. See extras/wsl-theme-sync/wsl-theme-sync for
# the per-tier rationale.

install_theme_sync() {
  ui_step "Theme sync (Windows ↔ Linux toolkits)"
  ui_spin "Install /usr/local/bin/wsl-theme-sync" \
    sudo install -m 755 \
      "$PROJECT_ROOT/extras/wsl-theme-sync/wsl-theme-sync" \
      /usr/local/bin/wsl-theme-sync

  install -d -m 755 "$SYSTEMD_USER_DIR"
  install -m 644 \
    "$PROJECT_ROOT/units/wsl-theme-sync.service" \
    "$SYSTEMD_USER_DIR/wsl-theme-sync.service"
  install -m 644 \
    "$PROJECT_ROOT/units/wsl-theme-sync.timer" \
    "$SYSTEMD_USER_DIR/wsl-theme-sync.timer"

  systemctl --user daemon-reload
  ui_spin "Enable wsl-theme-sync.timer" \
    systemctl --user enable --now wsl-theme-sync.timer
}

initial_theme_sync_run() {
  ui_step "Initial theme sync"
  ui_spin "wsl-theme-sync (one-shot)" /usr/local/bin/wsl-theme-sync
}
