#!/usr/bin/env bash
# Claude101 Workshop — transcribe.sh
#
# Usage:
#   bin/transcribe.sh <audio_file> [output_name]
#
# Transcribes an audio file with openai-whisper (Large v3, Spanish-locked) and
# writes the .txt transcript to ~/Meetings/transcripts/. First run downloads
# the ~3 GB model into ~/.claude101-stt/models/ (kit-local cache, never touches
# any other Whisper install on the machine).

set -euo pipefail

KIT_DIR="$HOME/.claude101-stt"
VENV_DIR="$KIT_DIR"
MODELS_DIR="$KIT_DIR/models"
MEETINGS_DIR="$HOME/Meetings"
TRANSCRIPTS_DIR="$MEETINGS_DIR/transcripts"

# Override via env vars if you need a different model or language
MODEL="${WHISPER_MODEL:-large-v3}"
LANGUAGE="${WHISPER_LANGUAGE:-Spanish}"

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

if [[ ! -x "$VENV_DIR/bin/whisper" ]]; then
  echo "openai-whisper not installed at $VENV_DIR. Run setup.sh first." >&2
  exit 1
fi

mkdir -p "$TRANSCRIPTS_DIR" "$MODELS_DIR"

echo "Transcribing: $AUDIO_FILE"
echo "Model:        $MODEL"
echo "Language:     $LANGUAGE"
echo "Cache:        $MODELS_DIR"
echo "Output:       $TRANSCRIPTS_DIR/${OUTPUT_NAME}.txt"
echo

# Stage the audio under the target stem so whisper's auto-generated output
# filename matches what we want (whisper names outputs after the input stem).
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

EXT="${AUDIO_FILE##*.}"
STAGED="$TMP_DIR/${OUTPUT_NAME}.${EXT}"
cp "$AUDIO_FILE" "$STAGED"

# openai-whisper CLI flags (note: underscores, not hyphens)
#   --model large-v3                     Whisper Large v3
#   --language Spanish                   force Spanish (skip auto-detect drift)
#   --model_dir ...                      kit-local model cache
#   --output_dir ...                     where transcripts go
#   --output_format txt                  plain text (also: srt, vtt, json, all)
#   --condition_on_previous_text False   prevents v3's hallucination bug where
#                                        it drifts into subtitle artefacts
#   --verbose False                      quieter logs
"$VENV_DIR/bin/whisper" \
  "$STAGED" \
  --model "$MODEL" \
  --language "$LANGUAGE" \
  --model_dir "$MODELS_DIR" \
  --output_dir "$TRANSCRIPTS_DIR" \
  --output_format txt \
  --condition_on_previous_text False \
  --verbose False

echo
echo "Done. Transcript at: $TRANSCRIPTS_DIR/${OUTPUT_NAME}.txt"
