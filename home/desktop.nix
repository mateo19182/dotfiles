{
  inputs,
  pkgs,
  user,
  ...
}:
let
  # Starts a recording, or stops the running one.
  screenrecord = pkgs.writeShellApplication {
    name = "screenrecord";
    runtimeInputs = with pkgs; [
      gpu-screen-recorder
      libnotify
      procps
    ];
    text = ''
      if pkill -SIGINT -f '^gpu-screen-recorder'; then
        notify-send -u low "Recording saved"
        exit 0
      fi
      dir="''${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasts"
      mkdir -p "$dir"
      notify-send -u low "Recording started" "Press Alt+Print again to stop"
      exec gpu-screen-recorder -w portal -f 60 -a default_output \
        -o "$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    '';
  };
in
{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.hex.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    screenrecord
    hyprpicker
    wl-clipboard
    wtype
    brightnessctl
    libnotify
    adwaita-icon-theme
    yaru-theme
  ];

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
      theme.mode = "dark";
      wallpaper = {
        enabled = true;
        default.path = "${user.dotfiles}/wallpapers/custom-bg.png";
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

  programs.hex = {
    enable = true;
    autostart = true;
    installModel = true;
    # Parakeet v3 handles Spanish and English and detects which one you speak.
    model = "parakeet_v3";
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "noctalia msg session lock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        inhibit_sleep = 3;
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Yaru-blue";
      package = pkgs.yaru-theme;
    };
    gtk4.theme = null;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "application/pdf" = "org.kde.okular.desktop";
      "image/png" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "inode/directory" = "org.gnome.Nautilus.desktop";
    };
  };
}
