"""Claude101 Workshop — Hugging Face Space.

Free, browser-based transcription powered by faster-whisper (large-v3-turbo).
Exposes a Gradio web UI AND a native MCP server endpoint, so attendees can
either drop a file in the browser or have Claude Desktop call it as a tool.

Runs on HF Space free CPU tier:
  - faster-whisper "large-v3-turbo" with int8 quantization
  - ~600 MB RAM, ~10 sec model load, ~10-15x realtime on 2 vCPU
"""

from __future__ import annotations

import base64
import os
import tempfile
import time
from pathlib import Path

import gradio as gr
from faster_whisper import WhisperModel

MODEL_NAME = os.environ.get("WHISPER_MODEL", "large-v3-turbo")
COMPUTE_TYPE = os.environ.get("WHISPER_COMPUTE", "int8")

print(f"Loading faster-whisper model '{MODEL_NAME}' (compute={COMPUTE_TYPE})...")
t0 = time.time()
model = WhisperModel(MODEL_NAME, device="cpu", compute_type=COMPUTE_TYPE)
print(f"Model ready in {time.time() - t0:.1f}s")

LANG_OPTIONS = [
    ("Español (Spanish)", "es"),
    ("English", "en"),
    ("Auto-detect", "auto"),
    ("Português", "pt"),
    ("Français", "fr"),
    ("Italiano", "it"),
    ("Deutsch", "de"),
]


def transcribe(audio_path: str | None, language: str = "es") -> tuple[str, str]:
    """Transcribe an audio file using faster-whisper large-v3-turbo.

    Args:
        audio_path: Path to an audio file (mp3, m4a, wav, flac, ogg, mp4, etc).
            On the web UI this is filled by the file picker. When called as an
            MCP tool, pass a local path or URL Claude can read.
        language: Two-letter language code (e.g. "es", "en", "pt") or "auto"
            to let the model detect. Defaults to Spanish ("es").

    Returns:
        A tuple of (transcript_text, transcript_file_path). The text appears
        in the UI; the file path is offered as a `.txt` download.
    """
    if not audio_path:
        return "Please upload an audio file first.", None

    lang_arg = None if language == "auto" else language

    t0 = time.time()
    segments_iter, info = model.transcribe(
        audio_path,
        language=lang_arg,
        beam_size=5,
        condition_on_previous_text=False,
        vad_filter=True,
    )
    text = " ".join(seg.text.strip() for seg in segments_iter).strip()
    elapsed = time.time() - t0

    detected = info.language if lang_arg is None else lang_arg
    header = (
        f"# Transcript\n"
        f"_Model: {MODEL_NAME} · Language: {detected} · "
        f"Audio: {info.duration:.0f}s · "
        f"Transcribed in {elapsed:.0f}s ({info.duration/elapsed:.1f}x realtime)_\n\n"
    )

    stem = Path(audio_path).stem or "transcript"
    out_dir = Path(tempfile.gettempdir())
    out_path = out_dir / f"{stem}.txt"
    out_path.write_text(text + "\n", encoding="utf-8")

    return header + text, str(out_path)


def transcribe_bytes(
    audio_b64: str,
    filename: str = "audio.mp3",
    language: str = "es",
) -> str:
    """Transcribe a base64-encoded audio file. MCP-friendly: no URL needed.

    Use this when calling from an MCP client that has the audio bytes locally
    (e.g. Claude Code reading a file from disk and base64-encoding it). The
    server decodes to a temp file, transcribes, and returns the transcript
    text directly — no separate upload step.

    Args:
        audio_b64: Base64 string of the audio file's raw bytes. On a typical
            workshop audio (10-min Spanish at 128 kbps), this is ~10-15 MB of
            text. Keep individual calls under ~25 MB of base64 to be safe.
        filename: Original filename (used only to pick a file extension so
            ffmpeg/whisper can decode correctly). Default: "audio.mp3".
        language: Two-letter language code ("es", "en", "pt", ...) or "auto".
            Defaults to Spanish ("es").

    Returns:
        The transcript text as a single string (no UI markdown wrapper).
    """
    try:
        audio_bytes = base64.b64decode(audio_b64, validate=True)
    except Exception as exc:
        return f"ERROR: invalid base64 payload — {exc}"

    suffix = Path(filename).suffix or ".mp3"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        lang_arg = None if language == "auto" else language
        segments_iter, _info = model.transcribe(
            tmp_path,
            language=lang_arg,
            beam_size=5,
            condition_on_previous_text=False,
            vad_filter=True,
        )
        text = " ".join(seg.text.strip() for seg in segments_iter).strip()
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

    return text


with gr.Blocks(title="Claude101 Transcribe") as demo:
    gr.Markdown(
        """
        # 🎙️ Claude101 — Transcribe audio (free, no install)

        Sube un archivo de audio, elige el idioma y obtén un `.txt`. Después
        pégalo en Claude Desktop para extraer puntos clave y redactar el correo.

        *Upload an audio file, pick the language, get a `.txt`. Then paste it
        into Claude Desktop to extract key points and draft the follow-up email.*

        **Modelo / Model:** `faster-whisper large-v3-turbo` — ~10-15x realtime on free CPU.
        """
    )
    with gr.Row():
        with gr.Column():
            audio_in = gr.Audio(
                label="Audio (mp3, m4a, wav, mp4...)",
                type="filepath",
                sources=["upload"],
            )
            lang_in = gr.Dropdown(
                choices=LANG_OPTIONS,
                value="es",
                label="Idioma / Language",
            )
            run_btn = gr.Button("Transcribir / Transcribe", variant="primary")
        with gr.Column():
            text_out = gr.Markdown(label="Transcript")
            file_out = gr.File(label="Descargar .txt / Download .txt")

    run_btn.click(transcribe, inputs=[audio_in, lang_in], outputs=[text_out, file_out])

    # API-only endpoint (no UI) — exposed as an MCP tool for clients that
    # already have audio bytes on hand (e.g. Claude Code).
    gr.api(transcribe_bytes)

    gr.Markdown(
        """
        ---
        ### Usar desde Claude Desktop / Use from Claude Desktop

        Este Space también expone un **MCP server** remoto. Agrega esta URL en
        **Settings → Connectors** de Claude Desktop:

        *This Space also exposes a remote **MCP server**. Add this URL under
        **Settings → Connectors** in Claude Desktop:*

        ```
        https://kikirrin-claude101-transcribe.hf.space/gradio_api/mcp/
        ```

        Luego en chat: *"Transcribe `audio.mp3` y extrae los pendientes."*
        """
    )


if __name__ == "__main__":
    # mcp_server=True publishes every exposed function as an MCP tool at
    # /gradio_api/mcp/sse — Claude Desktop can connect to it directly.
    demo.queue(max_size=20).launch(mcp_server=True)
