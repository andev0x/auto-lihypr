# 🌿 auto-lihypr

A fully automated Hyprland setup script for Ubuntu and Arch Linux focused on a minimal, developer-friendly Wayland environment.

Supports automatic installation on:
- Ubuntu / Debian-based systems (apt)
- Arch Linux (pacman) — installs pacman packages where available and falls back to building from source when necessary

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

- Ubuntu Server 24.04 LTS (or other Debian/Ubuntu derivatives) OR Arch Linux
- Minimum 2 CPU cores
- Minimum 4GB RAM
- Sudo privileges (the script uses sudo for package installation)

If you run on Arch Linux, the script uses `pacman` and will attempt to install available packages from the official repositories. Some packages (AUR-only) will be detected and a manual installation hint will be printed.

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

If you see an error like "dpkg was interrupted" or the installer fails because of a broken package state, run the following (Debian/Ubuntu):

```bash
sudo dpkg --configure -a
sudo apt-get install -f -y
sudo apt-get update
```

On Arch if pacman reports a lock or interrupted transaction:

```bash
# If a lock file exists and no package manager is running, remove the lock (use with caution):
sudo rm -f /var/lib/pacman/db.lck

# If a transaction needs finishing, try:
sudo pacman -Syu --noconfirm
```

If the installer suggests installing an AUR-only package (for example `swww`), you can install it with an AUR helper such as `paru` or `yay`:

```bash
paru -S swww
# or
yay -S swww
```

If you prefer automation and want the installer to build specific AUR packages automatically, open an issue or request and I can add a safe `makepkg` path for those packages.

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