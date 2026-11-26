# Installing on the ZBook

This wipes `/dev/nvme0n1`.

## 1. Before, on the old system

Push any repo work you care about, then put keys, tokens and untracked `.env` files into a KeePass
file in `~/Documents/misc` (synced to the server by Syncthing):

```bash
git -C ~/dotfiles show origin/nixos:bin/pre-install-vault > /tmp/pre-install-vault
uv run --script /tmp/pre-install-vault
```

Wait until Syncthing shows everything synced to `m19182-server`.

Write the NixOS **unstable minimal** ISO to a USB stick:
`sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`
(find the stick with `lsblk`; the PortableSSD is `sda`, so the stick is usually `sdb`). Unplug the SSD until first boot.

## 2. Install

Boot the USB (F9 for the HP boot menu):

```bash
sudo -i
nmcli device wifi connect "<ssid>" password "<password>"
git clone -b nixos https://github.com/mateo19182/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/bin/install-from-iso
reboot
```

It asks you to type `WIPE`, then the disk password, then your login password.

## 3. First boot

The disk password unlocks and logs you into Hyprland. Open a terminal (Super+Return), run `claude`
(log in), and say: **follow ~/dotfiles/FIRST-BOOT.md**. It does the rest and asks you when it needs you.

## If something goes wrong

- Bad update: pick the previous generation in the boot menu.
- Won't boot: from the USB, `cryptsetup open /dev/nvme0n1p2 root`, mount `@` on `/mnt`, `@nix` on `/mnt/nix`,
  `@home` on `/mnt/home`, `/dev/nvme0n1p1` on `/mnt/boot`, then `nixos-install --flake /mnt/home/m19182/dotfiles#zbook`.
