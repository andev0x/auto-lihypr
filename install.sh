#!/usr/bin/env bash

set -e

# ==================================================
# 🌿 anvndev Hyprland Setup for Ubuntu 24.04 LTS
# Full auto-setup for backend/devops environment
# ==================================================

echo "🌿 Starting anvndev environment setup..."

# --------------------------------------------------
# 1. System update
# --------------------------------------------------
sudo apt update -y && sudo apt upgrade -y

# --------------------------------------------------
# 2. Install core packages
# --------------------------------------------------
sudo apt install -y git curl wget zsh tmux neovim ripgrep fd-find unzip fzf build-essential \
  python3 python3-pip golang-go rustc cargo nodejs npm

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
echo "🌈 Installing Hyprland..."
sudo add-apt-repository -y ppa:hyprland-dev/stable || true
sudo apt update && sudo apt install -y hyprland waybar rofi kitty

# --------------------------------------------------
# 7. Copy config files
# --------------------------------------------------
CONFIG_DIR="$HOME/.config"
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
# 10. Done!
# --------------------------------------------------
echo ""
echo "✅ anvndev setup complete!"
echo "💡 Please log out and back in to apply Zsh + Hyprland environment."

