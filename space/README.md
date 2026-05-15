---
title: Claude101 Transcribe
emoji: 🎙️
colorFrom: blue
colorTo: green
sdk: gradio
sdk_version: "6.14.0"
app_file: app.py
pinned: false
license: mit
short_description: Free Spanish/EN transcription for Claude101
---

# Claude101 Transcribe — HF Space

Free, browser-based speech-to-text for the Claude101 workshop. Drop an audio file, get a `.txt` you can paste into Claude Desktop.

- **Model:** `faster-whisper large-v3-turbo` (distilled Whisper, 4× faster than Large v3)
- **Speed:** ~10–15× realtime on HF Space free CPU (10-min audio in ~50 s)
- **Languages:** Spanish-default, English/Portuguese/French/Italian/German + auto-detect
- **Cost:** $0 — runs on HF Space free CPU tier

## Use from a browser

Just drop a file and click *Transcribir*. The `.txt` downloads automatically.

## Use from Claude Desktop (MCP)

This Space exposes a native MCP server endpoint at:

```
https://kikirrin-claude101-transcribe.hf.space/gradio_api/mcp/
```

Paste that URL into Claude Desktop **Settings → Connectors → Add custom connector** and the `transcribe` tool becomes available in any chat. Then ask Claude: *"Transcribe audio.mp3 and extract key points."*

## Deploy your own copy

```bash
# 1. Create a Space on huggingface.co/new-space (Gradio SDK, free CPU tier)
# 2. Clone it locally
git clone https://huggingface.co/spaces/<your-user>/<space-name>
cd <space-name>

# 3. Copy these three files in
cp /path/to/workshop-stt/space/{app.py,requirements.txt,README.md} .

# 4. Push
git add -A && git commit -m "deploy claude101 transcribe" && git push
```

First boot takes ~3 min (downloads the model). After that, ~10 s cold start when idle.

## License

MIT.
