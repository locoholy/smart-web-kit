#!/usr/bin/env bash
# smart-web-kit installer — macOS / Linux
#   ./install.sh              binary → ~/.local/bin, skills → ~/.claude/skills
#   ./install.sh --project    also copy skills into ./.claude/skills and ./.agents/skills
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SWR_BIN_DIR:-$HOME/.local/bin}"

command -v node >/dev/null 2>&1 || { echo "ERROR: node >= 18 is required (https://nodejs.org)"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || { echo "ERROR: node >= 18 required, found $(node -v)"; exit 1; }

# 1) binary
mkdir -p "$BIN_DIR"
install -m 0755 "$REPO_DIR/tools/swr" "$BIN_DIR/swr"
echo "installed: $BIN_DIR/swr"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "WARNING: $BIN_DIR is not in PATH — add it to your shell profile"; ;;
esac

# 2) skills
copy_skills() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$REPO_DIR/skills/." "$dest/"
  echo "skills:    $dest"
}

if [ "${1:-}" = "--project" ]; then
  copy_skills ".claude/skills"
  copy_skills ".agents/skills"
else
  copy_skills "$HOME/.claude/skills"
fi

# 3) smoke test
"$BIN_DIR/swr" --version && echo "OK. Try: swr https://example.com"
echo "---"
echo "Wire any AI agent to swr inside a project:"
echo "  swr init          # ./.agents/skills (Codex / Agent-Skills CLIs)"
echo "  swr init --claude # ./.claude/skills (Claude)"
echo "  swr doctor        # ready / not-ready + what to install for Chrome escalation"
