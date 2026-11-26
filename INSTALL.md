# Installing on the ZBook

This wipes `/dev/nvme0n1`.

## 1. Before, on the old system

Push any repo work you care about, then:

```bash
git -C ~/dotfiles show origin/nixos:bin/pre-install-backup > /tmp/pre-install-backup
bash /tmp/pre-install-backup /run/media/m19182/PortableSSD
```

It packs into `zbook-backup.tar` on the disk: `~/Work` (without `node_modules`, venvs, `target/`), Documents, Music, Pictures, Bitwig Studio,
`.ssh`, `.gnupg`, `.aws`, `.claude`, `.codex`, the AWS VPN profile and the Linkwarden config. It also saves
the Datadog keys to `~/.config/secrets.env`, the Beszel token, and the Wi-Fi/VPN connections. Anything else
(e.g. `~/Downloads`) copy by hand if you want it.

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

The disk password unlocks and logs you into Hyprland. In a terminal (Super+Return):

```bash
tar -xpf /run/media/m19182/PortableSSD/zbook-backup.tar -C ~
sudo cp -a ~/.local/share/pre-install/system-connections/. /etc/NetworkManager/system-connections/
sudo chmod 600 /etc/NetworkManager/system-connections/* && sudo nmcli connection reload
sudo install -Dm600 ~/.local/share/pre-install/beszel-agent.env /etc/beszel/agent.env
sudo systemctl restart beszel-agent
mise install
sudo tailscale up
mullvad account login
```

Then:

- AWS VPN Client: File → Manage Profiles → Add `~/.config/aws-vpn-client/zepo-aws.ovpn`, connect once.
- Noctalia: Settings → Bar, add Headroom, VPN Manager and Tailnet.
- `hex status` should show the model ready; test F9.
- `cd ~/dotfiles && git checkout master && git merge nixos && git push`

## If something goes wrong

- Bad update: pick the previous generation in the boot menu.
- Won't boot: from the USB, `cryptsetup open /dev/nvme0n1p2 root`, mount `@` on `/mnt`, `@nix` on `/mnt/nix`,
  `@home` on `/mnt/home`, `/dev/nvme0n1p1` on `/mnt/boot`, then `nixos-install --flake /mnt/home/m19182/dotfiles#zbook`.
