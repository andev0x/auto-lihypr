# 🌿 auto-lihypr

A fully automated Hyprland setup script for Ubuntu Server with a focus on development environment and user experience.

## ✨ Features

- 🚀 One-command installation of Hyprland WM and essential tools
- 🎨 Beautiful SDDM login manager with Sugar Candy theme
- 🖥️ Automatic multi-monitor configuration
- 🎵 PipeWire audio system with Bluetooth support
- 🌐 NetworkManager with OpenVPN integration
- 🔧 Development tools pre-configured:
  - Neovim with LSP support
  - Tmux for terminal multiplexing
  - Zsh with Starship prompt
  - Git integration
- 🖼️ Dynamic wallpaper system with random selection
- 📦 Backup system for existing configurations
- 📝 Detailed installation logging

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/andev0x/auto-lihypr.git
cd auto-lihypr

# Make the script executable
chmod +x install.sh

# Run the installation
./install.sh
```

## 📋 Requirements

- Ubuntu Server 24.04 LTS
- Minimum 2 CPU cores
- Minimum 4GB RAM
- Sudo privileges

## 🎨 Customization

### Wallpapers
Place your wallpapers in `~/.config/hypr/wallpapers/`. Supported formats:
- JPG/JPEG
- PNG

To set a random wallpaper:
```bash
~/.config/hypr/set_wallpaper.sh --random
```

To set a specific wallpaper:
```bash
~/.config/hypr/set_wallpaper.sh --image /path/to/wallpaper.jpg
```

### Wallpaper Transition Effects
```bash
# Change transition type
~/.config/hypr/set_wallpaper.sh --transition wipe

# Adjust transition duration (seconds)
~/.config/hypr/set_wallpaper.sh --duration 1.5

# Combine options
~/.config/hypr/set_wallpaper.sh --random --transition fade --duration 2
```

## 🔧 Configuration

### Hyprland
- Main config: `~/.config/hypr/hyprland.conf`
- Keybinds: `~/.config/hypr/keybinds.conf`
- Monitors: `~/.config/hypr/monitors.conf`

### Development Tools
- Neovim: `~/.config/nvim/`
- Tmux: `~/.config/tmux/.tmux.conf`
- Zsh: `~/.config/zsh/.zshrc`

## 📝 Logging

Installation logs are saved to:
```bash
~/hyprland_install.log
```

## 🔄 Backup

Your existing configurations are automatically backed up to:
```bash
~/.config.bak.[timestamp]/
```

## 🛟 Troubleshooting

### Display Issues
1. Check monitor configuration:
   ```bash
   cat ~/.config/hypr/monitors.conf
   ```
2. Verify graphics drivers:
   ```bash
   lspci -k | grep -A 2 -E "(VGA|3D)"
   ```

### Audio Issues
1. Check PipeWire status:
   ```bash
   systemctl --user status pipewire
   ```
2. Verify audio devices:
   ```bash
   pactl info
   ```

### Network Issues
1. Check NetworkManager status:
   ```bash
   systemctl status NetworkManager
   ```
2. List WiFi networks:
   ```bash
   nmcli device wifi list
   ```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](License) file for details.