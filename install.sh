#!/usr/bin/env bash
# ==================================================
# 🌿 auto-lihypr-minimal — Build Hyprland on Ubuntu Server 24.04
# No PPA, no desktop environment.
# Author: anvndev
# ==================================================

set -euo pipefail

LOG_FILE="$HOME/auto-lihypr_install.log"
REPO_DIR="$(pwd)"
CONFIG_DIR="$HOME/.config"
WALLPAPER_DIR="$REPO_DIR/wallpapers"
BUILD_DIR="/tmp/hyprland-build"

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; RESET="\033[0m"
log() { echo -e "${YELLOW}$1${RESET}"; }
ok()  { echo -e "${GREEN}$1${RESET}"; }
err() { echo -e "${RED}$1${RESET}" >&2; }

log "🚀 Starting auto-lihypr-minimal installation..."

# ==================================================
# 🔧 Enable repositories
# ==================================================
log "🧩 Enabling Ubuntu repositories..."
sudo sed -i 's/^# deb/deb/g' /etc/apt/sources.list
sudo apt update -y

# ==================================================
# 🧩 Install essentials
# ==================================================
log "📦 Installing base packages..."

sudo apt install -y --no-install-recommends \
  git curl wget unzip jq fzf ripgrep neovim \
  zsh zoxide fonts-jetbrains-mono \
  python3 python3-pip build-essential cmake meson ninja-build pkg-config \
  libwayland-dev wayland-protocols libxkbcommon-dev libudev-dev libseat-dev \
  libdrm-dev libgbm-dev libinput-dev libvulkan-dev vulkan-tools \
  libxcb1-dev libxcb-dri3-dev libxcb-present-dev libxcb-xfixes0-dev \
  libxcb-render0-dev libxcb-shape0-dev libxcb-xkb-dev xwayland \
  libxkbcommon-x11-dev libegl1-mesa-dev libgles2-mesa-dev libglu1-mesa-dev \
  pipewire wireplumber libspa-0.2-bluetooth libpam0g-dev \
  libdisplay-info-dev libliftoff-dev libinput-bin \
  swaybg grim slurp jq

# ==================================================
# 🧱 Build Hyprland
# ==================================================
log "🔨 Building Hyprland from source..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
if [ ! -d "Hyprland" ]; then
  git clone --recursive https://github.com/hyprwm/Hyprland.git
fi
cd Hyprland
make all -j$(nproc)
sudo make install

# ==================================================
# 🌫️ Build swww (if not found)
# ==================================================
if ! command -v swww &>/dev/null; then
  log "🧩 Building swww (wallpaper daemon)..."
  cd "$BUILD_DIR"
  git clone https://github.com/LGFae/swww.git
  cd swww
  cargo build --release
  sudo install -Dm755 target/release/swww /usr/local/bin/swww
fi

# ==================================================
# 🔔 Build mako (if not found)
# ==================================================
if ! command -v mako &>/dev/null; then
  log "🔔 Building mako (notification daemon)..."
  cd "$BUILD_DIR"
  git clone https://github.com/emersion/mako.git
  cd mako
  meson setup build
  ninja -C build
  sudo ninja -C build install
fi

# ==================================================
# ✨ Shell setup
# ==================================================
log "🧠 Configuring Zsh..."
if ! command -v starship &>/dev/null; then
  curl -fsSL https://starship.rs/install.sh | bash -s -- -y
fi

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
grep -qxF 'eval "$(starship init zsh)"' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
grep -qxF 'eval "$(zoxide init zsh)"' "$ZSHRC" || echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
grep -qxF 'source ~/.config/zsh/aliases.zsh' "$ZSHRC" || echo 'source ~/.config/zsh/aliases.zsh' >> "$ZSHRC"

# ==================================================
# ⚙️ Apply configs
# ==================================================
log "📂 Copying configs..."
mkdir -p "$CONFIG_DIR"
cp -r "$REPO_DIR/configs/"* "$CONFIG_DIR/" || true

# ==================================================
# 🖼️ Wallpapers
# ==================================================
mkdir -p "$HOME/Pictures/wallpapers"
cp -r "$WALLPAPER_DIR"/* "$HOME/Pictures/wallpapers/" || true

# ==================================================
# 🧭 Create launcher
# ==================================================
log "⚙️ Creating start-hypr launcher..."
sudo tee /usr/local/bin/start-hypr >/dev/null <<'EOF'
#!/usr/bin/env bash
export XDG_SESSION_TYPE=wayland
export WLR_NO_HARDWARE_CURSORS=1
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export XDG_CURRENT_DESKTOP=Hyprland
exec Hyprland
EOF
sudo chmod +x /usr/local/bin/start-hypr

ok "✅ Installation complete!"
ok "Run 'start-hypr' from TTY to launch Hyprland."
ok "📜 Log file: $LOG_FILE"
