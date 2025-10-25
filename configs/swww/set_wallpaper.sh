#!/usr/bin/env bash
# Simple wallpaper setter using swww
WALLPAPER_DIR="$HOME/.config/wallpapers"
WALLPAPER="$WALLPAPER_DIR/default.jpg"

swww img "$WALLPAPER" --transition-type any --transition-duration 2 --transition-fps 60

