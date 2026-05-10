# lib/theme_sync.sh — install the Windows ↔ Linux-toolkits theme sync.
#
# The script at /usr/local/bin/wsl-theme-sync is DE-agnostic — it
# writes to whichever toolkit config files exist on this distro:
# gsettings (only if GNOME), GTK 3+4 settings.ini (any GTK), qt6ct
# (any Qt with qt6ct), and an env.d GTK_THEME fallback. See
# extras/wsl-theme-sync/wsl-theme-sync for the per-tier rationale.
#
# Two-stage install:
#
#   oneshot_theme_sync          [always — no env knob]
#     installs the script and fires it once so the first GUI launch
#     after install matches Windows light/dark. Cheap, no ongoing
#     work, doesn't clobber later user customization.
#
#   install_theme_sync_timer    [opt-in via QOL_THEME_SYNC=1]
#     additionally installs + enables a .timer that polls Windows
#     every minute and re-applies. Off by default because it
#     overwrites a user-customized theme on every fire.

# Always-on initial sync. Idempotent: re-runs just refresh the script
# and re-fire it (which is itself a no-op when nothing changed).
oneshot_theme_sync() {
  ui_step "Theme sync (initial Windows → Linux mirror)"
  ui_spin "Install /usr/local/bin/wsl-theme-sync" \
    sudo install -m 755 \
      "$PROJECT_ROOT/extras/wsl-theme-sync/wsl-theme-sync" \
      /usr/local/bin/wsl-theme-sync
  ui_spin "wsl-theme-sync (one-shot mirror)" \
    /usr/local/bin/wsl-theme-sync
}

# Opt-in continuous-polling timer. Adds the .service + .timer units
# and enables --now. Without this the script is only fired by
# oneshot_theme_sync at install time and then never again until the
# next ./install.sh re-run.
install_theme_sync_timer() {
  ui_step "Theme sync timer (continuous Windows-tracking)"

  install -d -m 755 "$SYSTEMD_USER_DIR"
  install -m 644 \
    "$PROJECT_ROOT/units/wsl-theme-sync.service" \
    "$SYSTEMD_USER_DIR/wsl-theme-sync.service"
  install -m 644 \
    "$PROJECT_ROOT/units/wsl-theme-sync.timer" \
    "$SYSTEMD_USER_DIR/wsl-theme-sync.timer"

  systemctl --user daemon-reload
  ui_spin "Enable wsl-theme-sync.timer (1min)" \
    systemctl --user enable --now wsl-theme-sync.timer
}
