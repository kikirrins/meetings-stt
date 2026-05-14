"""Claude101 Workshop — local MCP server exposing parakeet-mlx transcription.

Standalone: uses a kit-local venv at ~/.claude101-stt/ and a kit-local model
cache at ~/.claude101-stt/models/. Never touches any other model cache.

Run via Claude Desktop's MCP config (see claude_desktop_config.example.json).
Stdio transport — no network exposure.

Default model: NVIDIA Parakeet TDT 0.6B v3 (multilingual, 25 European
languages incl. Spanish, with automatic language detection). Override via
the PARAKEET_MODEL environment variable in the MCP config.

Tools exposed:
  - list_audio_files()                 -> list recordings in ~/Meetings/audio/
  - list_transcripts()                 -> list transcripts already produced
  - transcribe_audio(filename, name?)  -> run parakeet-mlx on a recording
  - read_transcript(name)              -> return transcript text
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from mcp.server.fastmcp import FastMCP

# --- Paths -------------------------------------------------------------------
HOME = Path(os.path.expanduser("~"))
MEETINGS_DIR = HOME / "Meetings"
AUDIO_DIR = MEETINGS_DIR / "audio"
TRANSCRIPTS_DIR = MEETINGS_DIR / "transcripts"
NOTES_DIR = MEETINGS_DIR / "notes"

KIT_DIR = HOME / ".claude101-stt"
MODELS_DIR = KIT_DIR / "models"
PARAKEET_BIN = KIT_DIR / "bin" / "parakeet-mlx"

# Model default — override via env in the MCP config
PARAKEET_MODEL = os.environ.get(
    "PARAKEET_MODEL", "mlx-community/parakeet-tdt-0.6b-v3"
)

AUDIO_EXTS = {".wav", ".mp3", ".m4a", ".flac", ".ogg", ".aac", ".opus", ".mp4"}

# --- MCP server --------------------------------------------------------------
mcp = FastMCP("claude101-stt")


def _ensure_dirs() -> None:
    for d in (AUDIO_DIR, TRANSCRIPTS_DIR, NOTES_DIR, MODELS_DIR):
        d.mkdir(parents=True, exist_ok=True)


@mcp.tool()
def list_audio_files() -> str:
    """List audio recordings available in ~/Meetings/audio/.

    Returns a newline-separated list of filenames (relative to the audio dir),
    sorted by modification time (newest first). Use these names with
    transcribe_audio().
    """
    _ensure_dirs()
    files = [
        p for p in AUDIO_DIR.iterdir()
        if p.is_file() and p.suffix.lower() in AUDIO_EXTS
    ]
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return f"(no audio files found in {AUDIO_DIR})"
    return "\n".join(p.name for p in files)


@mcp.tool()
def list_transcripts() -> str:
    """List transcript files already produced in ~/Meetings/transcripts/."""
    _ensure_dirs()
    files = sorted(
        (p for p in TRANSCRIPTS_DIR.glob("*.txt") if p.is_file()),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not files:
        return f"(no transcripts yet in {TRANSCRIPTS_DIR})"
    return "\n".join(p.name for p in files)


@mcp.tool()
def transcribe_audio(filename: str, output_name: str | None = None) -> str:
    """Transcribe an audio file from ~/Meetings/audio/ using parakeet-mlx.

    Uses NVIDIA Parakeet TDT 0.6B v3 by default — a multilingual model that
    auto-detects the language (Spanish, English, and 23 more). Override
    the model via the PARAKEET_MODEL env var.

    Args:
        filename: Name of the audio file inside ~/Meetings/audio/
                  (e.g. "team_sync_2026_05_14.m4a"). Absolute paths also OK.
        output_name: Optional stem for the transcript file
                     (default: audio filename without extension).

    Returns the absolute path of the produced transcript, plus the first
    ~600 characters as a quick preview.
    """
    _ensure_dirs()

    audio_path = Path(filename)
    if not audio_path.is_absolute():
        audio_path = AUDIO_DIR / filename
    if not audio_path.exists():
        return f"ERROR: audio file not found: {audio_path}"
    if not PARAKEET_BIN.exists():
        return (
            f"ERROR: parakeet-mlx not installed at {PARAKEET_BIN}. "
            "Run workshop-stt/setup.sh first."
        )

    stem = output_name or audio_path.stem

    # Stage the audio under the desired stem so parakeet-mlx's default
    # output template ({filename}) produces the basename we want.
    with tempfile.TemporaryDirectory() as tmp_dir:
        staged = Path(tmp_dir) / f"{stem}{audio_path.suffix}"
        shutil.copy2(audio_path, staged)

        cmd = [
            str(PARAKEET_BIN),
            str(staged),
            "--model", PARAKEET_MODEL,
            "--output-dir", str(TRANSCRIPTS_DIR),
            "--output-format", "txt",
            "--cache-dir", str(MODELS_DIR),
        ]

        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, check=True, timeout=60 * 60
            )
        except subprocess.CalledProcessError as e:
            return f"ERROR: parakeet-mlx failed (exit {e.returncode})\n{e.stderr}"
        except subprocess.TimeoutExpired:
            return "ERROR: transcription timed out after 1 hour"

    transcript_path = TRANSCRIPTS_DIR / f"{stem}.txt"
    if not transcript_path.exists():
        return (
            f"ERROR: parakeet-mlx finished but no transcript at {transcript_path}.\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )

    preview = transcript_path.read_text(encoding="utf-8", errors="replace")[:600]
    return (
        f"Transcript saved: {transcript_path}\n\n"
        f"--- preview (first 600 chars) ---\n{preview}"
    )


@mcp.tool()
def read_transcript(name: str) -> str:
    """Return the full text of a transcript in ~/Meetings/transcripts/.

    Args:
        name: Transcript filename with or without the .txt extension.
    """
    _ensure_dirs()
    if not name.endswith(".txt"):
        name = f"{name}.txt"
    path = TRANSCRIPTS_DIR / name
    if not path.exists():
        return f"ERROR: transcript not found: {path}"
    return path.read_text(encoding="utf-8", errors="replace")


if __name__ == "__main__":
    mcp.run()
