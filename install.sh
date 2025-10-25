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

# Helper: wait while apt/dpkg locks are held
apt_wait_for_locks() {
    local wait_seconds=0
    while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
        if [ $wait_seconds -ge 300 ]; then
            err "Timed out waiting for apt/dpkg locks (>$wait_seconds s)."
            return 1
        fi
        log "⏳ Waiting for other package managers to finish... ($wait_seconds s)"
        sleep 2
        wait_seconds=$((wait_seconds + 2))
    done
    return 0
}

# Helper: attempt to recover interrupted dpkg state
apt_recover() {
    # If dpkg was interrupted, try to fix it
    if sudo dpkg --audit >/dev/null 2>&1; then
        # no broken packages found
        return 0
    fi

    log "⚠️ Detected dpkg inconsistency — attempting automatic recovery..."
    sudo apt-get -o DPkg::Options::=--force-confdef -o DPkg::Options::=--force-confold update -y || true
    sudo dpkg --configure -a || true
    sudo apt-get install -f -y || true

    # Wait for locks to clear after recovery
    apt_wait_for_locks || return 1

    # One more update to ensure package lists are consistent
    sudo apt-get update || true
    return 0
}

# Ensure any interrupted dpkg state is healed before proceeding
apt_wait_for_locks || exit 1
apt_recover || { err "Failed to auto-recover dpkg state. Please run: sudo dpkg --configure -a && sudo apt-get install -f -y"; exit 1; }

# Perform update/upgrade (non-interactive)
log "🔄 Updating package lists and upgrading installed packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1 || true
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >/dev/null 2>&1; then
    log "⚠️ Full upgrade failed — attempting safe upgrade without new packages"
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade --without-new-pkgs -y || true
fi

# --------------------------------------------------
# 1. Install essential packages
# --------------------------------------------------
log "🔧 Installing core packages..."

# Try to recover dpkg just before installing packages
apt_wait_for_locks || exit 1
apt_recover || { err "Failed to auto-recover dpkg state prior to install. Please run: sudo dpkg --configure -a && sudo apt-get install -f -y"; exit 1; }

CORE_PKGS=(
    git curl wget unzip jq fzf ripgrep
    zsh zoxide neovim python3-pip
    golang rustc cargo
    waybar wofi mako hyprland swww
    fonts-jetbrains-mono
    build-essential meson cmake pkg-config
)

# Install packages with retries
attempts=0
max_attempts=3
until [ $attempts -ge $max_attempts ]
do
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${CORE_PKGS[@]}" && break
    attempts=$((attempts+1))
    log "⚠️ apt-get install failed — retrying ($attempts/$max_attempts) after recovery..."
    apt_recover || true
    sleep $((attempts * 5))
done

if [ $attempts -ge $max_attempts ]; then
    err "❌ Failed to install core packages after $max_attempts attempts. Please check $LOG_FILE and run: sudo dpkg --configure -a && sudo apt-get install -f -y"
    exit 1
fi

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

