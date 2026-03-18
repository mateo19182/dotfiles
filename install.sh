#!/bin/bash
# Dotfiles installation script

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR..."

# Function to create symlink with backup
link_file() {
    local src="$1"
    local dest="$2"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"
    
    # Backup existing file if it exists and isn't already a symlink
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "Backing up $dest to $dest.backup.$(date +%s)"
        mv "$dest" "$dest.backup.$(date +%s)"
    fi
    
    # Remove existing symlink
    if [ -L "$dest" ]; then
        rm "$dest"
    fi
    
    # Create symlink
    ln -s "$src" "$dest"
    echo "Linked: $dest -> $src"
}

# Hyprland configs
link_file "$DOTFILES_DIR/.config/hypr/monitors.conf" "$HOME/.config/hypr/monitors.conf"
link_file "$DOTFILES_DIR/.config/hypr/bindings.conf" "$HOME/.config/hypr/bindings.conf"
link_file "$DOTFILES_DIR/.config/hypr/looknfeel.conf" "$HOME/.config/hypr/looknfeel.conf"
link_file "$DOTFILES_DIR/.config/hypr/input.conf" "$HOME/.config/hypr/input.conf"

# Waybar
link_file "$DOTFILES_DIR/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link_file "$DOTFILES_DIR/.config/waybar/style.css" "$HOME/.config/waybar/style.css"

# Terminals
link_file "$DOTFILES_DIR/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
link_file "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"

# Shell & tools
link_file "$DOTFILES_DIR/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
link_file "$DOTFILES_DIR/.config/git/config" "$HOME/.config/git/config"
link_file "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Custom theme
mkdir -p "$HOME/.config/omarchy/themes/custom-bg/backgrounds"
link_file "$DOTFILES_DIR/.config/omarchy/themes/custom-bg/colors.toml" "$HOME/.config/omarchy/themes/custom-bg/colors.toml"
if [ -f "$DOTFILES_DIR/.config/omarchy/themes/custom-bg/backgrounds/image (1).png" ]; then
    link_file "$DOTFILES_DIR/.config/omarchy/themes/custom-bg/backgrounds/image (1).png" \
              "$HOME/.config/omarchy/themes/custom-bg/backgrounds/image (1).png"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Restart Waybar: omarchy-restart-waybar"
echo "2. Restart terminal: omarchy-restart-terminal"
echo "3. Hyprland configs will auto-reload"
