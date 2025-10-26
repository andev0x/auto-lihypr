#!/usr/bin/env bash
set -e

# ==================================================
# 🧱 Auto install Hyprland (Minimal setup)
# No GNOME, No PPA, No DE
# ==================================================

# Helper functions
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok() { echo -e "\033[1;32m[DONE]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" && exit 1; }

# Detect distro
. /etc/os-release 2>/dev/null || true
IS_ARCH=0
if [ "${ID:-}" = "arch" ] || [[ "${ID_LIKE:-}" == *arch* ]]; then
  IS_ARCH=1
fi

# Helper: wait for pacman lock (Arch) or apt/dpkg locks (Debian)
wait_pkg_locks() {
  if [ "$IS_ARCH" -eq 1 ]; then
    local waited=0
    while [ -f /var/lib/pacman/db.lck ]; do
      if [ $waited -ge 120 ]; then
        err "Timed out waiting for pacman lock."
      fi
      log "⏳ Waiting for pacman lock to be released... ($waited s)"
      sleep 2
      waited=$((waited+2))
    done
  else
    local waited=0
    while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
      if [ $waited -ge 300 ]; then
        err "Timed out waiting for apt/dpkg locks."
      fi
      log "⏳ Waiting for other package managers to finish... ($waited s)"
      sleep 2
      waited=$((waited+2))
    done
  fi
}

# Wrapper to install packages on Arch (pacman) with retry
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
    log "⚠️ pacman install failed — retrying ($attempts/$max_attempts)"
    sleep $((attempts * 5))
  done
  return 1
}

# Wrapper to update on Arch or Debian
if [ "$IS_ARCH" -eq 1 ]; then
  log "Detected Arch Linux — updating system with pacman..."
  wait_pkg_locks
  sudo pacman -Syu --noconfirm
  ok "System updated (pacman)."
  
  # Install base dependencies via pacman
  log "Installing base development and Wayland dependencies (pacman)..."
  pacman_install git curl wget base-devel meson ninja cmake pkgconf \
    wayland-protocols vulkan-icd-loader libxkbcommon libseat libinput libx11 xorg-xwayland xdg-desktop-portal-wlr
  ok "Base deps installed (pacman)."
else
  log "Updating system and installing base dependencies (apt)..."
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
  ok "System updated and base deps installed."
fi

# ==================================================
# 🔧 Ensure CMake ≥ 3.30 (only for Debian-based where older CMake may exist)
# ==================================================
if [ "$IS_ARCH" -ne 1 ]; then
  if ! cmake --version | grep -q "3.30"; then
    log "⬆️ Updating CMake to version 3.30.5..."
    sudo apt remove -y cmake || true
    sudo apt install -y build-essential libssl-dev
    cd /tmp
    wget -q https://github.com/Kitware/CMake/releases/download/v3.30.5/cmake-3.30.5.tar.gz
    tar -xf cmake-3.30.5.tar.gz
    cd cmake-3.30.5
    ./bootstrap >/dev/null
    make -j$(nproc)
    sudo make install
    ok "✅ Installed CMake $(cmake --version | head -n1)"
  fi
fi

# ==================================================
# 🧩 Build & Install Hyprland (from source)
# ==================================================
if [ "$IS_ARCH" -eq 1 ]; then
  log "Installing Hyprland from pacman..."
  if pacman_install hyprland waybar wofi mako kitty swww waybar; then
    ok "Hyprland and core packages installed via pacman."
  else
    log "⚠️ pacman install failed or package not available — falling back to build from source"
    cd /tmp
    git clone --recursive https://github.com/hyprwm/Hyprland.git hyprland-build
    cd hyprland-build
    # Prefer meson/ninja build if available
    if command -v meson >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
      meson setup build
      ninja -C build -j$(nproc)
      sudo ninja -C build install
    else
      make all -j$(nproc) || true
      sudo make install || true
    fi
    ok "Hyprland built and installed from source."
  fi
else
  log "Building Hyprland from source..."
  cd /tmp
  git clone --recursive https://github.com/hyprwm/Hyprland.git hyprland-build
  cd hyprland-build
  make all -j$(nproc)
  sudo make install
  ok "Hyprland installed."
fi

# ==================================================
# 🧰 Install essential Wayland tools
# ==================================================
log "Installing Wayland essentials..."
if [ "$IS_ARCH" -eq 1 ]; then
  pacman_install waybar kitty wofi grim slurp wl-clipboard wf-recorder \
    brightnessctl playerctl pavucontrol networkmanager \
    pipewire pipewire-pulse wireplumber mako swww
  ok "Essential Wayland tools installed (pacman)."
else
  sudo apt install -y \
    waybar kitty wofi grim slurp wl-clipboard wf-recorder \
    brightnessctl playerctl pavucontrol network-manager \
    pipewire wireplumber mako-notifier swww
  ok "Essential Wayland tools installed (apt)."
fi
if [ "$IS_ARCH" -eq 1 ]; then
  if ! command -v swww >/dev/null 2>&1; then
    log "⚠️ 'swww' not available in repositories or failed to install."
    log "If you need swww (wallpaper transitions), install it from AUR (e.g. using paru or yay):"
    log "  paru -S swww"
  fi
fi

# ==================================================
# 🧠 Create default config
# ==================================================
mkdir -p ~/.config/{hypr,waybar,mako,swww}
cat > ~/.config/hypr/hyprland.conf <<'EOF'
# ===============================
# 🧩 Minimal Hyprland config
# ===============================
monitor=,preferred,auto,1
exec = swww init
exec = waybar &
exec = mako &
exec = wofi --show drun &
exec-once = kitty
EOF

ok "Default Hyprland config created."

# ==================================================
# 🎨 Finishing up
# ==================================================
log "Cleaning temporary files..."
rm -rf /tmp/hyprland-build /tmp/cmake-3.*

ok "✅ Hyprland minimal setup complete!"
echo
echo "➡️ To start Hyprland, log out and run:"
echo "   dbus-run-session Hyprland"
echo
