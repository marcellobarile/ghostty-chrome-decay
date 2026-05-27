#!/usr/bin/env bash
# auto-theme.sh — switch Ghostty CRT phosphor shader based on time of day
# Run manually or let cron-setup.sh schedule it hourly.

# ─── CONFIGURATION ───────────────────────────────────────────────────
LIGHT_SHADER="crt-phosphor-paper.glsl"  # shader used during day (light)
DARK_SHADER="crt-phosphor-amber.glsl"   # shader used at night (dark)
LIGHT_THEME="phosphor-paper"             # Ghostty theme used during day
DARK_THEME="phosphor-amber"              # Ghostty theme used at night
LIGHT_START=7                            # hour (0-23) when light mode begins
DARK_START=19                            # hour (0-23) when dark mode begins
GHOSTTY_CONFIG="${GHOSTTY_CONFIG:-$HOME/.config/ghostty/config}"
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHADER_DIR="$SCRIPT_DIR/../shaders"
LINK="$SHADER_DIR/crt-phosphor-active.glsl"

hour=$((10#$(date +%H)))  # current hour, base-10 safe on macOS and Linux

if (( hour >= LIGHT_START && hour < DARK_START )); then
    target="$(cd "$SHADER_DIR" && pwd)/$LIGHT_SHADER"
    theme="$LIGHT_THEME"
else
    target="$(cd "$SHADER_DIR" && pwd)/$DARK_SHADER"
    theme="$DARK_THEME"
fi

if [[ ! -f "$target" ]]; then
    echo "auto-theme: shader not found: $target" >&2
    exit 1
fi

# ── shader symlink ────────────────────────────────────────────────────
current=$(readlink "$LINK" 2>/dev/null)

if [[ "$current" != "$target" ]]; then
    ln -sf "$target" "$LINK"
    echo "auto-theme: shader → $(basename "$target")"
else
    echo "auto-theme: shader unchanged ($(basename "$target"))"
fi

# ── theme line in Ghostty config ──────────────────────────────────────
# Shader sets phosphor look; theme sets the color palette. Keep them in sync.
if [[ ! -f "$GHOSTTY_CONFIG" ]]; then
    echo "auto-theme: config not found: $GHOSTTY_CONFIG" >&2
    exit 1
fi

current_theme=$(sed -n 's/^theme = //p' "$GHOSTTY_CONFIG")

if [[ "$current_theme" != "$theme" ]]; then
    # -i.bak is portable across BSD (macOS) and GNU sed
    sed -i.bak "s/^theme = .*/theme = $theme/" "$GHOSTTY_CONFIG" && rm -f "$GHOSTTY_CONFIG.bak"
    echo "auto-theme: theme → $theme"
else
    echo "auto-theme: theme unchanged ($theme)"
fi

# ── reload Ghostty ────────────────────────────────────────────────────
# Ghostty reloads its config (theme + custom-shader) on SIGUSR2. killall
# matches the process basename on both macOS (BSD) and Linux (procps), so it
# hits the app without touching MCP/helper procs that carry "ghostty" in a path.
if killall -USR2 ghostty 2>/dev/null; then
    echo "auto-theme: sent SIGUSR2 to Ghostty (config reloaded)"
else
    echo "auto-theme: Ghostty not running; will apply on next launch"
fi
