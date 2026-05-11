# lib/xdg_dirs.sh — populate ~/.config/user-dirs.dirs with the
# standard XDG directories (Documents, Downloads, Music, Pictures,
# Videos, Desktop, Templates, Public) and create a ~/Projects folder.
#
# On a normal GNOME box these are created by `xdg-user-dirs-update`
# running from /etc/xdg/autostart/xdg-user-dirs.desktop at gnome-
# session start. WSL distros without a full session manager (terminal-
# only, gnome-shell --mode=user, etc.) skip that autostart entirely;
# the dirs never appear and file dialogs land on a flat $HOME with
# .config/.cache/.local visible. Nautilus's sidebar gates the
# Documents/Music/Pictures/Videos shortcuts on user-dirs.dirs being
# populated, so an empty file results in those shortcuts vanishing.
#
# A bare `xdg-user-dirs-update` run only initialises the file on
# first run — it won't backfill missing entries. Iterate explicitly
# with `--set NAME PATH`; each call is idempotent.
#
# ~/Projects isn't an XDG-defined dir but is a near-universal default
# for source-tree clones. Created here as a folder; sidebar
# bookmarking is left to the desktop-specific installer (e.g.
# wsl-gnome-rdp-installer's install_projects_dir handles the Nautilus
# bookmarks file — that step is GNOME-aware and out of scope here).

setup_xdg_user_dirs() {
  ui_step "XDG user dirs + ~/Projects"

  # Install xdg-user-dirs if missing — same pattern as wslu.sh. Package
  # name is `xdg-user-dirs` on both Fedora and Debian. Without it the
  # `--set NAME PATH` loop below has nothing to call; skipping leaves
  # Nautilus / file-dialog sidebars without Documents/Music/Pictures/
  # Videos entries, which is exactly what this tier exists to fix.
  if ! command -v xdg-user-dirs-update >/dev/null 2>&1; then
    case "$DISTRO_FAMILY" in
      fedora-like)
        ui_spin "Install xdg-user-dirs (dnf)" \
          sudo dnf install -y -q xdg-user-dirs
        ;;
      debian-like)
        export DEBIAN_FRONTEND=noninteractive
        ui_spin "Install xdg-user-dirs (apt)" \
          sudo apt-get install -y -qq xdg-user-dirs
        ;;
      *)
        ui_skip "no $DISTRO_FAMILY recipe — install xdg-user-dirs manually for sidebar dir entries"
        return 0
        ;;
    esac
  fi

  local pair name dir
  for pair in DESKTOP:Desktop DOWNLOAD:Downloads DOCUMENTS:Documents \
              MUSIC:Music PICTURES:Pictures VIDEOS:Videos \
              TEMPLATES:Templates PUBLICSHARE:Public; do
    name=${pair%:*}
    dir=${pair#*:}
    mkdir -p "$HOME/$dir"
    xdg-user-dirs-update --set "$name" "$HOME/$dir" 2>/dev/null || true
  done
  ui_ok "user-dirs.dirs"
  ui_detail "Documents, Downloads, Music, Pictures, Videos, Desktop, Templates, Public"

  mkdir -p "$HOME/Projects"
  ui_ok "~/Projects"
}
