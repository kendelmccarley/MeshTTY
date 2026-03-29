#!/usr/bin/env bash
# meshtty-crt.sh — Launch MeshTTY inside cool-retro-term
#
# Usage: ./meshtty-crt.sh [meshtty flags, e.g. --bot --log]
#
# On first run, prints a one-time hint to import the bundled CRT profile.
# After that it launches cool-retro-term with meshtty.sh running inside it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate cool-retro-term ────────────────────────────────────────────────────

_find_crt() {
    # Check PATH first (Linux / Homebrew)
    if command -v cool-retro-term &>/dev/null; then
        command -v cool-retro-term
        return 0
    fi
    # macOS .app bundle locations
    local candidates=(
        "/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term"
        "$HOME/Applications/cool-retro-term.app/Contents/MacOS/cool-retro-term"
    )
    for p in "${candidates[@]}"; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

CRT_BIN="$(_find_crt)" || {
    cat >&2 << 'EOF'

  cool-retro-term not found.  Install it first:

    macOS:         brew install --cask cool-retro-term
    Raspberry Pi:  sudo apt install cool-retro-term
    Ubuntu:        sudo apt install cool-retro-term

  Then re-run:  ./meshtty-crt.sh

EOF
    exit 1
}

# ── One-time profile import hint ──────────────────────────────────────────────

HINT_STAMP="$HOME/.config/meshtty/.crt-hint-shown"
if [ ! -f "$HINT_STAMP" ]; then
    mkdir -p "$(dirname "$HINT_STAMP")" && touch "$HINT_STAMP"
    cat >&2 << EOF

  ╔══════════════════════════════════════════════════════════════════╗
  ║  First run: import a MeshTTY profile into cool-retro-term       ║
  ║                                                                  ║
  ║  Open cool-retro-term, then:                                     ║
  ║    Settings  ▶  Profiles  ▶  Import                             ║
  ║                                                                  ║
  ║  Choose one of these files from the MeshTTY repo:               ║
  ║    assets/crt-profiles/meshtty-amber.json    (warm amber)       ║
  ║    assets/crt-profiles/meshtty-phosphor.json (green phosphor)   ║
  ║                                                                  ║
  ║  This message appears only once.                                 ║
  ╚══════════════════════════════════════════════════════════════════╝

EOF
fi

# ── Build inner command ───────────────────────────────────────────────────────
# Prefer the installed meshtty.sh (has venv activation + serial wait logic).
# Fall back to direct python invocation for dev/uninstalled environments.

if [ -f "$SCRIPT_DIR/meshtty.sh" ]; then
    INNER_CMD="$SCRIPT_DIR/meshtty.sh"
else
    INNER_CMD="python3 -m meshtty.main"
fi

# Safely quote caller's arguments so they survive the bash -c hand-off
QUOTED_ARGS=""
for arg in "$@"; do
    QUOTED_ARGS="${QUOTED_ARGS} $(printf '%q' "$arg")"
done

# Write a temp wrapper script — avoids shell quoting issues with -e
TMPSCRIPT="$(mktemp "${TMPDIR:-/tmp}/meshtty-crt-XXXXXX.sh")"
chmod +x "$TMPSCRIPT"
cat > "$TMPSCRIPT" << INNER
#!/usr/bin/env bash
cd $(printf '%q' "$SCRIPT_DIR")
exec $INNER_CMD$QUOTED_ARGS
INNER

# ── Launch ────────────────────────────────────────────────────────────────────
"$CRT_BIN" -e "$TMPSCRIPT"
EXIT_CODE=$?
rm -f "$TMPSCRIPT"
exit $EXIT_CODE
