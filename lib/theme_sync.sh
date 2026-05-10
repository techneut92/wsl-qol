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
#
# When invoked from a meta-installer that runs wsl-qol BEFORE the
# GNOME stack is on disk (the RDP installer does this so binfmt /
# flatpak / pulse-detach are in place when its dnf step starts), the
# org.gnome.desktop.interface schema isn't registered yet, so the
# gsettings tier of the script silently no-ops. We detect that
# explicitly and skip the fire — the meta-installer is expected to
# re-fire /usr/local/bin/wsl-theme-sync after its package install
# step. Without this skip, the unhelpful-no-op surfaces as "everything
# looks green" while color-scheme actually never propagates.
oneshot_theme_sync() {
  ui_step "Theme sync (initial Windows → Linux mirror)"

  # Ensure the runtime deps. Stripped Fedora/Debian WSL images don't
  # carry these by default, and without them tier 1 of the sync
  # script (the gsettings write) silently no-ops — leaving libadwaita
  # apps stuck on the default light scheme even though Windows is
  # dark. glib2 provides the `gsettings` binary, dconf is the
  # backing store, gsettings-desktop-schemas registers the
  # org.gnome.desktop.interface schema. Best-effort: a missing
  # package manager just means the user's distro isn't one we
  # auto-install on, and the schema-presence check below still
  # correctly skips with a clear "defer to caller" message.
  case "$DISTRO_FAMILY" in
    debian-like)
      sudo apt-get install -y -qq \
        glib2.0-bin dconf-cli gsettings-desktop-schemas \
        >/dev/null 2>&1 || true
      ;;
    fedora-like)
      sudo dnf install -y -q \
        glib2 dconf gsettings-desktop-schemas \
        >/dev/null 2>&1 || true
      ;;
  esac

  ui_spin "Install /usr/local/bin/wsl-theme-sync" \
    sudo install -m 755 \
      "$PROJECT_ROOT/extras/wsl-theme-sync/wsl-theme-sync" \
      /usr/local/bin/wsl-theme-sync
  if command -v gsettings >/dev/null 2>&1 \
     && gsettings list-schemas 2>/dev/null \
        | grep -q '^org\.gnome\.desktop\.interface$'; then
    ui_spin "wsl-theme-sync (one-shot mirror)" \
      /usr/local/bin/wsl-theme-sync
  else
    ui_skip "GNOME schemas not registered yet — defer fire to caller"
  fi
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
