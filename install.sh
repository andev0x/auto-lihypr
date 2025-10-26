#!/usr/bin/env bash
set -e

# ==================================================
# 🧱 Auto install Hyprland (Minimal setup)
# For Ubuntu Server Minimal (24.04+)
# No GNOME, No PPA, No DE
# ==================================================

# Helper functions
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok() { echo -e "\033[1;32m[DONE]\033[0m $1"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $1" && exit 1; }

# ==================================================
# 🚀 Update system and install base deps
# ==================================================
log "Updating system and installing base dependencies..."
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

# ==================================================
# 🔧 Ensure CMake ≥ 3.30
# ==================================================
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

# ==================================================
# 🧩 Build & Install Hyprland (from source)
# ==================================================
log "Building Hyprland from source..."
cd /tmp
git clone --recursive https://github.com/hyprwm/Hyprland.git hyprland-build
cd hyprland-build
make all -j$(nproc)
sudo make install
ok "Hyprland installed."

# ==================================================
# 🧰 Install essential Wayland tools
# ==================================================
log "Installing Wayland essentials..."
sudo apt install -y \
  waybar kitty wofi grim slurp wl-clipboard wf-recorder \
  brightnessctl playerctl pavucontrol network-manager \
  pipewire wireplumber mako-notifier swww

ok "Essential Wayland tools installed."

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
