#!/usr/bin/env bash
# ==================================================
# 🌿 auto-lihypr — Full Hyprland Environment Setup
# For Ubuntu Server 24.04 LTS
# Author: anvndev
# ==================================================

set -euo pipefail

REPO_DIR="$(pwd)"
LOG_FILE="$HOME/auto-lihypr_install.log"
CONFIG_DIR="$HOME/.config"
ZSHRC="$HOME/.zshrc"
FONT_DIR="$HOME/.local/share/fonts"
WALLPAPER_DIR="$REPO_DIR/wallpapers"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log() { echo -e "${YELLOW}$1${RESET}"; }
ok() { echo -e "${GREEN}$1${RESET}"; }
err() { echo -e "${RED}$1${RESET}" >&2; }

# ==================================================
# 🧩 PREPARE SYSTEM
# ==================================================
log "🚀 Starting auto-lihypr installation..."

apt_wait_for_locks() {
    while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
        log "⏳ Waiting for other apt/dpkg processes..."
        sleep 3
    done
}

apt_recover() {
    log "🩹 Running dpkg recovery (if needed)..."
    sudo dpkg --configure -a || true
    sudo apt-get install -f -y || true
}

# --------------------------------------------------
# 0. System Update
# --------------------------------------------------
apt_wait_for_locks
sudo apt-get update -y
sudo apt-get upgrade -y || true

# ==================================================
# 🧠 DETECT SERVER OR DESKTOP MODE
# ==================================================
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    IS_SERVER=true
    log "💻 Detected headless Ubuntu Server environment (no GUI)."
else
    IS_SERVER=false
    log "🖥️ Detected desktop environment with GUI support."
fi

# ==================================================
# 🪄 ADD HYPRLAND REPOSITORY (IF NEEDED)
# ==================================================
if ! grep -q "hyprland/ppa" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    log "🌿 Adding Hyprland PPA..."
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository ppa:hyprland/ppa -y
    sudo apt-get update -y
fi

# ==================================================
# 🔧 CORE PACKAGES
# ==================================================
CORE_PKGS=(
    git curl wget unzip jq fzf ripgrep
    zsh zoxide neovim python3-pip
    golang rustc cargo
    fonts-jetbrains-mono
    build-essential meson cmake pkg-config
)

# Include GUI stack only if not headless
if [ "$IS_SERVER" = false ]; then
    CORE_PKGS+=(waybar wofi mako hyprland swww)
else
    log "⚙️ Skipping GUI packages (headless mode)."
fi

# ==================================================
# 🧰 INSTALL CORE PACKAGES
# ==================================================
log "📦 Installing core packages..."
attempts=0
max_attempts=3

until [ $attempts -ge $max_attempts ]; do
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${CORE_PKGS[@]}"; then
        ok "✅ Core packages installed successfully."
        break
    fi
    attempts=$((attempts + 1))
    err "⚠️ apt-get install failed — retrying ($attempts/$max_attempts)..."
    apt_recover
    sleep $((attempts * 5))
done

if [ $attempts -ge $max_attempts ]; then
    err "❌ Failed to install core packages after $max_attempts attempts. Check $LOG_FILE."
    exit 1
fi

# ==================================================
# 💫 INSTALL STARSHIP PROMPT
# ==================================================
if ! command -v starship &>/dev/null; then
    log "✨ Installing Starship prompt..."
    curl -fsSL https://starship.rs/install.sh | bash -s -- -y
fi

# ==================================================
# 📦 INSTALL GNU STOW
# ==================================================
if ! command -v stow &>/dev/null; then
    log "📦 Installing GNU Stow..."
    sudo apt install -y stow
fi

# ==================================================
# 🧠 CONFIGURE ZSH + STARSHIP + ZOXIDE
# ==================================================
log "⚙️ Configuring Zsh..."
touch "$ZSHRC"
grep -qxF 'eval "$(starship init zsh)"' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
grep -qxF 'eval "$(zoxide init zsh)"' "$ZSHRC" || echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
grep -qxF 'source ~/.config/zsh/aliases.zsh' "$ZSHRC" || echo 'source ~/.config/zsh/aliases.zsh' >> "$ZSHRC"

if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
fi

# ==================================================
# 🧱 APPLY CONFIGS
# ==================================================
log "🧩 Linking configs using GNU Stow..."
mkdir -p "$CONFIG_DIR"
cd "$REPO_DIR/configs"

for folder in *; do
    if [ -d "$folder" ]; then
        log "📂 Linking $folder → ~/.config/$folder"
        stow -t "$CONFIG_DIR" "$folder" || true
    fi
done

# ==================================================
# 🖼️ WALLPAPER SETUP
# ==================================================
if [ "$IS_SERVER" = false ]; then
    log "🖼️ Setting wallpaper..."
    mkdir -p "$HOME/Pictures/wallpapers"
    cp -r "$WALLPAPER_DIR"/* "$HOME/Pictures/wallpapers/"
    if command -v swww &>/dev/null; then
        swww init &>/dev/null || true
        swww img "$HOME/Pictures/wallpapers/default.jpg" --transition-type any --transition-fps 60 --transition-duration 2 || true
    fi
fi

# ==================================================
# 🔤 FONT CACHE
# ==================================================
log "🔤 Updating font cache..."
fc-cache -fv >/dev/null 2>&1 || true

# ==================================================
# ✅ DONE
# ==================================================
ok "✅ Installation complete!"
ok "💻 Log out and choose Hyprland session to start (if GUI installed)."
ok "📜 Log file: $LOG_FILE"
