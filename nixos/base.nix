{ pkgs, user, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        user.name
      ];
      auto-optimise-store = true;
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    # Weekly cleanup; keeps two weeks of generations to roll back to.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
      timeout = 2;
    };
    # Graphical LUKS prompt instead of a text one.
    plymouth.enable = true;
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "splash"
    ];
    # Run aarch64 binaries/containers (was qemu-user-static-binfmt on Arch).
    binfmt.emulatedSystems = [ "aarch64-linux" ];
  };

  zramSwap.enable = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "es";

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.fullName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "docker"
      "dialout"
    ];
    # Set a real password with `passwd` on first boot.
    initialPassword = "changeme";
  };

  security.sudo.wheelNeedsPassword = true;

  services = {
    fwupd.enable = true;
    fstrim.enable = true;
    btrfs.autoScrub = {
      enable = true;
      fileSystems = [ "/" ];
    };
    locate = {
      enable = true;
      package = pkgs.plocate;
    };
  };

  # Lets prebuilt binaries (mise tools, downloaded CLIs, AppImages) find their libraries.
  programs.nix-ld.enable = true;

  # Better rebuild UX: `nh os switch`, diffs, rollback picker.
  programs.nh = {
    enable = true;
    flake = user.dotfiles;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    btrfs-progs
    pciutils
    usbutils
    inxi
  ];
}
