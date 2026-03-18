# Dotfiles

Personal configuration files for Hyprland-based Arch setup.

## Installation

```bash
# Clone the repository
git clone <repo-url> ~/dotfiles
cd ~/dotfiles

# Create symlinks (backup existing configs first!)
stow -t ~ .
```

## What's Included

### Hyprland (Window Manager)
- `hypr/monitors.conf` - Display configuration 
- `hypr/bindings.conf` - Custom keybindings for apps
- `hypr/looknfeel.conf` - Window appearance
- `hypr/input.conf` - Spanish keyboard layout, touchpad settings

### Waybar (Status Bar)
- `waybar/config.jsonc` - Module layout
- `waybar/style.css` - Minimal styling

### Terminals
- `kitty/kitty.conf` - Kitty terminal config
- `ghostty/config` - Ghostty terminal config

### Shell & Tools
- `starship.toml` - Shell prompt with icons
- `tmux/tmux.conf` - Tmux with custom keybindings
- `git/config` - Git aliases and settings

### Omarchy Customizations
- `omarchy/themes/custom-bg/` - Custom theme with earthy colors

## Laptop-Specific Settings

This config is optimized for a laptop with:
- 1.25x display scaling
- Spanish keyboard layout
- Natural touchpad scrolling
- Custom app keybindings (Spotify, Signal, Obsidian, etc.)
