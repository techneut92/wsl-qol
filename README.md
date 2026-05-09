# wsl-qol

Quality-of-life fixes for WSL2 — desktop-agnostic. Install on any
Fedora-/Debian-like WSL2 distro to get:

- **WSLInterop binfmt_misc auto-recovery** — `wsl.exe`, `cmd.exe`,
  `powershell.exe` keep working across `wsl --shutdown`. Drops a
  `/etc/binfmt.d/WSLInterop.conf` so `systemd-binfmt.service`
  re-registers it on every boot regardless of `/init`'s mood.

- **Flatpak Start-Menu auto-publish via WSLg** — every time you
  `flatpak install --user` something, a systemd `.path` watcher trips
  and a sync script mirrors the new app's `.desktop` and icons into
  `/usr/share` so WSLg's Start-Menu publisher picks them up. Survives
  uninstalls (manifest-tracked).

- **Theme sync between Windows and Linux toolkits** — a 1-minute
  systemd `.timer` reads
  `HKCU\…\Personalize\AppsUseLightTheme` via `reg.exe` and writes to
  whichever toolkit config is relevant on this distro:
  * `gsettings` keys (when GNOME is around)
  * GTK 3 + 4 `settings.ini`
  * `qt6ct.conf` (when qt6ct is installed)
  * `~/.config/environment.d/45-theme.conf` GTK_THEME fallback

- **WSLg PulseAudio detach** for renumbered users (UID ≠ 1000) —
  WSLg pre-creates `/run/user/$UID/pulse` as a symlink into
  `/mnt/wslg/runtime-dir/pulse` (mode 0700, owned UID 1000); a
  renumbered user can't bind through it. A user oneshot detaches
  the symlink and substitutes a real directory only when needed.

- **Flatpak base setup** — flathub remote on both `--system` and
  `--user` (system path init is required for any bare `flatpak run`
  to succeed; `.desktop` Exec lines never include `--user`), plus a
  global `--nofilesystem=/tmp` override that keeps WSLg's
  `/tmp/.X11-unix` symlink-into-`/mnt/wslg/` from crashing flatpaks
  like ONLYOFFICE before they ever reach `main()`.

## Install

```sh
git clone https://github.com/techneut92/wsl-qol.git
cd wsl-qol
./install.sh
```

Re-running is idempotent. Each fix can be opted out via env (default
on):

```
QOL_BINFMT=0          # skip WSLInterop drop-in
QOL_FLATPAK=0         # skip flathub remotes + global overrides
QOL_FLATPAK_SYNC=0    # skip Start-Menu auto-publish
QOL_PULSE_DETACH=0    # skip WSLg pulse fix
QOL_THEME_SYNC=0      # skip theme sync timer
```

## What this is NOT

- It does not install a desktop environment.
- It does not configure RDP / `gnome-remote-desktop`. For that, see
  [wsl-gnome-rdp-installer](https://github.com/techneut92/wsl-gnome-rdp-installer)
  which depends on this repo.

## Files dropped on disk

| Path | Purpose |
| --- | --- |
| `/etc/binfmt.d/WSLInterop.conf` | Re-register interop at boot |
| `/etc/sudoers.d/wsl-flatpak-wslg-sync` | NOPASSWD for sync script |
| `/usr/local/bin/wsl-flatpak-wslg-sync` | Mirror flatpak exports → /usr/share |
| `/usr/local/bin/wsl-theme-sync` | Read Windows reg, write toolkit configs |
| `~/.config/systemd/user/wsl-flatpak-wslg-sync.{path,service}` | Watch flatpak exports, kick sync |
| `~/.config/systemd/user/wsl-theme-sync.{service,timer}` | 1-min theme poll |
| `~/.config/systemd/user/wslg-pulse-detach.service` | Renumbered-user pulse fix |
| `/var/lib/wsl-flatpak-wslg-sync/<user>.list` | Sync manifest for cleanup-on-uninstall |

## License

MIT. See [LICENSE](LICENSE).
