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
sudo apt update -y && sudo apt upgrade -y

# --------------------------------------------------
# 1. Install essential packages
# --------------------------------------------------
log "🔧 Installing core packages..."
sudo apt install -y \
    git curl wget unzip jq fzf ripgrep \
    zsh zoxide neovim python3-pip \
    golang rustc cargo \
    waybar wofi mako hyprland swww \
    fonts-jetbrains-mono \
    build-essential meson cmake pkg-config || {
    err "❌ Failed to install packages."
    exit 1
}

# --------------------------------------------------
# 2. Install Starship
# --------------------------------------------------
if ! command -v starship &>/dev/null; then
    log "✨ Installing Starship prompt..."
    curl -fsSL https://starship.rs/install.sh | bash -s -- -y
fi

# --------------------------------------------------
# 3. Install GNU Stow
# --------------------------------------------------
if ! command -v stow &>/dev/null; then
    log "📦 Installing GNU Stow..."
    sudo apt install -y stow
fi

# --------------------------------------------------
# 4. Configure Zsh + Starship + Zoxide
# --------------------------------------------------
log "🧠 Configuring Zsh shell..."
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
fi

touch "$ZSHRC"
grep -qxF 'eval "$(starship init zsh)"' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
grep -qxF 'eval "$(zoxide init zsh)"' "$ZSHRC" || echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
grep -qxF 'source ~/.config/zsh/aliases.zsh' "$ZSHRC" || echo 'source ~/.config/zsh/aliases.zsh' >> "$ZSHRC"

# ==================================================
# 🧱 APPLY CONFIGS USING STOW
# ==================================================
log "🧩 Applying configuration files with stow..."

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
log "🖼️ Setting default wallpaper..."
mkdir -p "$HOME/Pictures/wallpapers"
cp -r "$WALLPAPER_DIR"/* "$HOME/Pictures/wallpapers/"
if command -v swww &>/dev/null; then
    swww init &>/dev/null || true
    swww img "$HOME/Pictures/wallpapers/default.jpg" --transition-type any --transition-fps 60 --transition-duration 2 || true
fi

# ==================================================
# 🎨 FONT CACHE
# ==================================================
log "🔤 Updating font cache..."
fc-cache -fv >/dev/null 2>&1 || true

# ==================================================
# ✅ DONE
# ==================================================
ok "✅ Installation complete!"
ok "💻 Log out and choose Hyprland session to start."
ok "🧩 Configs installed under ~/.config"
ok "📜 Log file: $LOG_FILE"

