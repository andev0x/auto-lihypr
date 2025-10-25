#!/usr/bin/env bash

# ==================================================
# 🌿 anvndev Hyprland Setup for Ubuntu 24.04 LTS
# Full auto-setup for backend/devops environment
# ==================================================

# Setup logging
LOGFILE="$HOME/hyprland_install.log"
exec 1> >(tee -a "$LOGFILE") 2>&1

# Error handling and cleanup function
cleanup() {
    if [ "$?" -ne 0 ]; then
        echo "❌ Error occurred during installation. Check $LOGFILE for details."
        echo "❌ Last error occurred in section: $CURRENT_SECTION"
    fi
}

trap cleanup EXIT

# Function to handle apt operations with retry mechanism
apt_install() {
    local packages=("$@")
    local max_attempts=3
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        echo "📦 Installing packages (Attempt $attempt/$max_attempts)..."
        
        # Wait for apt lock to be released
        while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
            echo "⏳ Waiting for other software managers to finish..."
            sleep 1
        done

        # Try to install packages
        if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" >/dev/null 2>&1; then
            echo "✅ Package installation successful!"
            return 0
        else
            echo "⚠️ Package installation failed. Retrying in $wait_time seconds..."
            sleep $wait_time
            # Update package list before retry
            sudo apt-get update >/dev/null 2>&1
            wait_time=$((wait_time * 2))
            attempt=$((attempt + 1))
        fi
    done

    echo "❌ Failed to install packages after $max_attempts attempts."
    return 1
}

# Function to verify package installation
verify_packages() {
    local packages=("$@")
    local failed_packages=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            failed_packages+=("$pkg")
        fi
    done

    if [ ${#failed_packages[@]} -ne 0 ]; then
        echo "❌ Following packages failed to install:"
        printf '%s\n' "${failed_packages[@]}"
        return 1
    fi
    return 0
}

# Store currently executing section for error reporting
CURRENT_SECTION=""

# Exit on error, but ensure cleanup runs
set -e

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
CURRENT_SECTION="System Update"
echo "🔄 Updating system packages..."

# Wait for apt lock to be released
while sudo fuser /var/{lib/{dpkg,apt/lists},cache/apt/archives}/lock >/dev/null 2>&1; do
    echo "⏳ Waiting for other software managers to finish..."
    sleep 1
done

# Update package lists
for i in {1..3}; do
    if sudo apt-get update >/dev/null 2>&1; then
        break
    else
        echo "⚠️ Update failed, retrying... (Attempt $i/3)"
        sleep 5
    fi
done

# Upgrade packages with error handling
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >/dev/null 2>&1; then
    echo "⚠️ Full upgrade failed, attempting minimal upgrade..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade --without-new-pkgs -y
fi

# --------------------------------------------------
# 2. Install core packages and display manager
# --------------------------------------------------
CURRENT_SECTION="Core Package Installation"
echo "📦 Installing core packages..."

# Define package groups
CORE_PKGS=(git curl wget zsh tmux neovim ripgrep fd-find unzip fzf build-essential)
LANG_PKGS=(python3 python3-pip golang-go rustc cargo nodejs npm)
DISPLAY_PKGS=(sddm wayland xorg-xwayland mesa-utils)
AUDIO_PKGS=(pipewire pipewire-pulse wireplumber pavucontrol)
NETWORK_PKGS=(network-manager networkmanager-openvpn plasma-nm)

# Install packages by group with verification
for group in "CORE_PKGS" "LANG_PKGS" "DISPLAY_PKGS" "AUDIO_PKGS" "NETWORK_PKGS"; do
    echo "📦 Installing ${group}..."
    if ! apt_install "${!group[@]}"; then
        echo "❌ Failed to install ${group}. Cannot continue."
        exit 1
    fi
    
    # Verify installation
    if ! verify_packages "${!group[@]}"; then
        echo "❌ Package verification failed for ${group}. Cannot continue."
        exit 1
    fi
done

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
CURRENT_SECTION="Hyprland Installation"
echo "🌈 Installing Hyprland and dependencies..."

# Add Hyprland repository with retry
max_attempts=3
attempt=1
while [ $attempt -le $max_attempts ]; do
    if sudo add-apt-repository -y ppa:hyprland-dev/stable >/dev/null 2>&1; then
        break
    else
        echo "⚠️ Failed to add Hyprland repository (Attempt $attempt/$max_attempts)"
        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Could not add Hyprland repository. Cannot continue."
            exit 1
        fi
        sleep 5
        attempt=$((attempt + 1))
    fi
done

# Update package lists after adding repository
sudo apt-get update >/dev/null 2>&1

# Define Hyprland package groups
HYPR_CORE=(hyprland waybar rofi kitty)
HYPR_UTILS=(wofi mako grim slurp wl-clipboard)
HYPR_SYSTEM=(network-manager-gnome blueman brightnessctl pamixer swaylock)

# Install Hyprland packages by group
for group in "HYPR_CORE" "HYPR_UTILS" "HYPR_SYSTEM"; do
    echo "📦 Installing ${group}..."
    if ! apt_install "${!group[@]}"; then
        echo "❌ Failed to install ${group}. Cannot continue."
        exit 1
    fi
    
    # Verify installation
    if ! verify_packages "${!group[@]}"; then
        echo "❌ Package verification failed for ${group}. Cannot continue."
        exit 1
    fi
done

# Verify Hyprland installation specifically
if ! command -v Hyprland >/dev/null 2>&1; then
    echo "❌ Hyprland installation verification failed. Cannot continue."
    exit 1
fi

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
