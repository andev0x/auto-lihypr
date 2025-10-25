#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# anvndev Hyprland Installer (Ubuntu 24.04 LTS)
# - Copy configs from ./configs -> ~/.config
# - Install Hyprland + Waybar + common Wayland tools (best-effort)
# - Install dev tools (zsh, starship, zoxide, rustup, go, python)
# - Install JetBrainsMono Nerd Font (user-level)
# - Add user to docker group
# - Create / enable optional systemd --user wallpaper service (only if user bus available)
# - Robust apt handling, retries, verification
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=
\n\t'

# ---------------------------
# Editable defaults
# ---------------------------
TERMINAL_CMD="alacritty"           # placeholder used in hypr configs if needed
LAUNCHER_CMD="wofi --show drun"
CATPPUCCIN_FLAVOR="mocha"
ACCENT_COLOR="#1f6f4f"
ENABLE_PIKA_REPO=true              # optional third-party repo (enabled by default for Hyprland)
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
  # Wait for apt/dpkg locks to be released
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
  # Usage: apt_install_retry pkg1 pkg2 ...
  local packages=("$@")
  local attempt=1
  while [ $attempt -le $RETRY_MAX ]; do
    apt_wait_for_locks
    log "Installing packages (attempt $attempt/$RETRY_MAX): ${packages[*]}"
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
      return 0
    fi
    warn "apt install failed (attempt $attempt). Running apt-get update and retrying..."
    apt_update_retry
    attempt=$((attempt + 1))
    sleep $((attempt * 2))
  done
  die "Failed to install packages after $RETRY_MAX attempts: ${packages[*]}"
}

verify_pkg_installed() {
  # usage: verify_pkg_installed pkgname
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

verify_packages() {
  local missing=()
  for p in "$@"; do
    if ! verify_pkg_installed "$p"; then
      missing+=("$p")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    warn "The following packages were not installed via apt (may be available via other repos):"
    printf ' - %s\n' "${missing[@]}"
    return 1
  fi
  return 0
}

user_systemctl_available() {
  # Check if `systemctl --user` is usable (user systemd bus running)
  if systemctl --user >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# ---------------------------
# Prechecks
# ---------------------------
if [ "$EUID" -eq 0 ]; then
  die "Do not run this script as root. Run as normal user with sudo privileges."
}

if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
  die "This installer is designed for Ubuntu. Aborting."
}

log "Checking system resources..."
MIN_CORES=2
MIN_MEM_GB=4
CPU_CORES=$(nproc --all)
TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$CPU_CORES" -lt "$MIN_CORES" ] || [ "$TOTAL_MEM_GB" -lt "$MIN_MEM_GB" ]; then
  warn "Detected $CPU_CORES cores and ${TOTAL_MEM_GB}GB RAM; recommended >= ${MIN_CORES} cores and >= ${MIN_MEM_GB}GB RAM."
  # Not fatal — warn only
fi

# ---------------------------
# 1) Update apt
# ---------------------------
CURRENT_SECTION="apt_update"
log "Updating apt lists..."
apt_update_retry

# ---------------------------
# 2) Install basic packages (core + lang + wayland tooling)
# ---------------------------
CURRENT_SECTION="install_core_packages"
log "Installing core packages (best-effort)..."

# Core packages we attempt to install
CORE_PACKAGES=(git curl wget unzip jq fzf ripgrep fd-find bat eza)
LANG_PACKAGES=(python3 python3-pip golang-go)
RUST_PACKAGES=(build-essential pkg-config libssl-dev cmake)
# Wayland/Hyprland-related packages (names vary across distros; some may be missing)
WAYLAND_PACKAGES=(xwayland swaybg libwayland-dev libegl1-mesa)
HYPR_PACKAGES=(hyprland waybar wofi mako swww grim slurp wl-clipboard wayland-protocols)
AUDIO_PACKAGES=(pipewire pipewire-pulse wireplumber pavucontrol)
DISPLAY_MANAGER_PACKAGES=(sddm)
TERMINAL_PACKAGES=(alacritty)

