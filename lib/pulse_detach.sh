# lib/pulse_detach.sh — fix WSLg PulseAudio for renumbered users.
#
# WSLg's /init pre-creates per-user runtime symlinks at user-bootstrap
# time, including:
#   /run/user/$UID/pulse → /mnt/wslg/runtime-dir/pulse
# /mnt/wslg/runtime-dir/pulse is owned by UID 1000 mode 0700 — WSLg
# hardcodes the assumption that the WSL user is UID 1000. On any
# distro where the user has been renumbered (e.g. via the multi-distro
# cgroup-collision fix that bumps the user to 1001+), the symlink
# target becomes unwritable and pipewire-pulse.socket fails to bind
# /run/user/$UID/pulse/native with EACCES, breaking audio in WSLg.
#
# Ship a user oneshot that detaches the WSLg symlink and creates a
# real mode-0700 directory at /run/user/$UID/pulse only when the
# WSLg target isn't writable. No-op on the original UID-1000 distro;
# unblocks pipewire-pulse on a renumbered one.

install_wslg_pulse_detach() {
  ui_step "WSLg pulse-detach (renumbered-user fix)"
  install -d -m 755 "$SYSTEMD_USER_DIR"
  install -m 644 \
    "$PROJECT_ROOT/units/wslg-pulse-detach.service" \
    "$SYSTEMD_USER_DIR/wslg-pulse-detach.service"

  systemctl --user daemon-reload
  ui_spin "Enable wslg-pulse-detach.service" \
    systemctl --user enable --now wslg-pulse-detach.service
}
