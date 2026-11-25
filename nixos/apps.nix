# System-level apps and services. Per-user apps live in home/.
{
  inputs,
  pkgs,
  user,
  ...
}:
{
  imports = [
    inputs.autofirma-nix.nixosModules.default
    inputs.awsvpnclient-nix.nixosModules.default
  ];

  # Work VPN. Import the profile (~/.config/aws-vpn-client/zepo-aws.ovpn) in the app.
  services.awsvpnclient.enable = true;

  # Reports to the Beszel hub on the server. The agent token stays out of git:
  # /etc/beszel/agent.env holds TOKEN=... (see INSTALL.md).
  services.beszel.agent = {
    enable = true;
    environment = {
      HUB_URL = "https://stats.m19182.dev";
      KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVvbKwkwbWkI9zjVPq6/Z1eod2nSkEXwFVaNZ7vG5iA";
      LISTEN = "45876";
    };
    environmentFile = "/etc/beszel/agent.env";
  };

  networking = {
    networkmanager = {
      enable = true;
      plugins = [ pkgs.networkmanager-openvpn ];
    };
    firewall = {
      enable = true;
      # LocalSend
      allowedTCPPorts = [ 53317 ];
      allowedUDPPorts = [ 53317 ];
      # Tailscale + Mullvad route asymmetrically.
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  services = {
    resolved.enable = true;
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
    mullvad-vpn = {
      enable = true;
      gui.enable = true;
    };
    flatpak.enable = true;
    trezord.enable = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    gamemode.enable = true;

    autofirma = {
      enable = true;
      firefoxIntegration.enable = true;
    };
    configuradorfnmt.enable = true;

    localsend.enable = true;
  };
}