# Try to install groups, but don't abort entire script if some not found — apt_install_retry will fail if apt can't install package names explicitly.
# We'll attempt smaller sets to reduce big failures.
apt_install_retry "${CORE_PACKAGES[@]}" || warn "Some core packages failed to install; continuing."
apt_install_retry "${LANG_PACKAGES[@]}" || warn "Some language packages failed to install; continuing."
apt_install_retry "${RUST_PACKAGES[@]}" || warn "Rust build tools partial install may have failed; continuing."
apt_install_retry "${TERMINAL_PACKAGES[@]}" || warn "Terminal package install may have failed; continuing."

# Create a symlink for bat -> batcat if needed
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    log "Creating symlink for bat -> batcat"
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
fi

# Try to add hyprland repo if requested
if [ "$ENABLE_PIKA_REPO" = "true" ]; then
  log "Adding PikaOS community repo (third-party) - use at your own risk"
  sudo mkdir -p /etc/apt/keyrings
  if wget -qO- "https://ppa.pika-os.com/key.gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/pikaos-archive-keyring.gpg; then
    echo "deb [signed-by=/etc/apt/keyrings/pikaos-archive-keyring.gpg] https://ppa.pika-os.com/ stable main" | sudo tee /etc/apt/sources.list.d/pikaos.list >/dev/null
    apt_update_retry
  else
    warn "Failed to add Pika repo key; skipping."
  fi
fi

# Try installing Hyprland-related packages via apt; if they don't exist, we'll fallback later.
log "Attempting to install Hyprland-related packages via apt..."
if apt_install_retry "${HYPR_PACKAGES[@]}"; then
  log "Hyprland-related packages installed via apt (or some of them)."
else
  warn "Could not install all Hyprland packages from apt; will try fallback installer for Hyprland later."
fi

# Audio and network
apt_install_retry "${AUDIO_PACKAGES[@]}" || warn "Audio packages partial install."
apt_install_retry "${DISPLAY_MANAGER_PACKAGES[@]}" || warn "Display manager packages partial install."

