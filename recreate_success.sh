#!/bin/bash
# Version: 2.0.0 · updated 26-08-13-20-10
# install.sh for sensors.gorilla — put it on your PATH.
#
# TWO MODES, AND THE REASON THERE ARE TWO
#   Default is a COPY. That is the right thing for anyone who clones this repo:
#   the installed command keeps working even if they delete the clone.
#
#   --link installs a SYMLINK instead, for whoever is actually developing the
#   script. A copy silently drifts from its source — on the author's machine
#   three copies of this tool ended up at two different revisions, with the
#   documentation describing a third, and an afternoon went to diagnosing a
#   layout that was never broken. A symlink cannot drift.
#
#   Either way --check tells you whether what is installed matches this repo.
#
# USAGE
#   ./recreate_success.sh          install a copy
#   ./recreate_success.sh --link   install a symlink (for developing)
#   ./recreate_success.sh --check  compare installed against this repo

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/sensors.gorilla"
INSTALL_DIR="$HOME/.local/bin"
DEST="$INSTALL_DIR/sensors.gorilla"

# Anchor to the source, never assume it: if the script is missing, say so and
# stop, rather than installing nothing and reporting success.
[ -f "$SRC" ] || { echo "error: $SRC not found — run this from the repo." >&2; exit 1; }

version_of () { sed -n 's/^# Version: \([^ ]*\).*/\1/p' "$1" 2>/dev/null | head -1; }

case "${1:-copy}" in
  --check)
      if [ ! -e "$DEST" ]; then
          echo "  not installed  $DEST"; exit 1
      fi
      if [ -L "$DEST" ]; then
          echo "  symlink -> $(readlink -f "$DEST")"
      fi
      if cmp -s "$SRC" "$DEST"; then
          echo "  in sync   v$(version_of "$SRC")  $DEST"
      else
          echo "  DRIFTED   repo v$(version_of "$SRC") vs installed v$(version_of "$DEST")" >&2
          echo "            re-run this script to fix it." >&2
          exit 1
      fi
      exit 0 ;;
  --link|copy|--copy) ;;
  *) sed -n '2,25p' "$0"; exit 2 ;;
esac

mkdir -p "$INSTALL_DIR"
rm -f "$DEST"

if [ "${1:-}" = "--link" ]; then
    ln -s "$SRC" "$DEST"
    echo "Linked  $DEST -> $SRC"
else
    cp "$SRC" "$DEST"
    chmod +x "$DEST"
    echo "Copied  $SRC -> $DEST"
fi

# Verify the artifact, not the exit code: cp and ln both report success having
# produced something unusable if the target directory is odd.
cmp -s "$SRC" "$DEST" || { echo "error: installed file does not match source" >&2; exit 1; }
[ -x "$DEST" ] || { echo "error: installed file is not executable" >&2; exit 1; }

echo "=================================================="
echo "sensors.gorilla v$(version_of "$SRC") installed and verified"
echo "=================================================="
echo "Usage: sensors.gorilla         (live dashboard, follows the window)"
echo "       sensors.gorilla --once  (one snapshot, then exit)"
echo "       sensors.gorilla -n 5    (refresh every 5s)"
echo ""
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "WARNING: $INSTALL_DIR is not on your PATH. Add it to ~/.profile:"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""; echo "" ;;
esac
echo "Note: For SSD health & lifespan metrics, install smartmontools:"
echo "  sudo apt install smartmontools"
echo "=================================================="
