#!/usr/bin/env bash

set -e

# ==================================================
# 🌿 anvndev Hyprland Setup for Ubuntu 24.04 LTS
# Full auto-setup for backend/devops environment
# ==================================================

# Setup logging
LOGFILE="$HOME/hyprland_install.log"
exec 1> >(tee -a "$LOGFILE") 2>&1

# Progress tracking
STEPS_TOTAL=11
current_step=0

show_progress() {
    current_step=$((current_step + 1))
    echo "[$current_step/$STEPS_TOTAL] $1"
    echo "-------------------------------------------"
}

# Error handling
handle_error() {
    echo "❌ Error occurred in install.sh on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please do not run as root. Use normal user with sudo privileges."
    exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "❌ This script is designed for Ubuntu. Other distributions are not supported."
    exit 1
fi

# Check system requirements
echo "🔍 Checking system requirements..."
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')

if [ "$CPU_CORES" -lt 2 ] || [ "$TOTAL_MEM" -lt 4 ]; then
    echo "❌ System requirements not met:"
    echo "Minimum: 2 CPU cores and 4GB RAM"
    echo "Found: $CPU_CORES cores and ${TOTAL_MEM}GB RAM"
    exit 1
fi

echo "🌿 Starting anvndev environment setup..."

# --------------------------------------------------
# 1. System update
# --------------------------------------------------
sudo apt update -y

# --------------------------------------------------
# 2. Install core packages and display manager
# --------------------------------------------------
echo "📦 Installing core packages..."
sudo apt install -y git curl wget zsh tmux neovim ripgrep fd-find unzip fzf build-essential \
  python3 python3-pip golang-go rustc cargo nodejs npm \
  sddm wayland xorg-xwayland mesa-utils \
  pipewire pipewire-pulse wireplumber pavucontrol \
  network-manager networkmanager-openvpn plasma-nm

# Setup GPU drivers
echo "🎮 Setting up GPU drivers..."
if lspci | grep -i "nvidia" > /dev/null; then
    sudo apt install -y nvidia-driver-535 nvidia-utils-535
    # Enable nvidia-drm modeset
    echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
elif lspci | grep -i "amd" > /dev/null; then
    sudo apt install -y mesa-vulkan-drivers
else
    sudo apt install -y mesa-utils
fi

# Configure SDDM for Hyprland
echo "🔐 Setting up SDDM..."
sudo systemctl enable sddm

# Install SDDM theme
echo "🎨 Setting up SDDM theme..."
SDDM_THEME="sugar-candy"
sudo apt install -y qt5-style-plugins
git clone https://github.com/Kangie/sddm-sugar-candy.git /tmp/sddm-sugar-candy
sudo cp -r /tmp/sddm-sugar-candy/Sugar-Candy /usr/share/sddm/themes/
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << EOL
[Theme]
Current=$SDDM_THEME
EOL

# Configure Wayland session
sudo mkdir -p /usr/share/wayland-sessions/
sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << EOL
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOL

# Setup automatic monitor configuration
echo "🖥️ Setting up monitor configuration..."
MONITOR_CONFIG="$HOME/.config/hypr/monitors.conf"
mkdir -p "$(dirname "$MONITOR_CONFIG")"
if command -v wlr-randr >/dev/null 2>&1; then
    echo "# Generated monitor configuration" > "$MONITOR_CONFIG"
    wlr-randr | grep -w "connected" | while read -r line; do
        monitor=$(echo "$line" | awk '{print $1}')
        echo "monitor=$monitor,preferred,auto,1" >> "$MONITOR_CONFIG"
    done
else
    echo "monitor=,preferred,auto,1" > "$MONITOR_CONFIG"
fi

# Setup wallpaper system
echo "🖼️ Setting up wallpaper system..."
mkdir -p "$HOME/.config/hypr/wallpapers"
cp -r ./wallpapers/* "$HOME/.config/hypr/wallpapers/" 2>/dev/null || true

# Copy and setup wallpaper script
if [ -f "./configs/swww/set_wallpaper.sh" ]; then
    cp ./configs/swww/set_wallpaper.sh "$HOME/.config/hypr/"
    chmod +x "$HOME/.config/hypr/set_wallpaper.sh"

    # Create wallpaper rotation service
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/hyprland-wallpaper.service" << EOL
[Unit]
Description=Hyprland Wallpaper Rotation Service
PartOf=graphical-session.target

[Service]
ExecStart=$HOME/.config/hypr/set_wallpaper.sh --random
Restart=always
RestartSec=3600

[Install]
WantedBy=default.target
EOL

    # Enable wallpaper rotation service
    systemctl --user enable hyprland-wallpaper.service
fi

# Add wallpaper initialization to Hyprland config
if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
    if ! grep -q "set_wallpaper.sh" "$HOME/.config/hypr/hyprland.conf"; then
        echo -e "\n# Initialize wallpaper" >> "$HOME/.config/hypr/hyprland.conf"
        echo "exec-once = $HOME/.config/hypr/set_wallpaper.sh --random" >> "$HOME/.config/hypr/hyprland.conf"
    fi
fi

# --------------------------------------------------
# 3. Install fonts (JetBrainsMono Nerd)
# --------------------------------------------------
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
echo "🧩 Installing JetBrainsMono Nerd Font..."
wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -O /tmp/JetBrainsMono.zip
unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
fc-cache -fv

# --------------------------------------------------
# 4. Install Starship prompt
# --------------------------------------------------
echo "💫 Installing Starship..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

# --------------------------------------------------
# 5. Install Zoxide (smart directory jumper)
# --------------------------------------------------
echo "⚡ Installing Zoxide..."
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# --------------------------------------------------
# 6. Hyprland installation (Wayland compositor)
# --------------------------------------------------
echo "🌈 Installing Hyprland and dependencies..."
sudo add-apt-repository -y ppa:hyprland-dev/stable || true
sudo apt update
sudo apt install -y hyprland waybar rofi kitty \
    wofi mako grim slurp wl-clipboard \
    network-manager-gnome blueman \
    brightnessctl pamixer swaylock

# --------------------------------------------------
# 7. Setup Audio and Network
# --------------------------------------------------
echo "🔊 Setting up audio..."
# Enable and start PipeWire services
systemctl --user enable pipewire.service
systemctl --user start pipewire.service
systemctl --user enable pipewire-pulse.service
systemctl --user start pipewire-pulse.service
systemctl --user enable wireplumber.service
systemctl --user start wireplumber.service

echo "🌐 Setting up network..."
# Enable NetworkManager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
# Enable Bluetooth
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# --------------------------------------------------
# 8. Backup and Copy config files
# --------------------------------------------------
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config.bak.$(date +%Y%m%d_%H%M%S)"

# Backup existing configs
if [ -d "$CONFIG_DIR" ]; then
    echo "📦 Backing up existing configs to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    for dir in nvim tmux hypr waybar starship.toml; do
        if [ -e "$CONFIG_DIR/$dir" ]; then
            cp -r "$CONFIG_DIR/$dir" "$BACKUP_DIR/"
        fi
    done
fi

# Copy new configs
echo "📝 Copying new config files..."
mkdir -p "$CONFIG_DIR"
cp -r ./configs/nvim "$CONFIG_DIR/nvim"
cp -r ./configs/tmux "$CONFIG_DIR/tmux"
cp -r ./configs/hypr "$CONFIG_DIR/hypr"
cp -r ./configs/waybar "$CONFIG_DIR/waybar"
cp ./configs/starship.toml "$CONFIG_DIR/starship.toml"

# --------------------------------------------------
# 8. Set up Zsh as default shell
# --------------------------------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "💻 Changing default shell to Zsh..."
  chsh -s "$(which zsh)"
fi

# --------------------------------------------------
# 9. Configure Zsh + Starship + Zoxide
# --------------------------------------------------
ZSHRC="$HOME/.zshrc"

if ! grep -q "eval \"\$(starship init zsh)\"" "$ZSHRC"; then
  echo 'eval "$(starship init zsh)"' >> "$ZSHRC"
fi

if ! grep -q "eval \"\$(zoxide init zsh)\"" "$ZSHRC"; then
  echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC"
fi

# --------------------------------------------------
# 10. Verify Installation
# --------------------------------------------------
echo "🔍 Verifying installation..."

# Check critical components
COMPONENTS=(
    "hyprland"
    "sddm"
    "waybar"
    "kitty"
    "zsh"
    "nvim"
)

for component in "${COMPONENTS[@]}"; do
    if ! command -v "$component" >/dev/null 2>&1 && [ ! -f "/usr/bin/$component" ]; then
        echo "❌ $component is not properly installed!"
        exit 1
    fi
done

# Verify SDDM is enabled
if ! systemctl is-enabled sddm >/dev/null 2>&1; then
    echo "❌ SDDM is not properly enabled!"
    exit 1
fi

# --------------------------------------------------
# 11. Done!
# --------------------------------------------------
echo ""
echo "✅ anvndev setup complete!"
echo "💡 Installation successful! Please reboot your system to start using Hyprland."
echo "   After reboot:"
echo "   1. Select 'Hyprland' session at the SDDM login screen"
echo "   2. Login with your username and password"
echo ""
echo "   To start fresh: sudo systemctl reboot"
