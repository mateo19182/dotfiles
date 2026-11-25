{
  inputs,
  pkgs,
  user,
  ...
}:
{
  imports = [ inputs.noctalia.nixosModules.default ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Disk password at boot, then straight into Hyprland (like Omarchy).
  # Logging out drops to tuigreet instead of looping back in.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "uwsm start -- hyprland-uwsm.desktop";
        user = user.name;
      };
      default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start -- hyprland-uwsm.desktop'";
    };
  };

  # Also turns on NetworkManager, Bluetooth, UPower and power-profiles-daemon.
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
  };

  programs.gpu-screen-recorder.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Noctalia's lock screen authenticates against the stock `login` PAM service.
  security.polkit.enable = true;

  services = {
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;
    blueman.enable = false;

    printing = {
      enable = true;
      drivers = [ pkgs.hplip ];
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # Suspend on lid close; Noctalia locks before sleep.
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandlePowerKey = "ignore";
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      ia-writer-duospace
      font-awesome
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "JetBrainsMono Nerd Font" ];
      serif = [ "Noto Serif" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    TERMINAL = "ghostty";
    EDITOR = "code --wait";
  };
}
