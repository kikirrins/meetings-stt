#!/usr/bin/env python3
"""Claude101 Workshop — transcribe a local audio file via the HF Space.

Designed for Claude Code (or any local agent) to call as a single command:

    python bin/transcribe-remote.py <audio_file> [--language es] [--space URL]

Output: writes the transcript to ~/Meetings/transcripts/<stem>.txt and prints
the path on the final line of stdout. All progress lines go to stderr.

For audios longer than ~5 minutes, the script splits them into chunks with
ffmpeg, transcribes each chunk in series, and concatenates the result. This
keeps each request within the free CPU Space's per-call budget and avoids
giant uploads.

Requires:
  - gradio_client  (install with: pip install gradio_client)
  - ffmpeg         (brew install ffmpeg)
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from gradio_client import Client, handle_file

DEFAULT_SPACE = "https://kikirrin-claude101-transcribe.hf.space"
CHUNK_SECONDS = 5 * 60  # 5 minutes per chunk
TRANSCRIPTS_DIR = Path.home() / "Meetings" / "transcripts"


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def audio_duration_seconds(path: Path) -> float:
    """Return audio duration in seconds via ffprobe (silent on error → 0)."""
    try:
        out = subprocess.check_output(
            [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", str(path),
            ],
            stderr=subprocess.DEVNULL,
        )
        return float(out.strip())
    except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
        return 0.0


def split_audio(path: Path, work_dir: Path, chunk_seconds: int) -> list[Path]:
    """Split audio into N-second chunks via ffmpeg (re-encode to mp3 mono).

    Mono 64 kbps mp3 is sufficient for ASR and much smaller than the source.
    """
    pattern = work_dir / f"{path.stem}_part_%03d.mp3"
    subprocess.check_call(
        [
            "ffmpeg", "-y", "-i", str(path),
            "-f", "segment", "-segment_time", str(chunk_seconds),
            "-ac", "1", "-ar", "16000", "-c:a", "libmp3lame", "-b:a", "64k",
            "-reset_timestamps", "1", "-loglevel", "error",
            str(pattern),
        ]
    )
    return sorted(work_dir.glob(f"{path.stem}_part_*.mp3"))


def transcribe_one(client: Client, audio: Path, language: str) -> str:
    text, _ = client.predict(
        audio_path=handle_file(str(audio)),
        language=language,
        api_name="/transcribe",
    )
    # Strip the markdown header the web UI adds, keep only the body
    if text.startswith("# Transcript"):
        parts = text.split("\n\n", 1)
        text = parts[1] if len(parts) == 2 else text
    return text.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audio_file", type=Path, help="Local audio file to transcribe")
    parser.add_argument("--language", default="es", help="ISO code or 'auto' (default: es)")
    parser.add_argument("--space", default=os.environ.get("CLAUDE101_SPACE", DEFAULT_SPACE))
    parser.add_argument(
        "--chunk-seconds", type=int, default=CHUNK_SECONDS,
        help=f"Chunk size for long audios (default {CHUNK_SECONDS}s)",
    )
    args = parser.parse_args()

    if not args.audio_file.exists():
        log(f"ERROR: audio file not found: {args.audio_file}")
        return 1
    if shutil.which("ffmpeg") is None:
        log("ERROR: ffmpeg not found on PATH. Install with: brew install ffmpeg")
        return 1

    TRANSCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = TRANSCRIPTS_DIR / f"{args.audio_file.stem}.txt"

    duration = audio_duration_seconds(args.audio_file)
    log(f"Audio: {args.audio_file.name}  ({duration:.0f}s)")
    log(f"Space: {args.space}")

    log("Connecting to Space...")
    client = Client(args.space, verbose=False)

    t0 = time.time()
    if duration <= args.chunk_seconds * 1.1 or duration == 0:
        log("Transcribing single segment...")
        text = transcribe_one(client, args.audio_file, args.language)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            work_dir = Path(tmp)
            log(f"Splitting into ≤{args.chunk_seconds}s chunks...")
            chunks = split_audio(args.audio_file, work_dir, args.chunk_seconds)
            log(f"  → {len(chunks)} chunks")
            pieces: list[str] = []
            for i, chunk in enumerate(chunks, 1):
                log(f"  [{i}/{len(chunks)}] {chunk.name} …")
                pieces.append(transcribe_one(client, chunk, args.language))
            text = "\n\n".join(pieces).strip()

    elapsed = time.time() - t0
    out_path.write_text(text + "\n", encoding="utf-8")

    log(f"Done in {elapsed:.0f}s  ({len(text)} chars)")
    print(out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
