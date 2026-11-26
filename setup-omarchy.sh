#!/usr/bin/env bash
# Interactive, resilient Omarchy post-install debloat & dotfiles setup script.
# Asks before each section, skips non-existent items silently, and continues on errors.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
FAILURES=()
AUTO_YES=false

# If piped via `curl -fsSL <url> | bash`, clone the repo and re-exec from disk
if [[ ! -d "$SCRIPT_DIR/.config" ]]; then
  echo "[*] Bootstrapping dotfiles repository..."
  if ! command -v git >/dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed git || exit 1
  fi
  REPO_DIR="$HOME/github/dotfiles"
  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" pull --ff-only || true
  else
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone https://github.com/RustamSheoran/dotfiles.git "$REPO_DIR" || exit 1
  fi
  exec bash "$REPO_DIR/setup-omarchy.sh" </dev/tty
fi

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

ask() {
  local prompt="$1"
  if [[ "$AUTO_YES" == true ]]; then
    log "Auto-yes: $prompt"
    return 0
  fi
  local reply
  read -r -p "[?] $prompt [y/N/yyy=all]: " reply </dev/tty
  if [[ "$reply" == "yyy" ]]; then
    AUTO_YES=true
    return 0
  fi
  [[ "$reply" =~ ^[Yy]$ ]]
}

run_step() {
  local desc="$1"
  shift
  if "$@"; then
    return 0
  else
    warn "Failed: $desc"
    FAILURES+=("$desc")
    return 1
  fi
}

unit_exists_user() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q "^$1"
}

unit_exists_system() {
  systemctl list-unit-files "$1" --no-legend 2>/dev/null | grep -q "^$1"
}

log "Starting Omarchy debloat & setup..."

# 0. Omarchy preinstalled apps/webapps
if [[ ! -f "$HOME/.local/state/omarchy/preinstalls-removed" ]] && command -v omarchy-remove-preinstalls >/dev/null 2>&1; then
  if ask "Remove Omarchy preinstalled apps/webapps (omarchy-remove-preinstalls)?"; then
    run_step "Remove Omarchy preinstalls" omarchy-remove-preinstalls
  fi
fi

# 1. Remove unused packages (only those actually installed)
BLOAT_PKGS=(
  signal-desktop typora serein-bin
  docker docker-compose docker-buildx ufw-docker lazydocker
  system-config-printer
  fcitx5-mozc fcitx5-chinese-addons fcitx5-chewing fcitx5-hangul
)
TO_REMOVE=()
for pkg in "${BLOAT_PKGS[@]}"; do
  if pacman -Qq "$pkg" >/dev/null 2>&1; then
    TO_REMOVE+=("$pkg")
  fi
