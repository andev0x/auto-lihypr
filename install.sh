#!/usr/bin/env bash
set -e

# ==================================================
# 🐧 Auto install Hyprland for Arch Linux
# Optimized for Arch Linux with Ubuntu/Debian fallback
# ==================================================

# Colors and logging
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok() { echo -e "\033[1;32m[DONE]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" && exit 1; }

# Detect distribution
. /etc/os-release 2>/dev/null || true
IS_ARCH=0
if [ "${ID:-}" = "arch" ] || [[ "${ID_LIKE:-}" == *arch* ]]; then
  IS_ARCH=1
fi

# ==================================================
# 🐧 Arch Linux Detection and Requirements
# ==================================================
if [ "$IS_ARCH" -eq 1 ]; then
  log "🐧 Detected Arch Linux - Primary target system"
  log "📦 This script is optimized for Arch Linux"
else
  warn "⚠️  Non-Arch Linux detected: ${ID:-unknown}"
  warn "⚠️  This script is optimized for Arch Linux. Some features may not work optimally."
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    err "Installation cancelled. Please use Arch Linux for best experience."
  fi
fi

# ==================================================
# 🔧 System Requirements Check
# ==================================================
check_requirements() {
  log "🔍 Checking system requirements..."
  
  # Check if running as root
  if [ "$EUID" -eq 0 ]; then
    err "❌ Do not run this script as root. Use a regular user with sudo privileges."
  fi
  
  # Check sudo access
  if ! sudo -n true 2>/dev/null; then
    err "❌ This script requires sudo privileges. Please configure sudo access."
  fi
  
  # Check available memory
  local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
  if [ "$mem_gb" -lt 2 ]; then
    warn "⚠️  Low memory detected: ${mem_gb}GB (recommended: 4GB+)"
  fi
  
  # Check CPU cores
  local cores=$(nproc)
  if [ "$cores" -lt 2 ]; then
    warn "⚠️  Low CPU cores detected: ${cores} (recommended: 2+)"
  fi
  
  ok "✅ System requirements check completed"
}

# ==================================================
# 🔒 Package Manager Lock Management
# ==================================================
wait_pkg_locks() {
  if [ "$IS_ARCH" -eq 1 ]; then
    local waited=0
    while [ -f /var/lib/pacman/db.lck ]; do
      if [ $waited -ge 120 ]; then
        err "❌ Timed out waiting for pacman lock (120s)"
      fi
      log "⏳ Waiting for pacman lock to be released... (${waited}s)"
      sleep 2
      waited=$((waited+2))
    done
  else
    local waited=0
    while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
      if [ $waited -ge 300 ]; then
        err "❌ Timed out waiting for apt/dpkg locks (300s)"
      fi
      log "⏳ Waiting for other package managers to finish... (${waited}s)"
      sleep 2
      waited=$((waited+2))
    done
  fi
}

# ==================================================
# 📦 Arch Linux Package Installation
# ==================================================
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
    warn "⚠️ pacman install failed — retrying (${attempts}/${max_attempts})"
    sleep $((attempts * 5))
  done
  return 1
}

# ==================================================
# 🛠️ AUR Helper Detection and Installation
# ==================================================
setup_aur_helper() {
  log "🔍 Checking for AUR helper..."
  
  # Check for existing AUR helpers
  if command -v paru >/dev/null 2>&1; then
    log "✅ Found paru AUR helper"
    AUR_HELPER="paru"
    return 0
  elif command -v yay >/dev/null 2>&1; then
    log "✅ Found yay AUR helper"
    AUR_HELPER="yay"
    return 0
  elif command -v aurman >/dev/null 2>&1; then
    log "✅ Found aurman AUR helper"
    AUR_HELPER="aurman"
    return 0
  fi
  
  # No AUR helper found, offer to install paru
  warn "⚠️  No AUR helper found. AUR packages will need manual installation."
  read -p "Install paru AUR helper? (recommended) [Y/n]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    log "📦 Installing paru AUR helper..."
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
    AUR_HELPER="paru"
    ok "✅ paru AUR helper installed"
  else
    AUR_HELPER=""
    warn "⚠️  AUR helper not installed. Some packages may need manual installation."
  fi
}

