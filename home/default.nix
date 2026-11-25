{
  config,
  inputs,
  pkgs,
  user,
  ...
}:
let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # Live links into the repo: edits apply without a rebuild.
  link = path: config.lib.file.mkOutOfStoreSymlink "${user.dotfiles}/${path}";
in
{
  imports = [
    ./shell.nix
    ./desktop.nix
    ./webapps.nix
  ];

  home = {
    username = user.name;
    homeDirectory = "/home/${user.name}";
    stateVersion = "26.11";

    packages = with pkgs; [
      # CLI basics
      eza
      bat
      fd
      ripgrep
      fzf
      jq
      yq-go
      btop
      fastfetch
      tldr
      dust
      duf
      _7zz
      unzip
      wget
      inetutils
      whois
      socat
      tree
      man-pages
      gum
      imagemagick
      ffmpeg
      yt-dlp
      tesseract
      libqalculate
      qrencode
      zbar
      ddcutil

      # Dev
      neovim
      tmux
      gcc
      gnumake
      pkg-config
      gh
      docker-compose
      docker-buildx
      awscli2
      ssm-session-manager-plugin
      terraform
      vscode
      code-cursor
      zed-editor
      asciinema
      tree-sitter
      nil
      nixfmt
      nvd
      nix-output-monitor

      # Coding agents, updated daily by numtide.
      agents.claude-code
      agents.codex
      agents.opencode
      agents.amp
      agents.cursor-agent
      agents.pi
      agents.t3code

      # Terminals
      ghostty

      # Browsers
      google-chrome
      chromium
      firefox

      # Communication
      slack
      signal-desktop
      telegram-desktop
      discord

      # AI apps
      agents.claude-desktop
      chatgpt
      lmstudio

      # Media & office
      mpv
      imv
      obs-studio
      kdePackages.kdenlive
      spotify
      libreoffice
      calibre
      obsidian
      pinta
      kdePackages.okular
      nautilus
      sushi
      file-roller
      gnome-disk-utility

      # Audio production
      bitwig-studio
      vcv-rack
      yabridge
      yabridgectl
      wineWow64Packages.stagingFull

      # Network & security
      rustdesk
      freerdp
      networkmanagerapplet
      trezor-suite

      # Finance
      beancount
    ];

    sessionVariables = {
      BROWSER = "google-chrome-stable";
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/go/bin"
      "$HOME/.lmstudio/bin"
    ];
  };

  # App configs stay as plain files in the repo.
  # Per-file links: home-manager also writes ~/.config/hypr/hypridle.conf.
  xdg.configFile = {
    "hypr/hyprland.lua".source = link ".config/hypr/hyprland.lua";
    "hypr/lib.lua".source = link ".config/hypr/lib.lua";
    "hypr/defaults.lua".source = link ".config/hypr/defaults.lua";
    "hypr/monitors.lua".source = link ".config/hypr/monitors.lua";
    "hypr/input.lua".source = link ".config/hypr/input.lua";
    "hypr/looknfeel.lua".source = link ".config/hypr/looknfeel.lua";
    "hypr/windows.lua".source = link ".config/hypr/windows.lua";
    "hypr/autostart.lua".source = link ".config/hypr/autostart.lua";
    "hypr/bindings.lua".source = link ".config/hypr/bindings.lua";
    "ghostty/config".source = link ".config/ghostty/config";
    "tmux/tmux.conf".source = link ".config/tmux/tmux.conf";
    "git/config".source = link ".config/git/config";
    "starship.toml".source = link ".config/starship.toml";
    "mise/config.toml".source = link ".config/mise/config.toml";
    "nvim".source = link ".config/nvim";
  };

  home.file.".local/bin/linkwarden-add".source = link "bin/linkwarden-add";

  programs = {
    home-manager.enable = true;
    zoxide.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    mise = {
      enable = true;
      enableBashIntegration = true;
    };
  };

  services = {
    syncthing.enable = true;
    udiskie = {
      enable = true;
      automount = true;
      notify = false;
      tray = "never";
    };
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };
}
