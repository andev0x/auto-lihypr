#!/usr/bin/env bash
# ==================================================
# 🧪 Arch Linux Configuration Validation Script
# ==================================================

# Colors
log() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
ok() { echo -e "\033[1;32m[PASS]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
err() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }

echo "🧪 ==============================================="
echo "🧪 Arch Linux Configuration Validation"
echo "🧪 ==============================================="
echo

# Check if running on Arch Linux
. /etc/os-release 2>/dev/null || true
if [ "${ID:-}" = "arch" ] || [[ "${ID_LIKE:-}" == *arch* ]]; then
  ok "Running on Arch Linux: ${PRETTY_NAME:-$ID}"
else
  warn "Not running on Arch Linux: ${PRETTY_NAME:-$ID}"
fi

# Check package availability
log "Checking package availability..."

packages=(
  "hyprland:community/hyprland"
  "waybar:community/waybar"
  "kitty:community/kitty"
  "wofi:community/wofi"
  "mako:community/mako"
  "pipewire:extra/pipewire"
  "networkmanager:extra/networkmanager"
)

for pkg_info in "${packages[@]}"; do
  pkg_name="${pkg_info%%:*}"
  pkg_repo="${pkg_info##*:}"
  
  if pacman -Si "$pkg_name" >/dev/null 2>&1; then
    ok "Package $pkg_name available in $pkg_repo"
  else
    err "Package $pkg_name not found in repositories"
  fi
done

# Check AUR packages
log "Checking AUR package availability..."
aur_packages=("swww" "ttf-jetbrains-mono-nerd" "hyprlock")

for pkg in "${aur_packages[@]}"; do
  if curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$pkg" | grep -q '"Name":"'"$pkg"'"'; then
    ok "AUR package $pkg available"
  else
    warn "AUR package $pkg not found or AUR unavailable"
  fi
done

# Check configuration files
log "Checking configuration files..."

config_files=(
  "configs/hypr/hyprland.conf"
  "configs/hypr/keybinds.conf"
  "configs/hypr/decorations.conf"
  "configs/hypr/monitors.conf"
  "configs/waybar/config.jsonc"
  "configs/mako/config"
  "configs/kitty/kitty.conf"
  "configs/ghostty/config"
  "configs/starship.toml"
  "configs/swww/set_wallpaper.sh"
)

for file in "${config_files[@]}"; do
  if [ -f "$file" ]; then
    ok "Configuration file exists: $file"
  else
    err "Configuration file missing: $file"
  fi
done

# Check script permissions
log "Checking script permissions..."
if [ -x "install.sh" ]; then
  ok "install.sh is executable"
else
  warn "install.sh is not executable"
fi

# Check for AUR helpers
log "Checking for AUR helpers..."
aur_helpers=("paru" "yay" "aurman")
found_helper=false

for helper in "${aur_helpers[@]}"; do
  if command -v "$helper" >/dev/null 2>&1; then
    ok "AUR helper found: $helper"
    found_helper=true
  fi
done

if [ "$found_helper" = false ]; then
  warn "No AUR helper found (paru, yay, or aurman)"
fi

echo
echo "🧪 ==============================================="
echo "🧪 Validation Complete"
echo "🧪 ==============================================="