# ==================================================
# 📦 System Update and Base Dependencies
# ==================================================
install_base_deps() {
  if [ "$IS_ARCH" -eq 1 ]; then
    log "🐧 Updating Arch Linux system..."
    wait_pkg_locks
    sudo pacman -Syu --noconfirm
    ok "✅ System updated"
    
    log "📦 Installing base development and Wayland dependencies..."
    pacman_install git curl wget base-devel meson ninja cmake pkgconf \
      wayland-protocols vulkan-icd-loader libxkbcommon libseat libinput \
      libx11 xorg-xwayland xdg-desktop-portal-wlr
    ok "✅ Base dependencies installed"
  else
    log "📦 Updating system and installing base dependencies (Ubuntu/Debian)..."
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y \
      git curl wget build-essential meson ninja-build pkg-config \
      libwayland-dev libxkbcommon-dev libpixman-1-dev libseat-dev \
      libdrm-dev libinput-dev libxcb1-dev libxcb-composite0-dev \
      libxcb-xfixes0-dev libxcb-render0-dev libxcb-present-dev \
      libxcb-icccm4-dev libxcb-res0-dev libxcb-ewmh-dev libxcb-xinput-dev \
      libxcb-image0-dev libxcb-util-dev libxcb-cursor-dev \
      wayland-protocols libvulkan-dev libvulkan-volk-dev \
      libgbm-dev libegl1-mesa-dev libgles2-mesa-dev libxcb-xinerama0-dev \
      xwayland xdg-desktop-portal-wlr libpam0g-dev cmake
    ok "✅ Base dependencies installed (Ubuntu/Debian)"
  fi
}

# ==================================================
# 🧩 Hyprland and Core Packages Installation
# ==================================================
install_hyprland() {
  if [ "$IS_ARCH" -eq 1 ]; then
    log "🧩 Installing Hyprland and core packages from official repositories..."
    
    # Core Hyprland packages
    pacman_install hyprland waybar wofi mako kitty ghostty \
      grim slurp wl-clipboard wf-recorder brightnessctl playerctl \
      pavucontrol networkmanager pipewire pipewire-pulse wireplumber
    
    # Check for AUR-only packages
    if [ -n "$AUR_HELPER" ]; then
      log "📦 Installing AUR packages..."
      case $AUR_HELPER in
        paru|yay)
          $AUR_HELPER -S --noconfirm swww ttf-jetbrains-mono-nerd hyprlock
          ;;
        aurman)
          aurman -S --noconfirm swww ttf-jetbrains-mono-nerd hyprlock
          ;;
      esac
      ok "✅ AUR packages installed"
    else
      warn "⚠️  AUR packages not installed (no AUR helper):"
      warn "   - swww (wallpaper transitions)"
      warn "   - ttf-jetbrains-mono-nerd (terminal fonts)"
      warn "   - hyprlock (screen locker)"
      warn "   Install manually or set up an AUR helper"
    fi
    
    ok "✅ Hyprland and core packages installed"
  else
    log "🧩 Installing Hyprland and core packages (Ubuntu/Debian)..."
    sudo apt install -y \
      waybar kitty wofi grim slurp wl-clipboard wf-recorder \
      brightnessctl playerctl pavucontrol network-manager \
      pipewire wireplumber mako-notifier
    
    # Build Hyprland from source for Ubuntu/Debian
    log "🔨 Building Hyprland from source..."
    cd /tmp
    git clone --recursive https://github.com/hyprwm/Hyprland.git hyprland-build
    cd hyprland-build
    make all -j$(nproc)
    sudo make install
    cd ~
    rm -rf /tmp/hyprland-build
    ok "✅ Hyprland built and installed from source"
  fi
}

# ==================================================
# 📁 Configuration Deployment
# ==================================================
deploy_configs() {
  log "📁 Deploying configuration files..."
  
  # Create backup of existing configs
  if [ -d ~/.config ]; then
    local backup_dir="$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"
    log "💾 Backing up existing configs to $backup_dir"
    cp -r ~/.config "$backup_dir"
    ok "✅ Configs backed up"
  fi
  
  # Create config directories
  mkdir -p ~/.config/{hypr,waybar,mako,swww,wofi,kitty,ghostty,zsh,tmux,nvim}
  
  # Deploy Hyprland configs
  log "🔧 Deploying Hyprland configuration..."
  cp -r "$(dirname "$0")/configs/hypr/"* ~/.config/hypr/
  
  # Deploy Waybar config
  log "📊 Deploying Waybar configuration..."
  cp -r "$(dirname "$0")/configs/waybar/"* ~/.config/waybar/
  
  # Deploy Mako config
  log "🔔 Deploying Mako configuration..."
  cp -r "$(dirname "$0")/configs/mako/"* ~/.config/mako/
  
  # Deploy terminal configs
  log "🖥️ Deploying terminal configurations..."
  cp -r "$(dirname "$0")/configs/kitty/"* ~/.config/kitty/
  cp -r "$(dirname "$0")/configs/ghostty/"* ~/.config/ghostty/
  
  # Deploy shell configs
  log "🐚 Deploying shell configurations..."
  cp -r "$(dirname "$0")/configs/zsh/"* ~/.config/zsh/
  cp "$(dirname "$0")/configs/starship.toml" ~/.config/
  
  # Deploy Neovim config
  log "📝 Deploying Neovim configuration..."
  cp -r "$(dirname "$0")/configs/nvim/"* ~/.config/nvim/
  
  # Deploy wallpaper script
  log "🖼️ Deploying wallpaper management..."
  cp -r "$(dirname "$0")/configs/swww/"* ~/.config/swww/
  chmod +x ~/.config/swww/set_wallpaper.sh
  
  # Deploy wallpapers
  mkdir -p ~/.config/hypr/wallpapers
  cp -r "$(dirname "$0")/wallpapers/"* ~/.config/hypr/wallpapers/
  
  # Deploy Wofi config
  log "🔍 Deploying Wofi configuration..."
  cp -r "$(dirname "$0")/configs/wofi/"* ~/.config/wofi/
  
  ok "✅ All configurations deployed"
}

