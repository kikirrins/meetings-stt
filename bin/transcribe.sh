#!/usr/bin/env bash
# Claude101 Workshop — transcribe.sh
#
# Usage:
#   bin/transcribe.sh <audio_file> [output_name]
#
# Transcribes an audio file with parakeet-mlx (NVIDIA Parakeet TDT 0.6B v3,
# multilingual with automatic language detection) and writes the .txt
# transcript to ~/Meetings/transcripts/. First run downloads the model
# (~1.2 GB) into ~/.claude101-stt/models/ — a kit-local cache that never
# touches any other model cache on the machine.

set -euo pipefail

KIT_DIR="$HOME/.claude101-stt"
VENV_DIR="$KIT_DIR"
MODELS_DIR="$KIT_DIR/models"
MEETINGS_DIR="$HOME/Meetings"
TRANSCRIPTS_DIR="$MEETINGS_DIR/transcripts"

# Override via env var if you need a different model
MODEL="${PARAKEET_MODEL:-mlx-community/parakeet-tdt-0.6b-v3}"

if [[ $# -lt 1 ]]; then
  echo "Usage: transcribe.sh <audio_file> [output_name]" >&2
  exit 1
fi

AUDIO_FILE="$1"
OUTPUT_NAME="${2:-$(basename "${AUDIO_FILE%.*}")}"

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Audio file not found: $AUDIO_FILE" >&2
  exit 1
fi

if [[ ! -x "$VENV_DIR/bin/parakeet-mlx" ]]; then
  echo "parakeet-mlx not installed at $VENV_DIR. Run setup.sh first." >&2
  exit 1
fi

mkdir -p "$TRANSCRIPTS_DIR" "$MODELS_DIR"

echo "Transcribing: $AUDIO_FILE"
echo "Model:        $MODEL"
echo "Cache:        $MODELS_DIR"
echo "Output:       $TRANSCRIPTS_DIR/${OUTPUT_NAME}.txt"
echo

# Stage the audio under the target stem so parakeet-mlx's default
# output template ({filename}) produces the basename we want.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

EXT="${AUDIO_FILE##*.}"
STAGED="$TMP_DIR/${OUTPUT_NAME}.${EXT}"
cp "$AUDIO_FILE" "$STAGED"

# parakeet-mlx CLI flags:
#   --model            Hugging Face repo id (multilingual TDT v3 by default)
#   --output-dir       where transcripts go
#   --output-format    plain text (also: srt, vtt, json, all)
#   --cache-dir        kit-local HF cache so we don't pollute ~/.cache/huggingface
"$VENV_DIR/bin/parakeet-mlx" \
  "$STAGED" \
  --model "$MODEL" \
  --output-dir "$TRANSCRIPTS_DIR" \
  --output-format txt \
  --cache-dir "$MODELS_DIR"

echo
echo "Done. Transcript at: $TRANSCRIPTS_DIR/${OUTPUT_NAME}.txt"
