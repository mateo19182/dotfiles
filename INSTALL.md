# Installing on the ZBook

This wipes `/dev/nvme0n1`. Three scripts in `bin/` do the work.

## 1. Before, on the old system

```bash
git -C ~/dotfiles fetch && git -C ~/dotfiles show origin/nixos:bin/pre-install-backup > /tmp/pre-install-backup
bash /tmp/pre-install-backup /run/media/m19182/<disk>/zbook      # or server:/path/zbook
```

It moves the Datadog keys from `~/.bashrc` into `~/.config/secrets.env`, saves the Beszel token and the
NetworkManager connections (Wi-Fi, AirVPN), lists repos with uncommitted/unpushed work, and rsyncs `$HOME`
without caches, Steam games, LM Studio models, `node_modules`, venvs and build dirs (~200 GB today).
Re-run it right before installing so the copy is fresh.

Also: write a NixOS **unstable minimal** ISO to a USB stick
(https://nixos.org/download, "Minimal ISO image", then `sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`).

## 2. Install

Boot the USB (F9 for the HP boot menu), then:

```bash
sudo -i
nmcli device wifi connect "<ssid>" password "<password>"
git clone -b nixos https://github.com/mateo19182/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/bin/install-from-iso
reboot
```

It asks you to type `WIPE`, then the new disk password, then your login password.
Hex and AutoFirma compile during the install (10-20 min); the rest downloads.

## 3. First boot

The disk password unlocks and logs you straight into Hyprland. Open a terminal (Super+Return):

```bash
~/dotfiles/bin/post-install /run/media/m19182/<disk>/zbook      # same DEST as step 1
```

It restores your files (leaving the Nix-managed configs alone), the network connections and the Beszel
token, parks the old `~/.local/bin` in `~/.local/share/pre-install/old-local-bin`, runs `mise install` and
`tailscale up`. Then by hand:

- `mullvad account login`
- AWS VPN Client: File → Manage Profiles → Add `~/.config/aws-vpn-client/zepo-aws.ovpn`, connect once to test SSO.
- Noctalia: Settings → Bar, add Headroom, VPN Manager and Tailnet; turn on night light.
- Hex: `hex status` should show the model as ready; test F9.
- Merge the branch: `cd ~/dotfiles && git checkout master && git merge nixos && git push`.

## If something goes wrong

- Bad update: pick the previous generation in the boot menu.
- Won't boot at all: boot the USB, `cryptsetup open /dev/nvme0n1p2 root`, mount (`mount -o subvol=@ /dev/mapper/root /mnt`, plus `@nix` on `/mnt/nix`, `@home` on `/mnt/home`, `/dev/nvme0n1p1` on `/mnt/boot`), fix, `nixos-install --flake /mnt/home/m19182/dotfiles#zbook`.
- Hibernate: the swapfile is at `/.swapvol/swapfile`. Add `boot.resumeDevice = "/dev/mapper/root"` and `boot.kernelParams = [ "resume_offset=<n>" ]` with `<n>` from `sudo btrfs inspect-internal map-swapfile -r /.swapvol/swapfile`.
