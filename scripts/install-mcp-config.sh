#!/usr/bin/env bash
# Claude101 Workshop — install-mcp-config.sh
#
# Adds (or updates) the "claude101-stt" entry inside the Claude Desktop config
# file so the STT tools appear in Claude Desktop. Preserves any other MCP
# servers already configured.
#
# Usage:
#   bash scripts/install-mcp-config.sh
#
# Restart Claude Desktop after running.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KIT_DIR="$HOME/.claude101-stt"
PY_BIN="$KIT_DIR/bin/python"
SERVER_PY="$REPO_DIR/mcp-server/server.py"

# Claude Desktop config path differs by OS
case "$(uname -s)" in
  Darwin)
    CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    ;;
  Linux)
    CFG="$HOME/.config/Claude/claude_desktop_config.json"
    ;;
  *)
    echo "Unsupported OS. Edit your Claude Desktop config manually using the example JSON."
    exit 1
    ;;
esac

if [[ ! -f "$PY_BIN" ]]; then
  echo "Kit not installed yet. Run setup.sh first." >&2
  exit 1
fi
if [[ ! -f "$SERVER_PY" ]]; then
  echo "Cannot find $SERVER_PY — are you running this from the repo root?" >&2
  exit 1
fi

mkdir -p "$(dirname "$CFG")"

python3 - <<PY
import json
import os
from pathlib import Path

cfg_path = Path(r"$CFG")
py_bin   = r"$PY_BIN"
server   = r"$SERVER_PY"

cfg = {}
if cfg_path.exists():
    try:
        cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        backup = cfg_path.with_suffix(cfg_path.suffix + ".bak")
        cfg_path.rename(backup)
        print(f"⚠  Existing config wasn't valid JSON — backed up to {backup}")
        cfg = {}

cfg.setdefault("mcpServers", {})
cfg["mcpServers"]["claude101-stt"] = {
    "command": py_bin,
    "args": [server],
    "env": {
        "WHISPER_MODEL": "large-v3",
        "WHISPER_LANGUAGE": "Spanish",
    },
}

cfg_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
print(f"✓ Wrote {cfg_path}")
print("  → Quit and reopen Claude Desktop for the connector to load.")
PY
