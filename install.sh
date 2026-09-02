#!/usr/bin/env bash
# smart-web-kit installer — macOS / Linux
#   ./install.sh              binary → ~/.local/bin, skills → ~/.agents/skills
set -euo pipefail

[ "$#" -eq 0 ] || { echo "usage: ./install.sh"; exit 2; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SWR_BIN_DIR:-$HOME/.local/bin}"

command -v node >/dev/null 2>&1 || { echo "ERROR: node >= 18 is required (https://nodejs.org)"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || { echo "ERROR: node >= 18 required, found $(node -v)"; exit 1; }

# 1) binary — symlink, not a copy. A copied binary loses sight of ../skills,
#    so `swr init` from it cannot find what it is supposed to deploy, and the
#    installed command silently drifts behind the repo it came from.
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/tools/swr" "$BIN_DIR/swr"
echo "installed: $BIN_DIR/swr -> $REPO_DIR/tools/swr"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "WARNING: $BIN_DIR is not in PATH — add it to your shell profile"; ;;
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
echo "  swr doctor --skills  # confirm every installed copy matches this release"
