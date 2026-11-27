# First boot on the new ZBook (instructions for a coding agent)

NixOS was just installed from this repo (`~/dotfiles`, branch `nixos`). Finish the setup below, in order.
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
8. **KeePassXC.** **User:** click Unlock (no password), then Database → Database Settings → Secret Service
   → expose the root group, so apps can store passwords.
9. **Agent config.** `git clone git@github.com:mateo19182/agents-config.git ~/.canonfig`, then
   `canonfig doctor --no-input` (credentials must pass). **User:** run `canonfig secrets set huly-mcp-authorization`
   and paste `Bearer <Huly MCP token>` (hidden input). Then `canonfig sync --plan`, show the plan, and
   `canonfig sync --apply` after a yes. Each agent signs in to Executor the first time it uses it.
   If the server is already the canonfig Source, enroll as a Follower instead (see `~/.canonfig/README.md`).
10. **AWS VPN Client.** **User:** File → Manage Profiles → Add `~/.config/aws-vpn-client/zepo-aws.ovpn`,
   then connect once and finish the SSO login.
11. **Checks.** `hex status` (model ready), `systemctl --user --failed` and `systemctl --failed` (both empty).
    Report anything that isn't fine.
12. **Branch.** Ask the user, then: `git -C ~/dotfiles checkout master && git -C ~/dotfiles merge nixos`,
    and push only after a yes.

When done, give the user a short list: what's finished, and anything still for them.
