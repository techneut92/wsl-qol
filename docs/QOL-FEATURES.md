# wsl-qol features — catalog and rebuild plan

Authoritative list of every action wsl-qol takes (or used to take). This doc travels with the repo so the regression-test rebuild stays anchored to a real spec.

**Source of truth for "correct behavior" is the pre-QOL-split installer** at commit `b877973` of `wsl-gnome-rdp-installer`. Everything below that says "pre-split equivalent" links back to that baseline. If wsl-qol's behavior diverges from `b877973`'s, the pre-split version wins.

## Status legend

- **`active`** — implemented and called from `install.sh`
- **`disabled`** — code present, NOT called from `install.sh` (re-enable to test)
- **`removed`** — code deleted, awaiting rebuild

## Features

### 1. WSLInterop binfmt — `QOL_BINFMT`

- **What:** writes `/etc/binfmt.d/WSLInterop.conf` registering the MZ→`/init` handler so `.exe` binaries dispatch to Windows host. Restarts `systemd-binfmt.service`.
- **Why:** WSL's `/init` normally registers this on boot, but it occasionally drops after `wsl --shutdown`. The drop-in makes it survive.
- **Pre-split equivalent:** `units/WSLInterop.conf` + install logic in `lib/packages.sh` of `wsl-gnome-rdp-installer@b877973`.
- **Files:** `lib/binfmt.sh`, `units/WSLInterop.conf`.
- **Status:** `disabled` (call commented out in `install.sh`)

### 2. Flatpak remotes + global overrides — `QOL_FLATPAK`

- **What:** auto-installs `flatpak` via dnf/apt if missing, adds flathub remote (system + user), sets `flatpak override --user --nofilesystem=/tmp` (works around bwrap fail on WSLg's symlink-X11-unix), pins `XCURSOR_SIZE=24`.
- **Why:** WSLg's `/tmp/.X11-unix` is a symlink to `/mnt/wslg/...`; flatpaks declaring `filesystems=/tmp` crash without the override. ONLYOFFICE etc. need the cursor pin.
- **Pre-split equivalent:** flatpak setup in `lib/packages.sh` of `wsl-gnome-rdp-installer@b877973`.
- **Files:** `lib/flatpak.sh::setup_flatpak_remotes`.
- **Status:** `disabled`

### 3. WSLg flatpak Start-Menu auto-publish — `QOL_FLATPAK_SYNC`

- **What:** ships `/usr/local/bin/wsl-flatpak-wslg-sync` + `/etc/sudoers.d/wsl-flatpak-wslg-sync` (NOPASSWD for that one script) + user `.path` and `.service` units. The `.path` unit watches `~/.local/share/flatpak/exports/share/applications`; on change, runs `sudo wsl-flatpak-wslg-sync $USER` which mirrors `.desktop` + icons into `/usr/share/applications` (where WSLg picks them up for the Windows Start Menu).
- **Why:** WSLg only indexes `/usr/share/...`; per-user flatpak installs go to `~/.local/share/...` and never appear in Windows Start Menu without this mirror.
- **Pre-split equivalent:** `units/wsl-flatpak-wslg-sync.path` + `.service` + `extras/wslg-flatpak-sync/*` in `wsl-gnome-rdp-installer@b877973`.
- **Files:** `lib/flatpak.sh::install_wslg_flatpak_sync`, `lib/flatpak.sh::initial_flatpak_sync_run`, `units/wsl-flatpak-wslg-sync.{path,service}`, `extras/wslg-flatpak-sync/{wsl-flatpak-wslg-sync,sudoers.wsl-flatpak-wslg-sync}`.
- **Status:** `disabled`
- **Suspect ranking for the pop-shell flake:** **HIGH**. `.path` units fire whenever the watched dir changes — and `gnome-shell-headless` restart during pop-shell phase shakes XDG state. Could fire mid-verify and grab sudo + IO.

### 4. WSLg pulse-detach — `QOL_PULSE_DETACH`

- **What:** user oneshot service that removes the WSLg pre-created `/run/user/$UID/pulse` symlink (target is hardcoded mode `0700 UID 1000`) before pipewire-pulse tries to bind. Lets pipewire-pulse create its own real socket dir on renumbered UIDs.
- **Why:** see `project_wslg_renumber_pulse.md` memory. Without this, audio breaks on any non-1000 UID (i.e. after our `usermod -u 1001` renumber).
- **Pre-split equivalent:** `units/wslg-pulse-detach.service` in `wsl-gnome-rdp-installer@b877973`.
- **Files:** `lib/pulse_detach.sh`, `units/wslg-pulse-detach.service`.
- **Status:** `disabled`
- **Audio pre-split note:** user has no recall of audio actually breaking pre-patch. Necessity unconfirmed (see `project_pulse_detach_uncertain_necessity.md`).

### 5. Windows theme sync — `QOL_THEME_SYNC` — **REMOVED**

- **What it was:** systemd user `.timer` that fires every minute, queries `reg.exe HKCU\...\AppsUseLightTheme`, sets `org.gnome.desktop.interface.color-scheme` + `gtk-theme` to match Windows light/dark.
- **Why removed (2026-05-10):** the wsl-qol re-implementation appeared broken in user testing. Pre-split version was also broken (different reason — user systemd PATH lacks `/mnt/c/WINDOWS/system32`, so `command -v reg.exe || exit 0` made the script silently no-op). See `project_b877973_themesync_path_bug.md`.
- **Intent:** WANT TO REBUILD — feature is desired, just needs a working implementation. See `project_themesync_to_rebuild.md` memory for the spec we want next time.
- **Status:** `removed` (files deleted, call removed from `install.sh`, source line removed)

## Bootstrap mechanics (the "QOL split" itself)

The `wsl-gnome-rdp-installer` calls wsl-qol via `lib/qol_bootstrap.sh::bootstrap_wsl_qol()`:

1. Clone or `git pull --ff-only` `~/.local/share/wsl-qol/` (depth=20)
2. `bash $dir/install.sh` with current env passed through

This bootstrap mechanism stays even when all features are disabled — the regression test is "does the empty bootstrap alone break pop-shell, or do specific features break it."

## Regression-test re-enable order

When re-enabling features to find the pop-shell flake cause, do them in this order (lowest-suspicion first so a regression points clearly at the last-enabled tier):

1. `QOL_BINFMT=1` — single drop-in + one binfmt restart, no user-systemd churn
2. `QOL_PULSE_DETACH=1` — adds one user oneshot, one daemon-reload, restarts pipewire-pulse once
3. `QOL_FLATPAK=1` — flatpak remote-add + 2 overrides, no user-systemd units
4. `QOL_FLATPAK_SYNC=1` — adds `.path` + `.service` user units, 1 daemon-reload, enables `.path` (which then watches XDG dirs forever) — **highest suspicion**

Test pop-shell behavior after each enable. First regression points at the offending feature.
