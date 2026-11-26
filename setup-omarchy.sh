#!/usr/bin/env bash
# Resilient Omarchy post-install debloat & dotfiles setup script.
# Continues on errors, skips non-existent items silently, and reports any real failures.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=()

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

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
if (( ${#TO_REMOVE[@]} > 0 )); then
  log "Removing unused packages: ${TO_REMOVE[*]}"
  run_step "Remove bloat packages" sudo pacman -Rns --noconfirm "${TO_REMOVE[@]}"
fi

# 2. Install essential packages (only those missing)
ESSENTIAL_PKGS=(foot rmpc mpd mpd-mpris pacman-contrib mold clang gcc)
TO_INSTALL=()
for pkg in "${ESSENTIAL_PKGS[@]}"; do
  if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
    TO_INSTALL+=("$pkg")
  fi
done
if (( ${#TO_INSTALL[@]} > 0 )); then
  log "Installing essential packages: ${TO_INSTALL[*]}"
  run_step "Install pacman essentials" sudo pacman -S --noconfirm --needed "${TO_INSTALL[@]}"
fi

if ! pacman -Qq zen-browser-bin >/dev/null 2>&1 && command -v yay >/dev/null 2>&1; then
  log "Installing zen-browser-bin via yay..."
  run_step "Install zen-browser-bin" yay -S --noconfirm --needed zen-browser-bin
fi

# 3. Disable unwanted user services (only if present)
USER_DISABLE=(bt-agent.service voxtype.service mpd.service mpd-mpris.service owed.service)
for unit in "${USER_DISABLE[@]}"; do
  if unit_exists_user "$unit"; then
    log "Disabling user unit: $unit"
    run_step "Disable user unit $unit" systemctl --user disable --now "$unit"
  fi
done

# Disable localsearch-3 (GNOME file indexer)
if unit_exists_user "localsearch-3.service"; then
  log "Stopping & masking localsearch-3.service..."
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

# Disable Omarchy crash watcher if active
if command -v omarchy >/dev/null 2>&1 && [[ ! -f "$HOME/.local/state/omarchy/toggles/crash-capture-off" ]]; then
  log "Turning off omarchy crash-capture..."
  run_step "Toggle crash-capture off" omarchy toggle crash-capture
fi

# 4. Disable unwanted system services & enable SSD TRIM
SYS_DISABLE=(bluetooth.service avahi-daemon.service avahi-daemon.socket docker.socket)
for unit in "${SYS_DISABLE[@]}"; do
  if unit_exists_system "$unit"; then
    log "Disabling system unit: $unit"
    run_step "Disable system unit $unit" sudo systemctl disable --now "$unit"
  fi
done

if unit_exists_system "fstrim.timer"; then
  log "Enabling weekly SSD TRIM (fstrim.timer)..."
  run_step "Enable fstrim.timer" sudo systemctl enable --now fstrim.timer
fi

# 5. Pacman auto-clean hook, journald 100M cap, and BFQ I/O scheduler
if command -v paccache >/dev/null 2>&1; then
  log "Configuring pacman post-transaction cache cleanup hook..."
  run_step "Create paccache hook" sudo bash -c 'mkdir -p /etc/pacman.d/hooks && printf "[Trigger]\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nType = Package\nTarget = *\n\n[Action]\nDescription = Cleaning pacman cache\nWhen = PostTransaction\nExec = /bin/sh -c \"/usr/bin/paccache -rk0; /usr/bin/paccache -ruk0\"\n" > /etc/pacman.d/hooks/paccache.hook'
fi

log "Capping systemd journal at 100M..."
run_step "Configure journald 100M cap" sudo bash -c 'mkdir -p /etc/systemd/journald.conf.d && printf "[Journal]\nSystemMaxUse=100M\n" > /etc/systemd/journald.conf.d/size.conf && journalctl --vacuum-size=100M && systemctl restart systemd-journald'

log "Setting BFQ I/O scheduler for sd* drives..."
run_step "Configure BFQ udev rule" sudo bash -c 'printf "ACTION==\"add|change\", KERNEL==\"sd[a-z]\", ATTR{queue/scheduler}=\"bfq\"\n" > /etc/udev/rules.d/60-ioscheduler.rules'

# 6. Deploy dotfiles from this repository
log "Copying dotfiles into $HOME..."
DOTFILES=(
  ".config/hypr/bindings.lua"
  ".config/hypr/looknfeel.lua"
  ".config/hypr/input.lua"
  ".config/omarchy/shell.json"
  ".config/foot/foot.ini"
  ".config/mpv/mpv.conf"
  ".config/systemd/user/cache-clean.service"
  ".local/bin/omarchy-cache-clean"
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
if [[ -f "$HOME/.local/bin/omarchy-cache-clean" ]]; then
  chmod +x "$HOME/.local/bin/omarchy-cache-clean" 2>/dev/null || true
fi

# Enable 2-day cache-clean user service
if [[ -f "$HOME/.config/systemd/user/cache-clean.service" ]]; then
  mkdir -p "$HOME/.local/state"
  if [[ ! -f "$HOME/.local/state/cache-clean-next" ]]; then
    date -d '+2 days' +%s > "$HOME/.local/state/cache-clean-next" 2>/dev/null || true
  fi
  run_step "Enable cache-clean.service" bash -c 'systemctl --user daemon-reload && systemctl --user enable cache-clean.service'
fi

# 7. Reload Hyprland & Omarchy shell if running
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  run_step "Reload Hyprland" hyprctl reload
fi
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
fi

echo ""
if (( ${#FAILURES[@]} == 0 )); then
  log "Setup complete with 0 errors!"
else
  warn "Setup finished, but the following steps failed:"
  for f in "${FAILURES[@]}"; do
    printf '  - %s\n' "$f" >&2
  done
  exit 1
fi
