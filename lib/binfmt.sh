# lib/binfmt.sh — re-register WSL's interop binfmt_misc handler at boot.
#
# WSL2's /init normally registers the WSLInterop handler so that any
# DOS-magic (PE/EXE) binary executed inside the distro is dispatched
# to the /init interpreter, which forwards to the Windows host. The
# registration occasionally drops after a `wsl --shutdown` + relaunch,
# leaving wsl.exe / cmd.exe / powershell.exe failing with
# "cannot execute binary file: Exec format error".
#
# Drop a /etc/binfmt.d/WSLInterop.conf so that systemd-binfmt.service
# re-registers WSLInterop from a known-good rule on every boot,
# independent of /init's auto-register behaviour.

install_wslinterop_binfmt() {
  ui_step "WSLInterop binfmt_misc"
  local target=/etc/binfmt.d/WSLInterop.conf
  local src="$PROJECT_ROOT/units/WSLInterop.conf"
  if [ -f "$target" ] && cmp -s "$src" "$target"; then
    ui_skip "$target already in place"
  else
    ui_spin "Install $target" \
      sudo install -D -m 644 "$src" "$target"
  fi
  if [ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    ui_spin "Register WSLInterop in this session" \
      sudo systemctl restart systemd-binfmt.service
  else
    ui_skip "WSLInterop already registered for this session"
  fi
}
