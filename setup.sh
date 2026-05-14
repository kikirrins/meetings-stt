#!/usr/bin/env bash
# Claude101 Workshop — STT setup (standalone)
# Installs parakeet-mlx + the MCP SDK into a self-contained venv at
# ~/.claude101-stt/. Models are downloaded into ~/.claude101-stt/models/ so
# this kit never touches any other model cache on the machine.
#
# The default model (NVIDIA Parakeet TDT 0.6B v3, ~1.2 GB) downloads on the
# first transcription, not here.
#
# Requires Apple Silicon (M-series Mac). parakeet-mlx uses Apple's MLX
# framework and won't run on Intel Macs or Linux.
#
# Usage:
#   bash setup.sh

set -euo pipefail

BLUE=$'\033[1;34m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
NC=$'\033[0m'

printf '%s== Claude101 STT setup ==%s\n' "$BLUE" "$NC"

# --- 1. Prerequisites --------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  printf '%sError:%s parakeet-mlx requires Apple Silicon (M-series Mac).\n' "$RED" "$NC"
  printf '   Detected: %s %s\n' "$(uname -s)" "$(uname -m)"
  printf '   On Intel Macs or Linux, use the openai-whisper variant — see README.\n'
  exit 1
fi
printf '%s✓%s macOS on Apple Silicon (MLX backend)\n' "$GREEN" "$NC"

# Python 3.10+ required by parakeet-mlx
if ! command -v python3 >/dev/null 2>&1; then
  printf '%sError:%s python3 not found. Install Python 3.10+ first.\n' "$RED" "$NC"
  exit 1
fi
PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
printf '%s✓%s Python %s found\n' "$GREEN" "$NC" "$PY_VERSION"

# ffmpeg for audio decoding (m4a, mp3, etc.)
if ! command -v ffmpeg >/dev/null 2>&1; then
  printf '%sffmpeg not found. Attempting install...%s\n' "$YELLOW" "$NC"
  if command -v brew >/dev/null 2>&1; then
    brew install ffmpeg
  else
    printf '%sError:%s Install Homebrew and run `brew install ffmpeg`, then re-run setup.\n' "$RED" "$NC"
    exit 1
  fi
else
  printf '%s✓%s ffmpeg found\n' "$GREEN" "$NC"
fi

# --- 2. ~/Meetings folder structure ------------------------------------------
MEETINGS_DIR="$HOME/Meetings"
mkdir -p "$MEETINGS_DIR/audio" "$MEETINGS_DIR/transcripts" "$MEETINGS_DIR/notes"
printf '%s✓%s Created %s/{audio,transcripts,notes}\n' "$GREEN" "$NC" "$MEETINGS_DIR"

# --- 3. Kit-local model cache ------------------------------------------------
KIT_DIR="$HOME/.claude101-stt"
MODELS_DIR="$KIT_DIR/models"
mkdir -p "$MODELS_DIR"
printf '%s✓%s Model cache: %s\n' "$GREEN" "$NC" "$MODELS_DIR"

# --- 4. Venv + dependencies --------------------------------------------------
VENV_DIR="$KIT_DIR"
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  printf '%sCreating virtualenv at %s...%s\n' "$BLUE" "$VENV_DIR" "$NC"
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
pip install --upgrade pip >/dev/null
printf '%sInstalling parakeet-mlx + MCP SDK...%s\n' "$BLUE" "$NC"
pip install --upgrade "parakeet-mlx>=0.5.1" "mcp[cli]>=1.2.0"
deactivate

printf '%s✓%s parakeet-mlx + MCP SDK installed in %s\n' "$GREEN" "$NC" "$VENV_DIR"

# --- 5. Smoke test -----------------------------------------------------------
if "$VENV_DIR/bin/parakeet-mlx" --help >/dev/null 2>&1; then
  printf '%s✓%s parakeet-mlx CLI working\n' "$GREEN" "$NC"
else
  printf '%s⚠%s  parakeet-mlx CLI test failed — check pip output above\n' "$YELLOW" "$NC"
fi

# --- 6. Done -----------------------------------------------------------------
cat <<EOF

${GREEN}Setup complete.${NC}

The first transcription will download Parakeet TDT 0.6B v3 (~1.2 GB) into
${MODELS_DIR}. It runs with ~2 GB RAM and auto-detects the language
(Spanish, English, and 23 more).

Next steps:
  1. Drop a recording in ~/Meetings/audio/, then run:
       bash bin/transcribe.sh ~/Meetings/audio/<file>

     Or on macOS, double-click transcribe-latest.command in Finder.

  2. Wire the MCP server into Claude Desktop:
       bash scripts/install-mcp-config.sh
     Then quit and reopen Claude Desktop.

  3. In a new Claude Desktop chat, ask:
       "Transcribe <file> from my meetings folder and extract key points."

EOF
