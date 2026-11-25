# Installing on the ZBook

This wipes `/dev/nvme0n1`. Do the backup first.

## 1. Before, on the old system

- Back up your home to an external disk, minus caches:
  `rsync -aHAX --info=progress2 --exclude .cache --exclude .local/share/Steam --exclude .nix-portable ~/ /run/media/$USER/<disk>/home-backup/`
- Make sure these are in it: `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config/linkwarden`, `~/.claude`, `~/.codex`, `~/.config/server-backup`, `~/Work`.
- Move secrets out of `~/.bashrc` into `~/.config/secrets.env` (one `KEY=value` per line). The new bash sources it.
- Copy the NetworkManager connections (Wi-Fi, AirVPN WireGuard): `sudo cp -a /etc/NetworkManager/system-connections /run/media/$USER/<disk>/`
- Get this repo onto the installer: push the `nixos` branch, or copy `~/dotfiles` to the USB disk.

## 2. Install

Boot the NixOS unstable minimal ISO, then:

```bash
sudo -i
nmcli device wifi connect "<ssid>" password "<password>"
git clone -b nixos https://github.com/mateo19182/dotfiles.git /tmp/dotfiles   # or copy from USB

# Compare with the hand-written hosts/zbook/hardware.nix; add anything missing.
nixos-generate-config --no-filesystems --show-hardware-config

# Partition, encrypt (asks for the disk password) and mount.
nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
  --mode destroy,format,mount /tmp/dotfiles/hosts/zbook/disko.nix

nixos-install --flake /tmp/dotfiles#zbook --no-root-passwd

# Put the repo where home-manager's links expect it.
cp -a /tmp/dotfiles /mnt/home/m19182/dotfiles
chown -R 1000:100 /mnt/home/m19182/dotfiles
reboot
```

## 3. First boot

The disk password unlocks and logs you straight into Hyprland.

```bash
passwd                                   # replace "changeme"
rsync -a /run/media/m19182/<disk>/home-backup/ ~/   # restore data
sudo cp -a /run/media/m19182/<disk>/system-connections/. /etc/NetworkManager/system-connections/
sudo nmcli connection reload
sudo tailscale up
mullvad account login
mise install                             # node, go, rust, python, canonfig...

# Beszel agent token (from the hub, or the old /etc/systemd/system/beszel-agent.service).
sudo install -Dm600 /dev/stdin /etc/beszel/agent.env <<< "TOKEN=<token>"
sudo systemctl restart beszel-agent
```

AWS VPN Client: open it, File → Manage Profiles → Add, and pick `~/.config/aws-vpn-client/zepo-aws.ovpn`.

Then:

- Noctalia: Settings → Bar → add the Headroom, VPN Manager and Tailnet widgets, and turn on night light.
- Hex downloads its model on first start; check `hex status`.
- Hibernate: the swapfile is at `/.swapvol/swapfile`. To hibernate, add `boot.resumeDevice = "/dev/mapper/root"` and `boot.kernelParams = [ "resume_offset=<n>" ]` with `<n>` from `sudo btrfs inspect-internal map-swapfile -r /.swapvol/swapfile`.
