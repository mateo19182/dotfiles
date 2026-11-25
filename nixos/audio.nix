# PipeWire plus what Bitwig/yabridge need for low-latency work.
{ pkgs, user, ... }:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Equivalent of Arch's realtime-privileges group.
  users.groups.realtime = { };
  users.users.${user.name}.extraGroups = [ "realtime" ];
  security.pam.loginLimits = [
    {
      domain = "@realtime";
      type = "-";
      item = "rtprio";
      value = "98";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];
  services.udev.extraRules = ''
    KERNEL=="rtc0", GROUP="realtime"
    KERNEL=="hpet", GROUP="realtime"
    DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="realtime", MODE="0660"
  '';

  environment.systemPackages = with pkgs; [
    pavucontrol
    wiremix
    pamixer
    playerctl
  ];
}
