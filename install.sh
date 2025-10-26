#!/usr/bin/env bash
# ==================================================
# 🌿 auto-lihypr-minimal — Build Hyprland on Ubuntu Server 24.04
# Author: anvndev
# ==================================================

set -euo pipefail

LOG_FILE="$HOME/auto-lihypr_install.log"
REPO_DIR="$(pwd)"
CONFIG_DIR="$HOME/.config"
FONT_DIR="$HOME/.local/share/fonts"
WALLPAPER_DIR="$REPO_DIR/wallpapers"
BUILD_DIR="/tmp/hyprland-build"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log() { echo -e "${YELLOW}$1${RESET}"; }
ok()  { echo -e "${GREEN}$1${RESET}"; }
err() { echo -e "${RED}$1${RESET}" >&2; }

# ==================================================
# 🧩 BASIC SYSTEM SETUP
# ==================================================
log "🚀 Starting auto-lihypr-minimal installation..."

sudo apt update
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
    swaybg waybar wofi mako swww grim slurp jq

# ==================================================
# 🧱 BUILD HYPRLAND FROM SOURCE
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
# ✨ SHELL + PROMPT
# ==================================================
log "🧠 Configuring Zsh + Starship + Zoxide..."

if ! command -v starship &>/dev/null; then
    curl -fsSL https://starship.rs/install.sh | bash -s -- -y
fi

if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
fi

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

grep -qxF 'eval "$(starship init zsh)"' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
grep -qxF 'eval "$(zoxide init zsh)"' "$ZSHRC" || echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
grep -qxF 'source ~/.config/zsh/aliases.zsh' "$ZSHRC" || echo 'source ~/.config/zsh/aliases.zsh' >> "$ZSHRC"

# ==================================================
# 🧩 APPLY CONFIGS
# ==================================================
log "📂 Applying configuration files..."
mkdir -p "$CONFIG_DIR"
cp -r "$REPO_DIR/configs/"* "$CONFIG_DIR/" || true

# ==================================================
# 🖼️ WALLPAPER
# ==================================================
log "🖼️ Setting up wallpapers..."
mkdir -p "$HOME/Pictures/wallpapers"
cp -r "$WALLPAPER_DIR"/* "$HOME/Pictures/wallpapers/" || true

# ==================================================
# 🎨 FONT CACHE
# ==================================================
log "🔤 Updating font cache..."
fc-cache -fv >/dev/null 2>&1 || true

# ==================================================
# ⚙️ CREATE START SCRIPT
# ==================================================
log "⚙️ Creating Hyprland start helper..."

cat << 'EOF' | sudo tee /usr/local/bin/start-hypr > /dev/null
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

# ==================================================
# ✅ DONE
# ==================================================
ok "✅ Installation complete!"
ok "Run 'start-hypr' from TTY to launch Hyprland."
ok "📜 Log file: $LOG_FILE"
