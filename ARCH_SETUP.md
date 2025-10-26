# 🐧 Arch Linux Setup Guide

This guide provides step-by-step instructions for setting up Hyprland on Arch Linux using the auto-lihypr configuration.

## 📋 Prerequisites

### System Requirements
- **Arch Linux** (latest rolling release)
- Minimum 2 CPU cores
- Minimum 4GB RAM
- Sudo privileges
- Internet connection

### Recommended AUR Helper
Install an AUR helper for seamless package management:

```bash
# Install paru (recommended)
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ~
rm -rf /tmp/paru

# Or install yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ~
rm -rf /tmp/yay
```

## 🚀 Quick Installation

### 1. Clone the Repository
```bash
git clone https://github.com/andev0x/auto-lihypr.git
cd auto-lihypr
```

### 2. Run the Installation Script
```bash
chmod +x install.sh
./install.sh
```

The script will:
- ✅ Detect Arch Linux
- ✅ Update your system
- ✅ Install all required packages
- ✅ Set up AUR helper (if needed)
- ✅ Deploy all configurations
- ✅ Configure system services

## 📦 Package Installation Details

### Official Repository Packages
The following packages are installed from official Arch repositories:

| Package | Repository | Purpose |
|---------|------------|--------|
| `hyprland` | community | Wayland compositor |
| `waybar` | community | Status bar |
| `kitty` | community | Terminal emulator |
| `ghostty` | community | Alternative terminal |
| `wofi` | community | Application launcher |
| `mako` | community | Notification daemon |
| `pipewire` | extra | Audio system |
| `pipewire-pulse` | extra | PulseAudio compatibility |
| `wireplumber` | extra | Session manager |
| `networkmanager` | extra | Network management |
| `grim` | community | Screenshot tool |
| `slurp` | community | Screen area selection |
| `wl-clipboard` | community | Clipboard utilities |
| `brightnessctl` | community | Brightness control |
| `playerctl` | community | Media player control |
| `pavucontrol` | community | Audio control GUI |

### AUR Packages
The following packages are installed from AUR:

| Package | Purpose |
|---------|--------|
| `swww` | Wallpaper transitions |
| `ttf-jetbrains-mono-nerd` | Terminal fonts with icons |
| `hyprlock` | Screen locker |

## 🔧 Configuration Files

After installation, your configuration files will be located in:

```
~/.config/
├── hypr/              # Hyprland configuration
│   ├── hyprland.conf  # Main configuration
│   ├── keybinds.conf  # Key bindings
│   ├── decorations.conf # Window decorations
│   ├── monitors.conf  # Monitor settings
│   └── wallpapers/    # Wallpaper collection
├── waybar/            # Status bar configuration
├── mako/              # Notification daemon
├── kitty/             # Kitty terminal
├── ghostty/           # Ghostty terminal
├── wofi/              # Application launcher
├── swww/              # Wallpaper management
├── nvim/              # Neovim editor
├── zsh/               # Zsh shell
└── starship.toml      # Shell prompt
```

## 🎨 Customization

### Wallpapers
Place your wallpapers in `~/.config/hypr/wallpapers/`:
```bash
# Set random wallpaper
~/.config/swww/set_wallpaper.sh --random

# Set specific wallpaper
~/.config/swww/set_wallpaper.sh --image /path/to/wallpaper.jpg

# Change transition effect
~/.config/swww/set_wallpaper.sh --transition wipe --duration 2
```

### Key Bindings
Default key bindings (Super key = Windows key):

| Key Combination | Action |
|----------------|--------|
| `Super + Enter` | Open terminal (Kitty) |
| `Super + Q` | Close active window |
| `Super + E` | Open application launcher |
| `Super + R` | Change wallpaper |
| `Super + F` | Toggle fullscreen |
| `Super + M` | Exit Hyprland |
| `Super + L` | Lock screen |
| `Super + Space` | Toggle floating window |
| `Super + 1-5` | Switch workspaces |
| `Super + Shift + 1-3` | Move window to workspace |

### Terminal Configuration
Both Kitty and Ghostty are configured with:
- JetBrainsMono Nerd Font
- Dark theme optimized for development
- Proper Wayland integration

## 🔧 System Services

The following services are automatically configured:

### User Services (systemd --user)
```bash
# Check status
systemctl --user status pipewire pipewire-pulse wireplumber

# Restart if needed
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### System Services
```bash
# Check NetworkManager status
sudo systemctl status NetworkManager

# Enable if not already enabled
sudo systemctl enable NetworkManager
```

## 🚀 Starting Hyprland

### Method 1: Display Manager
1. Log out of your current session
2. Select "Hyprland" from your display manager
3. Login

### Method 2: Command Line
```bash
# Start Hyprland directly
dbus-run-session Hyprland

# Or start from TTY
Hyprland
```

## 🛠️ Troubleshooting

### Package Issues
```bash
# Update system
sudo pacman -Syu

# Fix broken packages
sudo pacman -S --needed $(pacman -Qnq)

# Clear package cache
sudo pacman -Sc
```

### AUR Package Issues
```bash
# Update AUR packages
paru -Syu

# Or with yay
yay -Syu
```

### Configuration Issues
```bash
# Check Hyprland logs
journalctl --user -u hyprland-session.target

# Test configuration
hyprctl reload
```

### Audio Issues
```bash
# Check PipeWire status
systemctl --user status pipewire

# Restart audio services
systemctl --user restart pipewire pipewire-pulse wireplumber

# Check audio devices
pactl info
```

### Display Issues
```bash
# Check monitor configuration
hyprctl monitors

# Reload configuration
hyprctl reload
```

## 📚 Additional Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [Wayland Protocol](https://wayland.freedesktop.org/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