# ==================================================
# 🔧 System Service Configuration
# ==================================================
configure_services() {
  log "🔧 Configuring system services..."
  
  if [ "$IS_ARCH" -eq 1 ]; then
    # Enable NetworkManager
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
    
    # Enable PipeWire
    systemctl --user enable pipewire pipewire-pulse wireplumber
    
    ok "✅ System services configured"
  else
    # Ubuntu/Debian service configuration
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
    systemctl --user enable pipewire pipewire-pulse wireplumber
    ok "✅ System services configured (Ubuntu/Debian)"
  fi
}

# ==================================================
# 🎨 Final Setup and Cleanup
# ==================================================
finalize_setup() {
  log "🎨 Finalizing setup..."
  
  # Clean up temporary files
  rm -rf /tmp/hyprland-build /tmp/cmake-3.* /tmp/paru 2>/dev/null || true
  
  # Set proper permissions
  chmod +x ~/.config/swww/set_wallpaper.sh
  
  # Create desktop entry for Hyprland
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

# ==================================================
# 📋 Installation Summary
# ==================================================
show_summary() {
  echo
  echo "🎉 ==============================================="
  echo "🎉 Hyprland Installation Complete!"
  echo "🎉 ==============================================="
  echo
  echo "📦 Installed packages:"
  echo "   ✅ Hyprland (Wayland compositor)"
  echo "   ✅ Waybar (status bar)"
  echo "   ✅ Wofi (application launcher)"
  echo "   ✅ Mako (notification daemon)"
  echo "   ✅ Kitty & Ghostty (terminals)"
  echo "   ✅ PipeWire (audio system)"
  echo "   ✅ NetworkManager (network management)"
  
  if [ "$IS_ARCH" -eq 1 ] && [ -n "$AUR_HELPER" ]; then
    echo "   ✅ swww (wallpaper transitions)"
    echo "   ✅ JetBrainsMono Nerd Font"
    echo "   ✅ hyprlock (screen locker)"
  fi
  
  echo
  echo "🚀 To start Hyprland:"
  echo "   1. Log out of your current session"
  echo "   2. Select 'Hyprland' from your display manager"
  echo "   3. Or run: dbus-run-session Hyprland"
  echo
  echo "🔧 Configuration files are located in:"
  echo "   ~/.config/hypr/     (Hyprland config)"
  echo "   ~/.config/waybar/   (Status bar)"
  echo "   ~/.config/kitty/    (Kitty terminal)"
  echo "   ~/.config/ghostty/  (Ghostty terminal)"
  echo "   ~/.config/nvim/     (Neovim editor)"
  echo
  echo "🖼️ Wallpapers are in:"
  echo "   ~/.config/hypr/wallpapers/"
  echo
  echo "📚 For customization, see the README.md file"
  echo
}

# ==================================================
# 🚀 Main Installation Flow
# ==================================================
main() {
  echo "🐧 ==============================================="
  echo "🐧 Auto-Lihypr - Arch Linux Optimized"
  echo "🐧 Hyprland Installation Script"
  echo "🐧 ==============================================="
  echo
  
  check_requirements
  install_base_deps
  
  if [ "$IS_ARCH" -eq 1 ]; then
    setup_aur_helper
  fi
  
  install_hyprland
  deploy_configs
  configure_services
  finalize_setup
  show_summary
}

# Run main function
main "$@"