#!/usr/bin/env bash
# smart-web-kit installer — macOS / Linux
#   ./install.sh              binary → ~/.local/bin, skills → ~/.agents/skills
#   ./install.sh --link       development mode: symlink tools/swr from this checkout
#
# Default: build the standalone binary (tools/build.sh) and install it as a real
# file, with the skill text embedded. Node is then only needed to run `swr`, not
# to find the skill; and moving or deleting the checkout does not break the
# installed command. --link keeps the old symlink for editing the tool in place.
set -euo pipefail

LINK=0
if [ "${1:-}" = "--link" ]; then LINK=1; fi
[ "$#" -le 1 ] || { echo "usage: ./install.sh [--link]"; exit 2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SWR_BIN_DIR:-$HOME/.local/bin}"

command -v node >/dev/null 2>&1 || { echo "ERROR: node >= 18 is required (https://nodejs.org)"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || { echo "ERROR: node >= 18 required, found $(node -v)"; exit 1; }

# 1) the command
mkdir -p "$BIN_DIR"
if [ "$LINK" -eq 1 ]; then
  # A symlink follows the working tree, so `swr init` deploys whatever is in the
  # checkout right now. Convenient while editing the tool, fragile afterwards:
  # the skill source is the checkout's ../skills, and the link dies with it.
  ln -sf "$REPO_DIR/tools/swr" "$BIN_DIR/swr"
  echo "installed (linked): $BIN_DIR/swr -> $REPO_DIR/tools/swr"
else
  # A real binary with the skill text embedded — no node_modules, no checkout,
  # no ../skills to find later.
  "$REPO_DIR/tools/build.sh" --install
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "WARNING: $BIN_DIR is not in PATH — add it to your shell profile";;
esac

# 2) skills — one canonical deployer, so install and re-sync can never
#    disagree about which roots receive the skills.
"$BIN_DIR/swr" init

# 3) smoke test
"$BIN_DIR/swr" --version
echo "OK. Try: swr https://example.com"
echo "---"
echo "  swr init             # re-sync skills into every agent root you use"
echo "  swr doctor           # ready / not-ready + what to install for Chrome escalation"
echo "  swr doctor --skills  # per-root status: synced, stale, modified, or missing"
