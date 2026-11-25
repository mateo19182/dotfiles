# Dotfiles

NixOS + Hyprland + Noctalia for the ZBook (`zbook`), plus the curated agent skills and the server's backup tool.

## Layout

| Path | What |
| --- | --- |
| `flake.nix` | Inputs (nixos-unstable, home-manager, Noctalia, llm-agents, Hex, ...) and the `zbook` system |
| `hosts/zbook/` | Hardware, disk layout (disko: LUKS + btrfs), VM test settings |
| `nixos/` | System: boot, users, desktop session, audio, services, system apps |
| `home/` | User: packages, shell, Noctalia, Hex, idle, theme, web apps |
| `.config/` | Plain config files, linked live into `~/.config` (no rebuild needed to edit) |
| `wallpapers/`, `webapps/icons/`, `bin/` | Assets and small scripts |
| `agents/`, `install.sh` | Agent skills (until canonfig takes over) |
| `server-backup/` | The server's restic backup tool (`./install.sh server-backup` on the server) |

## Everyday use

```bash
nh os switch            # apply changes (alias: rebuild)
nh os switch --update   # update all inputs, then apply (alias: update)
nix flake update llm-agents && nh os switch   # just bump the coding agents
```

Every switch is a new boot entry; pick an older one in the boot menu to roll back, or `sudo nixos-rebuild switch --rollback`.
The laptop keeps no backups of its own: important folders sync to the server with Syncthing.

Hyprland, ghostty, tmux, git, starship, mise and nvim configs live in `.config/` and are symlinked, so edit them in place and `hyprctl reload`.
Validate Hyprland edits with `hyprctl configerrors`.

## Test in a VM

```bash
nix build .#nixosConfigurations.zbook.config.system.build.vm
./result/bin/run-zbook-vm
```

User `m19182`, password `changeme`.

## Install

See [INSTALL.md](INSTALL.md).
