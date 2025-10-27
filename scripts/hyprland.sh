#!/usr/bin/env bash
set -e

# ==================================================
# 🐧 Hyprland Minimal Setup for Arch Linux
# ==================================================

# Colors and logging
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok() { echo -e "\033[1;32m[DONE]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" && exit 1; }

# Check Arch
. /etc/os-release 2>/dev/null || true
if [ "${ID:-}" != "arch" ] && [[ "${ID_LIKE:-}" != *arch* ]]; then
  err "❌ For Arch Linux only."
fi

# Check requirements
check_requirements() {
  log "🔍 Checking system requirements..."
  if ! sudo -n true 2>/dev/null; then
    err "❌ Requires sudo privileges."
  fi
  ok "✅ Requirements check completed"
}

# Wait package locks
wait_pkg_locks() {
  local waited=0
  while [ -f /var/lib/pacman/db.lck ]; do
    if [ $waited -ge 120 ]; then
      err "❌ Timed out waiting for pacman lock (120s)"
    fi
    log "⏳ Waiting for pacman lock... (${waited}s)"
    sleep 2
    waited=$((waited+2))
  done
}

# Pacman install
pacman_install() {
  local pkgs=("$@")
  local attempts=0
  local max_attempts=3
  while [ $attempts -lt $max_attempts ]; do
    wait_pkg_locks
    if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
      return 0
    fi
    attempts=$((attempts+1))
    warn "⚠️ Pacman failed — retrying (${attempts}/${max_attempts})"
    sleep $((attempts * 5))
  done
  return 1
}

# Setup AUR helper
setup_aur_helper() {
  log "🔍 Checking AUR helper..."
  if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
    return 0
  elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
    return 0
  fi
  read -p "Install paru AUR helper? (Y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    log "📦 Installing paru..."
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
    AUR_HELPER="paru"
  else
    AUR_HELPER=""
    warn "⚠️ No AUR helper. Skipping AUR packages."
  fi
}

# Install base deps
install_base_deps() {
  log "🐧 Updating system..."
  wait_pkg_locks
  sudo pacman -Syu --noconfirm
  ok "✅ System updated"
  log "📦 Installing base Wayland deps..."
  pacman_install git curl wget base-devel meson ninja cmake pkgconf \
    wayland-protocols vulkan-icd-loader libxkbcommon libinput \
    libx11 xorg-xwayland xdg-desktop-portal-wlr
  ok "✅ Base deps installed"
}

# Install Hyprland minimal
install_hyprland_minimal() {
  log "🧩 Installing Hyprland minimal..."

  # Remove pulseaudio
  if pacman -Qq pulseaudio > /dev/null 2>&1; then
    log "🔄 Removing pulseaudio..."
    sudo pacman -Rns --noconfirm pulseaudio pulseaudio-bluetooth pulseaudio-alsa || true
    ok "✅ Pulseaudio removed."
  fi

  # Core: hyprland, waybar, wofi, grim/slurp, pipewire, network
  pacman_install hyprland waybar wofi grim slurp wl-clipboard brightnessctl \
    pavucontrol networkmanager pipewire pipewire-pulse wireplumber

  # Optional: mako, swww
  read -p "Install mako (notifications) and swww (wallpaper transitions)? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    pacman_install mako
    [ -n "$AUR_HELPER" ] && $AUR_HELPER -S --noconfirm swww
  fi

  # AUR: nerd fonts
  if [ -n "$AUR_HELPER" ]; then
    $AUR_HELPER -S --noconfirm ttf-jetbrains-mono-nerd
  else
    warn "⚠️ Skip ttf-jetbrains-mono-nerd (install manually for fonts)"
  fi

  ok "✅ Hyprland minimal installed"
}

# Deploy wm configs
deploy_wm_configs() {
  log "📁 Deploying WM configs (skip if exists)..."
  # Ensure ~/.config permissions
  mkdir -p ~/.config
  chown $USER:$USER ~/.config
  chmod u+rwx ~/.config

  if [ -d ~/.config ]; then
    local backup_dir="$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"
    log "💾 Backup to $backup_dir"
    cp -r ~/.config "$backup_dir"
  fi

  mkdir -p ~/.config/{hypr,waybar,wofi,mako,swww}
  [ ! -d ~/.config/hypr ] && cp -r "$(dirname "$0")/../configs/wm/hypr/"* ~/.config/hypr/
  [ ! -d ~/.config/waybar ] && cp -r "$(dirname "$0")/../configs/wm/waybar/"* ~/.config/waybar/
  [ ! -d ~/.config/wofi ] && cp -r "$(dirname "$0")/../configs/wm/wofi/"* ~/.config/wofi/
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    [ ! -f ~/.config/mako/config ] && cp "$(dirname "$0")/../configs/wm/mako/config" ~/.config/mako/
    [ ! -f ~/.config/swww/set_wallpaper.sh ] && { cp "$(dirname "$0")/../configs/wm/swww/set_wallpaper.sh" ~/.config/swww/; chmod +x ~/.config/swww/set_wallpaper.sh; }
  fi

  mkdir -p ~/.config/hypr/wallpapers
  [ ! -f ~/.config/hypr/wallpapers/default.jpg ] && cp -r "$(dirname "$0")/../wallpapers/"* ~/.config/hypr/wallpapers/

  # Deploy theme
  mkdir -p ~/.config/themes
  [ ! -d ~/.config/themes/professional ] && cp -r "$(dirname "$0")/../themes/professional/"* ~/.config/themes/

  ok "✅ WM configs deployed"
}

# Configure services
configure_services() {
  log "🔧 Configuring services..."
  sudo systemctl enable --now NetworkManager
  systemctl --user enable --now pipewire pipewire-pulse wireplumber
  ok "✅ Services configured"
}

# Finalize
finalize_setup() {
  log "🎨 Finalizing..."
  rm -rf /tmp/paru 2>/dev/null || true
  mkdir -p ~/.local/share/applications
  cat > ~/.local/share/applications/hyprland.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland Compositor
Exec=Hyprland
Type=Application
EOF
  ok "✅ Setup finalized"
}

# Summary
show_hypr_summary() {
  echo
  echo "🎉 Hyprland Minimal Setup Complete!"
  echo "📦 Installed: Hyprland, Waybar, Wofi, PipeWire, NetworkManager"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "    + Optional: Mako, Swww"
  fi
  echo "🚀 Run scripts/dotfiles.sh for terminals/dev tools."
  echo "🔧 Configs: ~/.config/{hypr,waybar,wofi,mako,swww}"
  echo
}

main() {
  echo "🐧 Hyprland Setup - Arch Linux Optimized"
  echo
  check_requirements
  install_base_deps
  setup_aur_helper
  install_hyprland_minimal
  deploy_wm_configs
  configure_services
  finalize_setup
  show_hypr_summary
}

main "$@"
