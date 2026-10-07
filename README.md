# Dotfiles

Personal configuration for an existing Omarchy installation with Lua-based Hyprland configuration and the Omarchy shell.

## Installation

```bash
git clone https://github.com/mateo19182/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer creates individual symlinks in `${XDG_CONFIG_HOME:-$HOME/.config}`. It checks all source files first and backs up existing files or links next to their original locations. Running it again leaves correct links alone. Keep this repository in place while using its symlinks.

Install Omarchy and the relevant applications first; this repository does not install packages. It relies on Omarchy's packaged defaults, plugins, and theme state. It does not reset your configuration or restart applications.

After installing on your desktop:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart terminal
```

Omarchy shell settings reload automatically. Restore an individual setting by removing its symlink and renaming the corresponding `.backup.*` file to the original name.

## Included configuration

- `hypr/*.lua`: Omarchy bootstrap and overrides for monitors, input, keybindings, appearance, and window rules.
- `omarchy/shell.json`: shell layout, widgets, and idle settings.
- `omarchy/plugins/m19182.*`: custom agent usage, VPN, and lock plugins.
- `ghostty/config`: terminal font, appearance, scrolling, and keybindings.
- `tmux/tmux.conf`: multiplexer behavior and keybindings.
- `git/config` and `starship.toml`: personal Git settings and shell prompt.
- `omarchy/themes/custom-bg/`: custom colors and background image.

The previous Hyprland `.conf` files and Waybar configuration have been replaced by the current Lua configuration and Omarchy shell. Kitty configuration is not included.

## Personal settings

Review the configuration before using it on another machine, especially monitor scaling, keyboard layout, application bindings, fonts, and Git identity. Current monitor configuration uses preferred modes, automatic placement, and scale 1. Ghostty uses Liberation Mono at size 9. This is a snapshot of personal preferences, rather than a hardware-independent default.

Credentials, runtime state, and local databases do not belong in this repository.

## Custom shell plugins

These plugin snapshots require a compatible current Omarchy/Quickshell installation. The agent widget uses Omarchy usage collectors; the VPN widget uses NetworkManager (`nmcli`) and existing saved profiles. VPN credentials and profiles are not stored here. The lock plugin requires `/etc/pam.d/omarchy-lock-password`; the installer checks this before linking any files. Fingerprint authentication is optional and depends on its separately installed PAM configuration.
