#!/bin/bash
# Claude Code status line.
# Approximates the user's Starship prompt (~/.config/starship.toml):
# gray directory + username, extended here with git branch/dirty status,
# the active model name, context window usage, and Claude.ai rate-limit
# usage (5-hour session + 7-day weekly windows, colored dim/yellow/red as
# usage climbs).
#
# Reads the status line JSON payload from stdin (see Claude Code docs).

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
five_hour_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- Rate-limit color: dim by default, yellow >=70%, red >=90% ---
# (used_percentage is a float; compare via awk, not bash's integer-only [ -gt ])
rl_color() {
    local pct="$1"
    if awk -v p="$pct" 'BEGIN { exit !(p >= 90) }'; then
        printf '\033[2;31m'
    elif awk -v p="$pct" 'BEGIN { exit !(p >= 70) }'; then
        printf '\033[2;33m'
    else
        printf '\033[2m'
    fi
}

# --- Directory (dim, like starship's gray [directory] segment) ---
dir_display="${cwd/#$HOME/\~}"

# --- Git branch + dirty status (skip optional locks so we never block) ---
git_segment=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
            git_segment=" \033[2;33m${branch} *\033[0m"
        else
            git_segment=" \033[2;32m${branch}\033[0m"
        fi
    fi
fi

# --- Context window usage ---
ctx_segment=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    ctx_segment="  \033[2mctx:$(printf '%.0f' "$used_pct")%\033[0m"
fi

# --- Model name ---
model_segment=""
if [ -n "$model" ] && [ "$model" != "null" ]; then
    model_segment="  \033[2;36m${model}\033[0m"
fi

# --- Rate limits (5h session + 7d weekly; absent until first API response) ---
five_hour_segment=""
if [ -n "$five_hour_pct" ] && [ "$five_hour_pct" != "null" ]; then
    five_hour_segment="  $(rl_color "$five_hour_pct")5h:$(printf '%.0f' "$five_hour_pct")%\033[0m"
fi

seven_day_segment=""
if [ -n "$seven_day_pct" ] && [ "$seven_day_pct" != "null" ]; then
    seven_day_segment="  $(rl_color "$seven_day_pct")7d:$(printf '%.0f' "$seven_day_pct")%\033[0m"
fi

printf "\033[2;37m%s\033[0m%b%b%b%b%b\n" "$dir_display" "$git_segment" "$model_segment" "$ctx_segment" "$five_hour_segment" "$seven_day_segment"
