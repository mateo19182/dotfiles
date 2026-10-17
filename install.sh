#!/usr/bin/env bash
# Link this repository's configuration into $HOME.
#
#   ./install.sh [--dry-run] <profile>...
#
# Profiles:
#   omarchy   Hyprland, Omarchy shell and plugins, ghostty, tmux, git, starship,
#             custom theme. Needs an existing Omarchy installation.
#   agents    Curated agent skills into every skill directory that exists,
#             plus the Claude Code status line script.
#
# Every link is created individually. Existing files, directories and links are
# backed up; a link that already points at this repository is left alone, so
# re-running is safe.
set -euo pipefail

DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY_RUN=0

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

profiles=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage 0 ;;
        omarchy|agents) profiles+=("$arg") ;;
        *) printf 'Unknown argument: %s\n\n' "$arg" >&2; usage ;;
    esac
done
[[ ${#profiles[@]} -gt 0 ]] || usage

has_profile() { local p; for p in "${profiles[@]}"; do [[ $p == "$1" ]] && return 0; done; return 1; }

# Paths under .config/ in this repository, linked into $XDG_CONFIG_HOME.
configs=(
    hypr/hyprland.lua hypr/monitors.lua hypr/input.lua
    hypr/bindings.lua hypr/looknfeel.lua hypr/windows.lua
    omarchy/plugins/m19182.agents
    omarchy/plugins/m19182.vpn
    omarchy/plugins/m19182.lock
    omarchy/shell.json
    ghostty/config tmux/tmux.conf git/config starship.toml
    omarchy/themes/custom-bg/colors.toml
    'omarchy/themes/custom-bg/backgrounds/image (1).png'
)

# Skill directories the agents profile links into. Only existing directories
# are used, so an agent that is not installed is skipped. Override with
# SKILL_DIRS="dir1:dir2" to target others, such as ~/.cursor/skills.
default_skill_dirs="$HOME/.claude/skills:$HOME/.agents/skills"
IFS=: read -r -a skill_dirs <<< "${SKILL_DIRS:-$default_skill_dirs}"

run() {
    if (( DRY_RUN )); then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}

# link SRC DEST: back up whatever is at DEST, then symlink SRC there.
# With BACKUP_DIR set, the backup goes there instead of beside DEST.
link() {
    local src="$1" dest="$2"
    if [[ -L "$dest" && "$(readlink -- "$dest")" == "$src" ]]; then
        printf 'Already linked: %s\n' "$dest"
        return
    fi
    run mkdir -p -- "$(dirname -- "$dest")"
    if [[ -e "$dest" || -L "$dest" ]]; then
        local backup
        if [[ -n "${BACKUP_DIR:-}" ]]; then
            run mkdir -p -- "$BACKUP_DIR"
            backup="$BACKUP_DIR/$(basename -- "$dest")"
        else
            backup="$dest.backup.$(date +%s%N)"
        fi
        run mv -- "$dest" "$backup"
        printf 'Backed up: %s\n' "$backup"
    fi
    run ln -s -- "$src" "$dest"
    printf 'Linked: %s -> %s\n' "$dest" "$src"
}

# --- omarchy ---------------------------------------------------------------

if has_profile omarchy; then
    printf '\n== omarchy\n'
    # The custom lock plugin needs Omarchy's packaged password PAM helper.
    if [[ ! -f /etc/pam.d/omarchy-lock-password ]]; then
        printf 'Missing Omarchy lock PAM helper; install a compatible Omarchy version first.\n' >&2
        exit 1
    fi
    # Check the entire source set before touching any destination.
    for config in "${configs[@]}"; do
        if [[ ! -e "$DOTFILES_DIR/.config/$config" ]]; then
            printf 'Missing source: %s\n' "$DOTFILES_DIR/.config/$config" >&2
            exit 1
        fi
    done
    for config in "${configs[@]}"; do
        link "$DOTFILES_DIR/.config/$config" "$CONFIG_DIR/$config"
    done
fi

# --- agents ----------------------------------------------------------------

if has_profile agents; then
    printf '\n== agents\n'
    link "$DOTFILES_DIR/agents/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
    mapfile -t skills < <(find "$DOTFILES_DIR/agents/skills" -mindepth 2 -maxdepth 2 -type d | sort)
    # Replaced skill copies go to a state directory, not beside the link: an
    # agent would otherwise load <skill>.backup.<ts>/SKILL.md as a second skill.
    backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/$(date +%Y%m%d-%H%M%S)"
    for dir in "${skill_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            printf 'Skipping %s (agent not installed)\n' "$dir"
            continue
        fi
        BACKUP_DIR="$backup_root/$(basename -- "$(dirname -- "$dir")")"
        for skill in "${skills[@]}"; do
            link "$skill" "$dir/$(basename -- "$skill")"
        done
        BACKUP_DIR=""
    done
fi

# --- next steps ------------------------------------------------------------

printf '\nDone. Replaced files were backed up beside their originals; replaced skills under %s.\n' \
    "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups"
if has_profile omarchy; then
    printf 'Validate Hyprland: hyprctl reload && hyprctl configerrors\n'
    printf 'Reload terminal settings: omarchy restart terminal\n'
    printf 'Omarchy shell settings reload automatically.\n'
fi
