#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# anvndev Hyprland Installer (Ubuntu 24.04 LTS)
# -----------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# ---------------------------
# Editable defaults
# ---------------------------
TERMINAL_CMD="alacritty"
LAUNCHER_CMD="wofi --show drun"
CATPPUCCIN_FLAVOR="mocha"
ACCENT_COLOR="#1f6f4f"
ENABLE_SYSTEMD_USER_SERVICE=true
USER_TO_ADD_DOCKER_GROUP="$(whoami)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$HOME/hyprland_install.log"
BACKUP_DIR="$HOME/.config.backup.$(date +%Y%m%d%H%M%S)"
FONT_DIR="$HOME/.local/share/fonts"
RETRY_MAX=3

# ---------------------------
# Logging & traps
# ---------------------------
exec 1> >(tee -a "$LOGFILE") 2>&1
echo "==== anvndev Hyprland installer started: $(date) ===="

cleanup() {
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "❌ Installer failed (exit code $rc). See $LOGFILE for details."
  else
    echo "✅ Installer finished successfully."
  fi
}
trap cleanup EXIT

err_trap() {
  echo "❌ Error in script at line $1."
  exit 1
}
trap 'err_trap $LINENO' ERR

# ---------------------------
# Helpers
# ---------------------------
log() { printf "\033[1;32m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; exit 1; }

apt_wait_for_locks() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
        sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
        sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
        sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    echo "⏳ Waiting for other package managers to finish..."
    sleep 1
  done
}

apt_update_retry() {
  local i=1
  while [ $i -le $RETRY_MAX ]; do
    apt_wait_for_locks
    if sudo apt-get update -y; then
      return 0
    fi
    warn "apt-get update attempt $i failed. Retrying..."
    sleep $((i * 2))
    i=$((i + 1))
  done
  die "apt-get update failed after $RETRY_MAX attempts."
}

apt_install_retry() {
  local packages=("$@")
  local attempt=1
  while [ $attempt -le $RETRY_MAX ]; do
    apt_wait_for_locks
    log "Installing packages (attempt $attempt/$RETRY_MAX): ${packages[*]}"
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
      return 0
    fi
    warn "apt install failed (attempt $attempt). Retrying..."
    apt_update_retry
    attempt=$((attempt + 1))
    sleep $((attempt * 2))
  done
  die "Failed to install packages after $RETRY_MAX attempts: ${packages[*]}"
}

user_systemctl_available() {
  systemctl --user >/dev/null 2>&1
}

# ---------------------------
# Prechecks
# ---------------------------
if [ "$EUID" -eq 0 ]; then
  die "Do not run this script as root. Run as normal user with sudo privileges."
fi
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
  die "This installer is for Ubuntu only."
fi

# ---------------------------
# 1) Update apt
# ---------------------------
log "Updating apt lists..."
apt_update_retry

# ---------------------------
# 2) Install basic packages
# ---------------------------
log "Installing core packages..."
CORE=(git curl wget unzip jq fzf ripgrep fd-find bat eza zsh)
LANG=(python3 python3-pip golang-go)
apt_install_retry "${CORE[@]}"
apt_install_retry "${LANG[@]}"

# ---------------------------
# 3) Fonts (JetBrainsMono Nerd)
# ---------------------------
log "Installing JetBrainsMono Nerd Font..."
mkdir -p "$FONT_DIR"
tmpd=$(mktemp -d)
pushd "$tmpd" >/dev/null
wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
unzip -o JetBrainsMono.zip -d jetbrains
mv jetbrains/*.ttf "$FONT_DIR/"
popd >/dev/null
rm -rf "$tmpd"
fc-cache -fv

# ---------------------------
# 4) Starship + zoxide
# ---------------------------
log "Installing Starship & zoxide..."
if ! command -v starship >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi
if ! command -v zoxide >/dev/null 2>&1; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# ---------------------------
# 5) Copy configs
# ---------------------------
log "Backing up and copying configs..."
mkdir -p "$BACKUP_DIR"
for d in nvim tmux hypr waybar wofi mako swww alacritty kitty ghostty; do
  [ -e "$HOME/.config/$d" ] && cp -r "$HOME/.config/$d" "$BACKUP_DIR/" || true
done

if [ -d "$REPO_ROOT/configs" ]; then
  cp -rv "$REPO_ROOT/configs/"* "$HOME/.config/"
fi

if [ -f "$REPO_ROOT/configs/starship.toml" ]; then
  cp -v "$REPO_ROOT/configs/starship.toml" "$HOME/.config/starship.toml"
fi

# ---------------------------
# 6) Zsh setup
# ---------------------------
if command -v zsh >/dev/null 2>&1; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    chsh -s "$(command -v zsh)" || warn "Failed to set default shell"
  fi
fi

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
grep -q 'starship init zsh' "$ZSHRC" || echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
grep -q 'zoxide init zsh' "$ZSHRC" || echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"

# ---------------------------
# Done
# ---------------------------
echo ""
echo "🎉 Installation completed successfully!"
echo "➡️  Configs: ~/.config/"
echo "➡️  Backup:  $BACKUP_DIR"
echo "➡️  Log:     $LOGFILE"
