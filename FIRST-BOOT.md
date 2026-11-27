# First boot on the new ZBook (instructions for a coding agent)

NixOS was just installed from this repo (`~/dotfiles`). Finish the setup below, in order.
Run each step, check it worked, and stop to ask the user when a step says **user**.
Ask before every `sudo` command, and before any push. Skip a step that's already done.

1. **Update.** Run `update` (`nh os switch --update`). If the build fails, show the error and stop.
2. **Syncthing.** Get this laptop's device ID: `syncthing cli show system | grep myID`.
   **User:** accept that device on `m19182-server`'s Syncthing page and share the folders
   `misc`, `mymusic`, `obsidian` and `photoshard` with it. Then accept the folder shares locally
   (`http://127.0.0.1:8384`, or `syncthing cli`) at these paths:
   `misc` → `~/Documents/misc`, `mymusic` → `~/Music`, `obsidian` → `~/Documents/obsidian-19182`,
   `photoshard` → `~/Pictures/hard`. Wait until `~/Documents/misc/vault.kdbx` exists.
3. **Secrets.** Run `~/dotfiles/bin/vault-restore` (the vault has no master password).
   It restores `~/.ssh`, `~/.aws`, the AWS VPN profile, `~/.config/secrets.env` and the Beszel token.
   Then `sudo systemctl restart beszel-agent` and check `systemctl status beszel-agent` is active.
4. **Check SSH.** `ssh -T git@github.com` should greet `mateo19182`.
5. **Tools.** `mise install`.
6. **VPNs.** **User:** `sudo tailscale up` (opens a login link) and `mullvad account login`
   (asks for the account number).
7. **Repos.** **User:** say which repos to clone into `~/Work/{zepo,tribo,personal}`. Clone them with SSH URLs,
   then run `vault-restore` again so their `.env` files come back. It lists any that still wait for a folder.
8. **KeePassXC.** **User:** click Unlock (no password). The vault already shares its root group with apps
   (Secret Service). Check: `echo ok | secret-tool store --label=check check 1 && secret-tool lookup check 1 && secret-tool clear check 1` prints `ok`.
9. **Agent config.** canonfig Follower of `m19182-server` (README of the `agents-config` repo).
   `canonfig doctor --no-input`: credentials must pass (needs KeePassXC unlocked from step 8).
   On the server, revoke the old Omarchy laptop (`canonfig source revoke follower-6cd02c4f696e031f476bfa5e5e269b1b`;
   already gone if it ran `canonfig follower unenroll` before the wipe), then create an invitation:
   `canonfig source invite --endpoint https://m19182.tail5196fa.ts.net:17342 --output ~/canonfig-invite --expires 15m --group canonfig:secrets`.
   Copy it here with `scp` (never print it), then `canonfig follower enroll --stdin --name zbook < canonfig-invite`,
   delete the file on both machines, `canonfig sync --plan`, show it, `canonfig sync --apply` after a yes,
   and `canonfig schedule set daily@09:00`. Each agent signs in to Executor the first time it uses it.
10. **AWS VPN Client.** **User:** File → Manage Profiles → Add `~/.config/aws-vpn-client/zepo-aws.ovpn`,
   then connect once and finish the SSO login.
11. **Checks.** `hex status` (model ready), `systemctl --user --failed` and `systemctl --failed` (both empty).
    Report anything that isn't fine.
When done, give the user a short list: what's finished, and anything still for them.