# ---------------------------
# 3) Install fonts (JetBrainsMono Nerd)
# ---------------------------
CURRENT_SECTION="install_fonts"
log "Installing JetBrainsMono Nerd Font into $FONT_DIR..."
mkdir -p "$FONT_DIR"
tmpd="$(mktemp -d)"
pushd "$tmpd" >/dev/null
if wget -q --spider "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
  wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -O JetBrainsMono.zip
  unzip -o JetBrainsMono.zip -d jetbrains
  mv jetbrains/*.ttf "$FONT_DIR/" 2>/dev/null || true
else
  warn "Could not download JetBrainsMono zip; trying git fallback..."
  if command -v git >/dev/null 2>&1; then
    git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git nerd-fonts-temp
    cp nerd-fonts-temp/patched-fonts/JetBrainsMono/*.ttf "$FONT_DIR/" 2>/dev/null || true
    rm -rf nerd-fonts-temp
  else
    warn "git not available; please install Nerd Fonts manually."
  fi
fi
popd >/dev/null
rm -rf "$tmpd"
fc-cache -fv || true
log "Fonts installed (if downloads succeeded)."

# ---------------------------
# 4) Install Starship & zoxide
# ---------------------------
CURRENT_SECTION="dev_tools"
log "Installing Starship & zoxide..."
if ! command -v starship >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y || warn "Starship installation failed."
fi
if ! command -v zoxide >/dev/null 2>&1; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || warn "zoxide install failed."
fi

# rustup (optional)
if ! command -v rustc >/dev/null 2>&1; then
  log "Installing rustup toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || warn "rustup install failed"
  export PATH="$HOME/.cargo/bin:$PATH"
fi

# go (use apt if available)
if ! command -v go >/dev/null 2>&1; then
  if apt-cache show golang-go >/dev/null 2>&1; then
    apt_install_retry golang-go || warn "golang apt install failed"
  else
    warn "golang not available in apt; please install manually if needed"
  fi
}

# ---------------------------
# 5) Hyprland fallback installer (if hyprland not found)
# ---------------------------
CURRENT_SECTION="hypr_fallback"
if ! command -v hyprland >/dev/null 2>&1 && ! command -v Hyprland >/dev/null 2>&1; then
  warn "Hyprland binary not found. Attempting official Hyprland installer (fallback)."
  # Try official install script (this script may build from source)
  if curl -fsSL https://raw.githubusercontent.com/hyprwm/Hyprland/main/install.sh | bash -s -- --unattended; then
    log "Hyprland installed via official installer."
  else
    warn "Hyprland official installer failed. You may need to install Hyprland manually or enable a distro/community repo."
  fi
else
  log "Hyprland binary detected."
fi

# ---------------------------
# 6) GPU drivers (best-effort)
# ---------------------------
CURRENT_SECTION="gpu"
log "Checking GPU vendor for driver hints..."
if lspci | grep -qi nvidia; then
  warn "NVIDIA GPU detected. Using ubuntu-drivers to install recommended drivers."
  sudo ubuntu-drivers autoinstall || warn "NVIDIA driver installation failed."
  sudo bash -c 'echo "options nvidia-drm modeset=1" > /etc/modprobe.d/nvidia.conf' || warn "Could not write nvidia.conf"
elif lspci | grep -qi amd; then
  apt_install_retry mesa-vulkan-drivers || warn "mesa vulkan drivers install failed."
else
  apt_install_retry mesa-utils || warn "mesa-utils install failed."
fi

# ---------------------------
# 7) Display manager session entry for Hyprland (if SDDM exists)
# ---------------------------
CURRENT_SECTION="sddm_session"
if [ -d /usr/share/wayland-sessions ]; then
  log "Creating Hyprland .desktop session"
  sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<'EOS'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland - dynamic tiling Wayland compositor
Exec=hyprland
Type=Application
EOS
fi

# ---------------------------
# 8) Backup current configs and copy repo configs
# ---------------------------
CURRENT_SECTION="copy_configs"
log "Backing up existing ~/.config to $BACKUP_DIR (selected dirs) and copying new configs..."

mkdir -p "$BACKUP_DIR"
mkdir -p "$HOME/.config"

for d in nvim tmux hypr waybar wofi mako swww starship.toml zsh alacritty kitty ghostty; do
  if [ -e "$HOME/.config/$d" ] || [ -e "$HOME/.$d" ]; then
    log "Backing up $d"
    mkdir -p "$BACKUP_DIR"
    if [ -e "$HOME/.config/$d" ]; then
      cp -r "$HOME/.config/$d" "$BACKUP_DIR/" || warn "Failed to backup $HOME/.config/$d"
    fi
    if [ -e "$HOME/.$d" ]; then
      cp -r "$HOME/.$d" "$BACKUP_DIR/" || warn "Failed to backup $HOME/.$d"
    fi
  fi
done

# Copy from repo configs folder (expect ./configs exists)
if [ -d "$REPO_ROOT/configs" ]; then
  log "Copying configs from $REPO_ROOT/configs to ~/.config/"
  cp -rv "$REPO_ROOT/configs/"* "$HOME/.config/" || warn "Some config copy operations failed"
else
  warn "No configs folder found in repo ($REPO_ROOT/configs). Skipping copy."
fi

# Ensure starship config if provided
if [ -f "$REPO_ROOT/configs/starship.toml" ]; then
  mkdir -p "$HOME/.config"
  cp -v "$REPO_ROOT/configs/starship.toml" "$HOME/.config/starship.toml" || warn "Failed to copy starship.toml"
}

# Copy wallpapers if present
if [ -d "$REPO_ROOT/wallpapers" ]; then
  mkdir -p "$HOME/.config/hypr/wallpapers"
  cp -rv "$REPO_ROOT/wallpapers/"* "$HOME/.config/hypr/wallpapers/" || true
fi

# Make set_wallpaper.sh executable
if [ -f "$HOME/.config/swww/set_wallpaper.sh" ]; then
    chmod +x "$HOME/.config/swww/set_wallpaper.sh"
fi

# ---------------------------
# 9) Install fonts from repo (if any)
# ---------------------------
CURRENT_SECTION="repo_fonts"
if [ -d "$REPO_ROOT/fonts" ]; then
  log "Copying repository fonts into $FONT_DIR"
  mkdir -p "$FONT_DIR"
  cp -v "$REPO_ROOT/fonts/"* "$FONT_DIR/" 2>/dev/null || true
  fc-cache -fv || true
fi

# ---------------------------
# 10) Setup user shell configs (zsh, starship, zoxide)
# ---------------------------
CURRENT_SECTION="shell_setup"
log "Setting zsh as default shell if not already"

if [ -x "$(command -v zsh)" ]; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    if chsh -s "$(command -v zsh)"; then
      log "Default shell changed to zsh (you may need to log out/in to apply)."
    else
      warn "chsh failed; you may need to enter your password or change default shell manually."
    fi
  fi
else
  warn "zsh not installed - ensure zsh is installed if you want to use it."
fi

# Append starship & zoxide init to ~/.zshrc if not present
ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"
if ! grep -q 'starship init zsh' "$ZSHRC"; then
  printf '\n# Starship prompt\n' >> "$ZSHRC"
  printf 'eval "$(starship init zsh)"\n' >> "$ZSHRC"
fi
if ! grep -q 'zoxide init zsh' "$ZSHRC"; then
  printf '\n# zoxide\n' >> "$ZSHRC"
  printf 'eval "$(zoxide init zsh)"\n' >> "$ZSHRC"
fi

# ---------------------------
# 11) Add user to docker group
# ---------------------------
CURRENT_SECTION="docker_group"
if command -v docker >/dev/null 2>&1; then
    if id -nG "$USER_TO_ADD_DOCKER_GROUP" | grep -qw docker; then
      log "User $USER_TO_ADD_DOCKER_GROUP already in docker group"
    else
      log "Adding $USER_TO_ADD_DOCKER_GROUP to docker group (requires logout/login to take effect)"
      sudo usermod -aG docker "$USER_TO_ADD_DOCKER_GROUP" || warn "Failed to add user to docker group"
    fi
else
    warn "Docker is not installed. Skipping adding user to docker group."
fi

# ---------------------------
# 12) Create systemd --user wallpaper service (optional)
# ---------------------------
CURRENT_SECTION="user_services"
if [ "$ENABLE_SYSTEMD_USER_SERVICE" = "true" ]; then
  if user_systemctl_available; then
    log "Creating user wallpaper systemd service (hyprland-wallpaper.service)"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/hyprland-wallpaper.service" <<'EOF'
[Unit]
Description=Hyprland Wallpaper Rotation Service
PartOf=graphical-session.target

[Service]
ExecStart=%h/.config/swww/set_wallpaper.sh
Restart=always
RestartSec=3600

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload || warn "systemctl --user daemon-reload failed"
    systemctl --user enable --now hyprland-wallpaper.service || warn "Failed to enable hyprland-wallpaper.service (user bus may not be active)"
  else
    warn "Skipping user service creation: systemctl --user not available in this session."
  fi
fi

# ---------------------------
# 13) Final verification
# ---------------------------
CURRENT_SECTION="final_verify"
log "Verifying critical binaries"
CRITICAL=(hyprland waybar wofi swww mako grim slurp wl-paste wl-copy zsh nvim tmux alacritty)
for bin in "${CRITICAL[@]}"; do
  if command -v "$bin" >/dev/null 2>&1; then
    log "Found: $bin"
  else
    warn "Missing (or not in PATH): $bin"
  fi
done

# If Hyprland present, attempt reload (non-fatal)
if command -v hyprctl >/dev/null 2>&1; then
  log "Reloading Hyprland config if running"
  hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed or Hyprland not running"
fi

echo ""
echo "🎉 Andev Hyprland installer finished. See $LOGFILE for details."
echo "Notes:"
echo " - You may need to log out / reboot to apply shell change and group membership."
echo " - If some packages were not installed, consider enabling community repos or building from source."
echo " - To start Hyprland: select 'Hyprland' session in your display manager or run 'hyprland' from TTY (if appropriate)."
