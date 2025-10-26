# 🌿 auto-lihypr

A fully automated Hyprland setup script **optimized for Arch Linux** with Ubuntu/Debian support. This configuration is designed for a minimal, developer-friendly Wayland environment with maximum stability on Arch Linux.

## 🎯 **Primary Target: Arch Linux**

**This configuration is primarily designed and tested for Arch Linux.** All configurations are optimized for Arch Linux's rolling release model and package management system.

### Supported Systems:
- **Arch Linux (pacman)** — ✅ **Primary target, fully optimized**
- Ubuntu / Debian-based systems (apt) — ⚠️ Secondary support

### Arch Linux Advantages:
- Latest stable versions of all Wayland components
- Native package availability for all core dependencies
- Optimized systemd integration
- Rolling release ensures compatibility with latest features

Notes:
- Some utilities (for example `swww` for fancy wallpaper transitions) may only be available from the AUR on Arch. The installer will warn you and suggest how to install them.

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

# Run the installation (use a persistent session such as tmux on remote hosts)
./install.sh
```

## 📋 Requirements

### **Recommended: Arch Linux**
- **Arch Linux** (latest rolling release) — ✅ **Recommended for best experience**
- Minimum 2 CPU cores
- Minimum 4GB RAM
- Sudo privileges (the script uses sudo for package installation)
- AUR helper (optional but recommended): `paru`, `yay`, or `pacman` with manual AUR builds

### **Secondary Support: Ubuntu/Debian**
- Ubuntu Server 24.04 LTS (or other Debian/Ubuntu derivatives)
- Minimum 2 CPU cores  
- Minimum 4GB RAM
- Sudo privileges

### **Arch Linux Package Management**
The script uses `pacman` for official packages and provides guidance for AUR packages. All core dependencies are available in official Arch repositories for maximum stability.

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

Installation logs are written to the home directory. Possible locations used by the installer:

```bash
# Check either of these (one may exist depending on script version):
~/hyprland_install.log
~/auto-lihypr_install.log
```

If you see an error during installation, attach the most recent log file when asking for help.

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
### Package manager / dpkg / pacman issues

### **Arch Linux Package Issues**

If pacman reports a lock or interrupted transaction:

```bash
# If a lock file exists and no package manager is running, remove the lock (use with caution):
sudo rm -f /var/lib/pacman/db.lck

# If a transaction needs finishing, try:
sudo pacman -Syu --noconfirm
```

**Installing AUR Packages** (recommended for full functionality):

If the installer suggests installing an AUR-only package (for example `swww`), install it with an AUR helper:

```bash
# Using paru (recommended)
paru -S swww

# Using yay
yay -S swww

# Manual AUR installation
git clone https://aur.archlinux.org/swww.git
cd swww
makepkg -si
```

**Essential AUR packages for full functionality:**
- `swww` - Wallpaper transitions
- `ttf-jetbrains-mono-nerd` - Nerd Font for terminals
- `hyprlock` - Screen locker (if not in official repos)

### **Ubuntu/Debian Package Issues**

If you see an error like "dpkg was interrupted" or the installer fails because of a broken package state:

```bash
sudo dpkg --configure -a
sudo apt-get install -f -y
sudo apt-get update
```

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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.