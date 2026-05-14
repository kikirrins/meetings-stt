#!/usr/bin/env bash
# Double-click to transcribe the newest audio file in ~/Meetings/audio/.
# First run will also download the ~600MB Parakeet model.

set -e

cd "$(dirname "$0")"

AUDIO_DIR="$HOME/Meetings/audio"
if [[ ! -d "$AUDIO_DIR" ]]; then
  echo "No ~/Meetings/audio/ directory. Run setup.sh first."
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

# Pick newest audio file by mtime
LATEST=$(ls -t "$AUDIO_DIR"/*.{wav,mp3,m4a,flac,ogg,aac,opus,mp4} 2>/dev/null | head -n 1 || true)

if [[ -z "$LATEST" ]]; then
  echo "No audio files found in $AUDIO_DIR"
  echo "Drop a .wav / .mp3 / .m4a there and try again."
  read -n 1 -s -r -p "Press any key to close..."
  exit 1
fi

echo "Transcribing newest audio file:"
echo "  $LATEST"
echo

bash bin/transcribe.sh "$LATEST"

echo
echo "============================================================"
echo "Done. Transcript is in ~/Meetings/transcripts/"
echo "You can close this window."
echo "============================================================"
