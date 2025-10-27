#!/usr/bin/env bash
# Enhanced wallpaper setter using swww with random selection support

# Directory containing wallpapers
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"

# Function to get a random wallpaper
get_random_wallpaper() {
    find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1
}

# Initialize swww if not running
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww init
fi

# Default options
TRANSITION="fade"
TRANSITION_STEP=2
TRANSITION_DURATION=3

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --random)
            USE_RANDOM=1
            shift
            ;;
        --image)
            WALLPAPER="$2"
            shift 2
            ;;
        --transition)
            TRANSITION="$2"
            shift 2
            ;;
        --step)
            TRANSITION_STEP="$2"
            shift 2
            ;;
        --duration)
            TRANSITION_DURATION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get wallpaper path
if [ -n "$USE_RANDOM" ]; then
    WALLPAPER=$(get_random_wallpaper)
elif [ -z "$WALLPAPER" ]; then
    # If no wallpaper specified, use random
    WALLPAPER=$(get_random_wallpaper)
fi

# Set the wallpaper
if [ -f "$WALLPAPER" ]; then
    swww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-step "$TRANSITION_STEP" \
        --transition-fps 60 \
        --transition-duration "$TRANSITION_DURATION"
else
    echo "Error: Wallpaper not found!"
    exit 1
fi
