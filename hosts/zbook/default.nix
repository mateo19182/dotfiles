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

  # Mount @home in the initrd, before activation creates ~ (else it lands on @, hidden by the mount).
  fileSystems."/home".neededForBoot = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs user; };
    users.${user.name} = import ../../home;
  };

  # Test run: `nix build .#nixosConfigurations.zbook.config.system.build.vm && ./result/bin/run-zbook-vm`,
  # then a VNC viewer on localhost:5905 (user m19182, password changeme).
  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;
    cores = 6;
    diskSize = 20480;
    sharedDirectories.dotfiles = {
      source = "/home/m19182/dotfiles";
      target = "/home/m19182/dotfiles";
    };
    qemu.options = [
      "-vga none"
      "-device virtio-vga"
      "-display vnc=127.0.0.1:5"
    ];
  };

  # Don't bump after install: it pins stateful defaults, not the package versions.
  system.stateVersion = "26.11";
}
