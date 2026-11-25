{ inputs, user, ... }:
let
  testVm = {
    memorySize = 8192;
    cores = 6;
    # home-manager links into ~/dotfiles; give the VM this checkout there.
    sharedDirectories.dotfiles = {
      source = "/home/m19182/dotfiles-nixos";
      target = "/home/m19182/dotfiles";
    };
    # Software-rendered so it runs anywhere.
    qemu.options = [
      "-vga none"
      "-device virtio-vga"
      "-display vnc=127.0.0.1:5"
    ];
  };
in
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

  # Test VMs: `.#...zbook.config.system.build.vm` (quick) or `.vmWithDisko` (real
  # LUKS + btrfs layout, disk password "disko"). View either over VNC on :5905.
  virtualisation.vmVariant.virtualisation = testVm // { diskSize = 20480; };
  virtualisation.vmVariantWithDisko.virtualisation = testVm // {
    # disko's variant redefines fileSystems; keep @home mounted early like the real one.
    fileSystems."/home".neededForBoot = true;
  };

  # Don't bump after install: it pins stateful defaults, not the package versions.
  system.stateVersion = "26.11";
}
