# Claude101 — Speech-to-Text Kit

Free transcription for the **Claude101 workshop** exercise:
**audio → transcript → key points → email**.

## 🚀 Modo rápido (Windows, Mac, Chromebook) — sin instalar nada

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/kikirrins/meetings-stt/blob/main/colab/Claude101_Transcribe.ipynb)

Haz clic en el botón **Open in Colab** ☝️ — sube tu audio, corre 4 celdas, descarga el transcript `.txt`. No necesitas Git, Python, ni nada. Funciona igual en Windows, Mac y Chromebook.

> *Fast path (any OS, no install): click the **Open in Colab** badge above. Upload your audio, run 4 cells, download the `.txt`. No Git, no Python, no setup.*

---

## Modo local (Mac Apple Silicon) — instalación nativa

Lo de abajo es **solo para usuarios técnicos en Mac M1/M2/M3/M4** que quieren la integración con Claude Desktop vía MCP. Si solo necesitas el transcript, usa la opción de Colab.

*The rest of this README covers the **local install** — Apple Silicon Mac only, for users who want native Claude Desktop MCP integration. If you just need a transcript, use the Colab option above.*

Built around [`parakeet-mlx`](https://github.com/senstella/parakeet-mlx) running NVIDIA's **Parakeet TDT 0.6B v3** — a 600M-parameter multilingual ASR model that runs on Apple Silicon in ~2 GB of RAM and auto-detects the language (Spanish, English, and 23 more). Everything runs on your machine — no API costs, no cloud upload. Pairs with **Claude Desktop** via a tiny local MCP server so you can transcribe straight from chat.

> Hecho para el workshop Claude101. El modelo es multilingüe y detecta automáticamente el idioma; no hace falta configurarlo. Sirve igual para audio en español o inglés.

## What you get

- A reproducible `setup.sh` that creates a kit-local venv at `~/.claude101-stt/` and a model cache at `~/.claude101-stt/models/`. **Does not touch any other model cache** you may already have.
- A simple CLI: `bin/transcribe.sh path/to/audio.m4a` → drops a `.txt` into `~/Meetings/transcripts/`
- A local **MCP server** so Claude Desktop can run transcription as a tool from any chat
- An auto-install script for the Claude Desktop config so you never edit JSON by hand
- A `~/Meetings/` folder structure: `audio/`, `transcripts/`, `notes/`
- Convenience `.command` files for macOS users who prefer double-clicking

## Requirements

- **Apple Silicon Mac** (M1/M2/M3/M4 — uses Apple's MLX framework). Intel Macs and Linux are not supported by this kit.
- Python 3.10+
- `ffmpeg` (setup tries to install it via Homebrew)
- ~2 GB RAM available during transcription (works on 8 GB MacBook Airs)
- ~2 GB free disk for the model + venv

## Quick start

```bash
git clone https://github.com/kikirrins/meetings-stt.git
cd meetings-stt
bash setup.sh
```

That:

1. Installs `ffmpeg` if missing
2. Creates `~/Meetings/audio/`, `~/Meetings/transcripts/`, `~/Meetings/notes/`
3. Creates a venv at `~/.claude101-stt/`
4. Installs `parakeet-mlx` + the MCP SDK
5. Parakeet TDT 0.6B v3 (~1.2 GB) downloads on **first transcription**, into `~/.claude101-stt/models/`

### Test the CLI

```bash
# Drop an audio file at ~/Meetings/audio/test.m4a, then:
bash bin/transcribe.sh ~/Meetings/audio/test.m4a
```

(macOS shortcut: double-click `transcribe-latest.command` — it grabs the newest file in `~/Meetings/audio/` automatically.)

### Wire it into Claude Desktop

One command:

```bash
bash scripts/install-mcp-config.sh
```

That merges the `claude101-stt` MCP server entry into your Claude Desktop config (preserving anything else you already had configured). **Restart Claude Desktop** and the four tools below appear under the connector.

Prefer to do it by hand? Use `mcp-server/claude_desktop_config.example.json` as a template — edit the two `REPLACE_WITH_*` placeholders to match your install, then merge into `~/Library/Application Support/Claude/claude_desktop_config.json`.

## Workshop flow

| Step | What | How |
|------|------|-----|
| 0 | Record audio | macOS Voice Memos / QuickTime / your phone. Save to `~/Meetings/audio/`. |
| 1 | **Transcribe** | CLI: `bash bin/transcribe.sh ~/Meetings/audio/<file>` <br> Or from Claude Desktop chat: *"Transcribe `<file>` from my meetings folder."* |
| 2 | Key points + email | In Claude Desktop: *"Extract action items and key decisions, then draft a follow-up email."* |

(If a participant already has a transcript, they skip step 1.)

## MCP tools exposed

| Tool                | Purpose                                                                |
|---------------------|------------------------------------------------------------------------|
| `list_audio_files`  | List recordings in `~/Meetings/audio/` (newest first)                  |
| `list_transcripts`  | List transcripts already produced                                      |
| `transcribe_audio`  | Run Parakeet TDT v3 on a recording; saves to `~/Meetings/transcripts/` |
| `read_transcript`   | Return the full text of a saved transcript                             |

## Configuration

The default model is multilingual and auto-detects the language, so there's nothing to configure for the workshop. If you need a different Parakeet variant, override via env var in the MCP config:

| Variable           | Default                                  | Notes |
|--------------------|------------------------------------------|-------|
| `PARAKEET_MODEL`   | `mlx-community/parakeet-tdt-0.6b-v3`     | Any Hugging Face repo id compatible with parakeet-mlx, e.g. `mlx-community/parakeet-tdt-0.6b-v2` (English-only, faster). |

For the CLI: prefix the command with the env var, e.g.

```bash
PARAKEET_MODEL=mlx-community/parakeet-tdt-0.6b-v2 bash bin/transcribe.sh ~/Meetings/audio/foo.wav
```

## Troubleshooting

**`parakeet-mlx: command not found` / setup says it didn't install.** Re-run `bash setup.sh`. Check Python is ≥ 3.10 (`python3 --version`) and that you're on Apple Silicon (`uname -m` should print `arm64`).

**`ffmpeg not found` during transcription of `.m4a` / `.mp3`.** Install via `brew install ffmpeg`.

**First run is slow.** Parakeet TDT v3 (~1.2 GB) downloads to `~/.claude101-stt/models/` once. Subsequent runs use the cached file — roughly 60× realtime on M-series Macs (one hour of audio ≈ one minute).

**The model picked the wrong language.** v3 auto-detects per 24-second window. If a short clip is misclassified, transcribe a longer chunk or switch to an English-only model (`PARAKEET_MODEL=mlx-community/parakeet-tdt-0.6b-v2`) when you know the audio is English.

**MCP server doesn't show up in Claude Desktop.** Restart Claude Desktop. Check the config landed correctly:
```bash
cat "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
```

**I want to uninstall.** Delete `~/.claude101-stt/` (venv + model cache) and `~/Meetings/` (your recordings — back up first). Remove the `claude101-stt` entry from the Claude Desktop config.

## Repo layout

```
.
├── README.md
├── LICENSE                         MIT
├── setup.sh                        one-shot installer
├── run-setup.command               macOS double-click wrapper for setup.sh
├── transcribe-latest.command       macOS double-click — transcribes newest audio
├── bin/
│   └── transcribe.sh               CLI transcriber
├── mcp-server/
│   ├── server.py                   local MCP server (stdio)
│   ├── requirements.txt
│   └── claude_desktop_config.example.json
└── scripts/
    └── install-mcp-config.sh       auto-merge MCP entry into Claude Desktop
```

## License

MIT — see `LICENSE`.