done
if (( ${#TO_REMOVE[@]} > 0 )) && ask "Remove unused packages (${TO_REMOVE[*]})?"; then
  run_step "Remove bloat packages" sudo pacman -Rns --noconfirm "${TO_REMOVE[@]}"
fi

# 2. Install essential packages (only those missing)
ESSENTIAL_PKGS=(foot rmpc mpd mpd-mpris omacalc aether pacman-contrib mold clang gcc)
TO_INSTALL=()
for pkg in "${ESSENTIAL_PKGS[@]}"; do
  if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
    TO_INSTALL+=("$pkg")
  fi
done
if (( ${#TO_INSTALL[@]} > 0 )) && ask "Install essential packages (${TO_INSTALL[*]})?"; then
  run_step "Install pacman essentials" sudo pacman -S --noconfirm --needed "${TO_INSTALL[@]}"
fi

if ! pacman -Qq zen-browser-bin >/dev/null 2>&1 && command -v yay >/dev/null 2>&1; then
  if ask "Install Zen Browser (zen-browser-bin via yay)?"; then
    run_step "Install zen-browser-bin" yay -S --noconfirm --needed zen-browser-bin
  fi
fi

if [[ -f /usr/share/applications/zen.desktop ]] && command -v xdg-settings >/dev/null 2>&1; then
  if ask "Set Zen as your default web browser?"; then
    run_step "Set Zen as default browser" xdg-settings set default-web-browser zen.desktop
  fi
fi

# 3. Disable unwanted services & enable SSD TRIM
if ask "Disable background bloat services (bluetooth, avahi, voxtype, owed, localsearch-3, mpd autostart, crash-capture) and enable SSD TRIM?"; then
  USER_DISABLE=(bt-agent.service voxtype.service mpd.service mpd-mpris.service owed.service)
  for unit in "${USER_DISABLE[@]}"; do
    if unit_exists_user "$unit"; then
      run_step "Disable user unit $unit" systemctl --user disable --now "$unit"
    fi
  done

  if unit_exists_user "localsearch-3.service"; then
    systemctl --user stop localsearch-3.service 2>/dev/null || true
    run_step "Mask localsearch-3.service" systemctl --user mask localsearch-3.service
  fi
  mkdir -p "$HOME/.config/autostart"
  run_step "Hide localsearch-3 autostart" bash -c 'cat > "$HOME/.config/autostart/localsearch-3.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=LocalSearch
Hidden=true
EOF'

  if command -v omarchy >/dev/null 2>&1 && [[ ! -f "$HOME/.local/state/omarchy/toggles/crash-capture-off" ]]; then
    run_step "Toggle crash-capture off" omarchy toggle crash-capture
  fi

  SYS_DISABLE=(bluetooth.service avahi-daemon.service avahi-daemon.socket docker.socket)
  for unit in "${SYS_DISABLE[@]}"; do
    if unit_exists_system "$unit"; then
      run_step "Disable system unit $unit" sudo systemctl disable --now "$unit"
    fi
  done

  if unit_exists_system "fstrim.timer"; then
    run_step "Enable fstrim.timer" sudo systemctl enable --now fstrim.timer
  fi
fi

# 4. Pacman auto-clean hook, journald 100M cap, and BFQ I/O scheduler
if ask "Configure Pacman auto-clean hook (keep 0), journald 100M cap, and BFQ I/O scheduler?"; then
  if command -v paccache >/dev/null 2>&1; then
    run_step "Create paccache hook" sudo bash -c 'mkdir -p /etc/pacman.d/hooks && printf "[Trigger]\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nType = Package\nTarget = *\n\n[Action]\nDescription = Cleaning pacman cache\nWhen = PostTransaction\nExec = /bin/sh -c \"/usr/bin/paccache -rk0; /usr/bin/paccache -ruk0\"\n" > /etc/pacman.d/hooks/paccache.hook'
  fi

  run_step "Configure journald 100M cap" sudo bash -c 'mkdir -p /etc/systemd/journald.conf.d && printf "[Journal]\nSystemMaxUse=100M\n" > /etc/systemd/journald.conf.d/size.conf && journalctl --vacuum-size=100M && systemctl restart systemd-journald'

  run_step "Configure BFQ udev rule" sudo bash -c 'printf "ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/scheduler}=\"bfq\"\n" > /etc/udev/rules.d/60-ioscheduler.rules'
fi

# 5. Deploy dotfiles
if ask "Copy dotfiles into $HOME?"; then
  DOTFILES=(
    ".config/hypr/bindings.lua"
    ".config/hypr/looknfeel.lua"
    ".config/hypr/input.lua"
    ".config/omarchy/shell.json"
    ".config/omarchy/shell.toml"
    ".config/foot/foot.ini"
    ".bashrc"
    ".clang-format"
  )
  for rel in "${DOTFILES[@]}"; do
    src="$SCRIPT_DIR/$rel"
    dst="$HOME/$rel"
    if [[ -f "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      run_step "Copy $rel" cp "$src" "$dst"
    fi
  done

  if [[ -d "$SCRIPT_DIR/.config/omarchy/themes/green-anime" ]]; then
    if ask "Restore and apply the green-anime theme + wallpaper?"; then
      mkdir -p "$HOME/.config/omarchy/themes"
      run_step "Copy green-anime theme" cp -r "$SCRIPT_DIR/.config/omarchy/themes/green-anime" "$HOME/.config/omarchy/themes/"
      if command -v omarchy >/dev/null 2>&1; then
        run_step "Apply green-anime theme" omarchy theme set green-anime
        if [[ -f "$HOME/.config/omarchy/themes/green-anime/backgrounds/wallhaven-po5mlj.jpg" ]]; then
          omarchy-theme-bg-set "$HOME/.config/omarchy/themes/green-anime/backgrounds/wallhaven-po5mlj.jpg" >/dev/null 2>&1 || true
        fi
      fi
    fi
  fi

  if command -v omarchy >/dev/null 2>&1; then
    for plugin in omarchy.agents omarchy.elsewhen omarchy.weather omarchy.dropbox omarchy.tailscale; do
      omarchy plugin disable "$plugin" >/dev/null 2>&1 || true
    done
  fi
  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    run_step "Reload Hyprland" hyprctl reload
  fi
  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
  fi
fi

# 6. Ask to generate SSH key for GitHub only if none exists
if [[ ! -f "$HOME/.ssh/id_ed25519" && ! -f "$HOME/.ssh/id_rsa" ]] && command -v ssh-keygen >/dev/null 2>&1; then
  if ask "No SSH key found. Generate one for GitHub?"; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    run_step "Generate SSH key" ssh-keygen -t ed25519 -C "${USER:-user}@$(hostname)" -f "$HOME/.ssh/id_ed25519"
  fi
fi

# 7. Ask to set up LazyVim (specialized for Competitive Programming)
if command -v git >/dev/null 2>&1; then
  if ask "Install my LazyVim config (specialized for Competitive Programming)?"; then
    if [[ -d "$HOME/.config/nvim" ]]; then
      mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)" 2>/dev/null || true
    fi
    if run_step "Clone RustamSheoran/nvim" git clone https://github.com/RustamSheoran/nvim.git "$HOME/.config/nvim"; then
      run_step "Run nvim/setup.sh" bash "$HOME/.config/nvim/setup.sh"
    fi
  fi
fi

echo ""
if (( ${#FAILURES[@]} == 0 )); then
  log "Setup complete with 0 errors!"
else
  warn "Setup finished, but the following steps failed:"
  for f in "${FAILURES[@]}"; do
    printf '  - %s\n' "$f" >&2
  done
fi

echo ""
log "Next steps:"
if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  echo "  1. View or copy your SSH public key and add it at https://github.com/settings/keys:"
  echo "       cat ~/.ssh/id_ed25519.pub"
  echo "       wl-copy < ~/.ssh/id_ed25519.pub"
  echo "  2. Test GitHub SSH:"
  echo "       ssh -T git@github.com"
fi
echo "  3. Reload bash config (or open a new terminal):"
echo "       source ~/.bashrc"

(( ${#FAILURES[@]} == 0 )) || exit 1
