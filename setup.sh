#!/usr/bin/env bash
# Claude101 Workshop — STT setup (standalone)
# Installs openai-whisper + the MCP SDK into a self-contained venv at
# ~/.claude101-stt/. Models are downloaded into ~/.claude101-stt/models/ so
# this kit never touches any other Whisper install on the machine.
#
# Whisper Large v3 (~3 GB) downloads on the first transcription, not here.
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
case "$(uname -s)" in
  Darwin)
    OS="macOS"
    if [[ "$(uname -m)" == "arm64" ]]; then
      printf '%s✓%s macOS on Apple Silicon (GPU via MPS)\n' "$GREEN" "$NC"
    else
      printf '%s⚠%s  macOS on Intel — transcription will run on CPU\n' "$YELLOW" "$NC"
    fi
    ;;
  Linux)
    OS="Linux"
    printf '%s✓%s Linux (GPU only if CUDA present)\n' "$GREEN" "$NC"
    ;;
  *)
    OS="$(uname -s)"
    printf '%s⚠%s  Untested OS: %s\n' "$YELLOW" "$NC" "$OS"
    ;;
esac

# Python 3.9+ required (openai-whisper supports 3.9–3.12)
if ! command -v python3 >/dev/null 2>&1; then
  printf '%sError:%s python3 not found. Install Python 3.10+ first.\n' "$RED" "$NC"
  exit 1
fi
PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
printf '%s✓%s Python %s found\n' "$GREEN" "$NC" "$PY_VERSION"

# ffmpeg for audio decoding (m4a, mp3, etc.)
if ! command -v ffmpeg >/dev/null 2>&1; then
  printf '%sffmpeg not found. Attempting install...%s\n' "$YELLOW" "$NC"
  if [[ "$OS" == "macOS" ]] && command -v brew >/dev/null 2>&1; then
    brew install ffmpeg
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y ffmpeg
  else
    printf '%sError:%s Install ffmpeg manually — required for non-WAV audio.\n' "$RED" "$NC"
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
printf '%sInstalling openai-whisper + MCP SDK (PyTorch is the heavy dep)...%s\n' "$BLUE" "$NC"
pip install --upgrade openai-whisper "mcp[cli]>=1.2.0"
deactivate

printf '%s✓%s openai-whisper + MCP SDK installed in %s\n' "$GREEN" "$NC" "$VENV_DIR"

# --- 5. Smoke test -----------------------------------------------------------
if "$VENV_DIR/bin/whisper" --help >/dev/null 2>&1; then
  printf '%s✓%s whisper CLI working\n' "$GREEN" "$NC"
else
  printf '%s⚠%s  whisper CLI test failed — check pip output above\n' "$YELLOW" "$NC"
fi

# --- 6. Done -----------------------------------------------------------------
cat <<EOF

${GREEN}Setup complete.${NC}

The first transcription will download Whisper Large v3 (~3 GB) into
${MODELS_DIR}.

Next steps:
  1. Drop a recording in ~/Meetings/audio/, then run:
       bash bin/transcribe.sh ~/Meetings/audio/<file>

     Or on macOS, double-click transcribe-latest.command in Finder.

  2. Wire the MCP server into Claude Desktop:
       Open  ~/Library/Application Support/Claude/claude_desktop_config.json
       Merge the snippet from  mcp-server/claude_desktop_config.example.json
         (edit the absolute paths to match your install — see README)
       Quit and reopen Claude Desktop.

  3. In a new Claude Desktop chat, ask:
       "Transcribe <file> from my meetings folder and extract key points."

EOF
