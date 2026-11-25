{ inputs, user, ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    ../../nixos/base.nix
    ../../nixos/desktop.nix
    ../../nixos/apps.nix
    ../../nixos/audio.nix
  ];

  networking.hostName = "zbook";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs user; };
    users.${user.name} = import ../../home;
  };

  # `nix build .#nixosConfigurations.zbook.config.system.build.vm` for a test run.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 6;
      diskSize = 20480;
      # home-manager links into ~/dotfiles; give the VM this checkout there.
      sharedDirectories.dotfiles = {
        source = "/home/m19182/dotfiles-nixos";
        target = "/home/m19182/dotfiles";
      };
      # Software-rendered so it runs anywhere; view it with a VNC client on :5905.
      qemu.options = [
        "-vga none"
        "-device virtio-vga"
        "-display vnc=127.0.0.1:5"
      ];
    };
  };

  # Don't bump after install: it pins stateful defaults, not the package versions.
  system.stateVersion = "26.11";
}
