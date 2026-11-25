# Noctalia, styled like the Omarchy bar: flat, square, full width, no shadows or animations.
# Changes made in Noctalia's Settings window win over these (they go to
# ~/.local/state/noctalia/settings.toml); copy the ones you keep back here.
{
  config,
  inputs,
  pkgs,
  user,
  ...
}:
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Your own palettes: one JSON per file, picked in Settings → Appearance → Theme.
  xdg.configFile."noctalia/palettes".source =
    config.lib.file.mkOutOfStoreSymlink "${user.dotfiles}/.config/noctalia/palettes";

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    extraPackages = with pkgs; [
      gpu-screen-recorder
      networkmanager
      networkmanagerapplet
      tailscale
      libsecret
      xdg-utils
    ];

    settings = {
      shell = {
        # Its first-run wizard would reset the palette choices made here.
        setup_wizard_enabled = false;
        corner_radius_scale = 0;
        font_family = "JetBrainsMono Nerd Font";
        animation.enabled = false;
        panel = {
          shadow = false;
          border_width = 1.0;
          launcher_placement = "floating";
        };
        launcher.layout = "simple";
      };

      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "Custom-BG";
        # Recolor these apps whenever the palette changes.
        templates = {
          builtin_ids = [
            "ghostty"
            "gtk3"
            "gtk4"
            "hyprland"
            "btop"
          ];
          enable_community_templates = false;
        };
      };

      wallpaper = {
        enabled = true;
        default.path = "${user.dotfiles}/wallpapers/custom-bg.png";
        transition = [ "fade" ];
        transition_duration = 300;
      };

      bar.main = {
        position = "top";
        thickness = 26;
        radius = 0;
        margin_ends = 0;
        margin_edge = 0;
        padding = 10;
        widget_spacing = 10;
        shadow = false;
        compositor_blur = false;
        capsule = false;
        start = [
          "launcher"
          "workspaces"
        ];
        center = [ "clock" ];
        end = [
          "tray"
          "rylos/tailnet:bar"
          "ayagmar/headroom:usage"
          "andrewdems/vpn-manager:bar"
          "bluetooth"
          "network"
          "volume"
          "battery"
          "session"
        ];
      };

      widget = {
        launcher.glyph = "menu-2";
        clock = {
          format = "{:%A %H:%M}";
          tooltip_format = "{:%-d %B, W%V %Y}";
        };
        workspaces = {
          style = "minimal";
          labels_only_when_occupied = false;
        };
        network.show_label = false;
        battery.peek = true;
      };

      # Plugins pinned through flake.lock; `nix flake update` moves them.
      plugins = {
        auto_update = "none";
        source = [
          {
            name = "official";
            kind = "path";
            location = "${inputs.noctalia-official-plugins}";
            enabled = true;
          }
          {
            name = "community";
            kind = "path";
            location = "${inputs.noctalia-community-plugins}";
            enabled = true;
          }
        ];
        enabled = [
          "ayagmar/headroom"
          "andrewdems/vpn-manager"
          "rylos/tailnet"
        ];
      };
    };
  };
}
