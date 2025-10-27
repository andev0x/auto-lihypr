#!/usr/bin/env bash
set -e

# ==================================================
# 🖥️ Dotfiles Setup for Arch Linux (Terminals + Dev Tools)
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

# Install terminals and dev tools
install_terminals_dev() {
  log "🖥️ Installing terminals and dev tools..."

  # Terminals variety + dev core
  pacman_install kitty alacritty ghostty tmux neovim zsh

  # AUR: zoxide + starship
  if [ -n "$AUR_HELPER" ]; then
    $AUR_HELPER -S --noconfirm zoxide-bin starship
  else
    warn "⚠️ Skip zoxide/starship (install manually: paru -S zoxide-bin starship)"
  fi

  # Optional: backend/DevOps/AI tools
  read -p "Install Docker, Python, Node.js for backend/DevOps/AI? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    pacman_install docker podman kubectl python python-pip nodejs npm
    if lspci | grep -i nvidia >/dev/null 2>&1; then
      log "🔍 Detected NVIDIA - Installing CUDA..."
      pacman_install cuda nvidia-utils
    fi
  fi

  ok "✅ Terminals and dev tools installed"
}

# Deploy dotfiles configs
deploy_dotfiles() {
  log "📁 Deploying dotfiles (skip if exists)..."
  # Ensure ~/.config permissions
  mkdir -p ~/.config
  chown $USER:$USER ~/.config
  chmod u+rwx ~/.config

  if [ -d ~/.config ]; then
    local backup_dir="$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"
    log "💾 Backup to $backup_dir"
    cp -r ~/.config "$backup_dir"
  fi

  mkdir -p ~/.config/{kitty,alacritty,ghostty,tmux,nvim,zsh}
  [ ! -f ~/.config/kitty/kitty.conf ] && cp "$(dirname "$0")/../configs/dotfiles/kitty/kitty.conf" ~/.config/kitty/
  [ ! -f ~/.config/alacritty/alacritty.toml ] && cp "$(dirname "$0")/../configs/dotfiles/alacritty/alacritty.toml" ~/.config/alacritty/
  [ ! -f ~/.config/ghostty/config ] && cp "$(dirname "$0")/../configs/dotfiles/ghostty/config" ~/.config/ghostty/
  [ ! -d ~/.config/tmux ] && cp -r "$(dirname "$0")/../configs/dotfiles/tmux/"* ~/.config/tmux/
  [ ! -d ~/.config/nvim ] && cp -r "$(dirname "$0")/../configs/dotfiles/nvim/"* ~/.config/nvim/
  [ ! -d ~/.config/zsh ] && cp -r "$(dirname "$0")/../configs/dotfiles/zsh/"* ~/.config/zsh/

  # Integrate zoxide + starship with zsh
  if [ -f ~/.config/zsh/aliases.zsh ]; then
    if ! grep -q "zoxide" ~/.config/zsh/aliases.zsh; then
      echo 'eval "$(zoxide init zsh)"' >> ~/.config/zsh/aliases.zsh
      echo "alias cd='z'" >> ~/.config/zsh/aliases.zsh
    fi
    if ! grep -q "starship" ~/.config/zsh/aliases.zsh; then
      echo 'eval "$(starship init zsh)"' >> ~/.config/zsh/aliases.zsh
    fi
  else
    warn "⚠️ ~/.config/zsh/aliases.zsh not found. Zoxide/Starship integration skipped."
  fi

  ok "✅ Dotfiles deployed"
}

# Summary
show_dot_summary() {
  echo
  echo "🎉 Dotfiles Setup Complete!"
  echo "📦 Installed: Kitty, Alacritty, Ghostty, Tmux, Neovim, Zsh, Zoxide, Starship"
  echo "🚀 Restart shell or Hyprland to apply."
  echo "🔧 Configs: ~/.config/{kitty,alacritty,ghostty,tmux,nvim,zsh}"
  echo
}

main() {
  echo "🖥️ Dotfiles Setup - Arch Linux Optimized"
  echo
  check_requirements
  setup_aur_helper
  install_terminals_dev
  deploy_dotfiles
  show_dot_summary
}

main "$@"
