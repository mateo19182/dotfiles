#!/usr/bin/env bash
# Link personal configuration onto an existing Omarchy installation.
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

configs=(
    hypr/hyprland.lua hypr/monitors.lua hypr/input.lua
    hypr/bindings.lua hypr/looknfeel.lua hypr/windows.lua
    omarchy/plugins/m19182.agents
    omarchy/plugins/m19182.vpn
    omarchy/plugins/m19182.lock
    omarchy/shell.json
    ghostty/config tmux/tmux.conf git/config starship.toml
    omarchy/themes/custom-bg/colors.toml
    'omarchy/themes/custom-bg/backgrounds/image (1).png'
)

# The custom lock plugin needs Omarchy's packaged password PAM helper.
if [[ ! -f /etc/pam.d/omarchy-lock-password ]]; then
    printf "Missing Omarchy lock PAM helper; install a compatible Omarchy version first.\n" >&2
    exit 1
fi

# Check the entire source set before touching any destination.
for config in "${configs[@]}"; do
    if [[ ! -e "$DOTFILES_DIR/.config/$config" ]]; then
        printf 'Missing source: %s\n' "$DOTFILES_DIR/.config/$config" >&2
        exit 1
    fi
done

for config in "${configs[@]}"; do
    src="$DOTFILES_DIR/.config/$config"
    dest="$CONFIG_DIR/$config"
    if [[ -L "$dest" && "$(readlink -- "$dest")" == "$src" ]]; then
        printf 'Already linked: %s\n' "$dest"
        continue
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    # Preserve files, directories and existing links, including broken links.
    if [[ -e "$dest" || -L "$dest" ]]; then
        backup="$dest.backup.$(date +%s%N)"
        mv -- "$dest" "$backup"
        printf 'Backed up: %s\n' "$backup"
    fi
    ln -s -- "$src" "$dest"
    printf 'Linked: %s\n' "$dest"
done

printf '\nInstallation complete. Existing settings were backed up.\n'
printf 'On your desktop, validate Hyprland: hyprctl reload && hyprctl configerrors\n'
printf 'Reload terminal settings: omarchy restart terminal\n'
printf 'Omarchy shell settings reload automatically.\n'
