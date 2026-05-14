# Claude101 — Local Speech-to-Text Kit

Local, free, offline transcription for the **Claude101 workshop** exercise:
**audio → transcript → key points → email**.

Built around [`openai-whisper`](https://github.com/openai/whisper) with **Whisper Large v3** (Spanish-locked by default). Everything runs on your machine — no API costs, no cloud upload, no length limit. Pairs with **Claude Desktop** via a tiny local MCP server so you can transcribe straight from chat.

> Hecho para el workshop Claude101. El audio de los ejercicios está en español; el modelo viene preconfigurado para español. Para cambiar el idioma, edita `WHISPER_LANGUAGE` en el MCP config (ver más abajo).

## What you get

- A reproducible `setup.sh` that creates a kit-local venv at `~/.claude101-stt/` and a model cache at `~/.claude101-stt/models/`. **Does not touch any other Whisper install** you may already have.
- A simple CLI: `bin/transcribe.sh path/to/audio.m4a` → drops a `.txt` into `~/Meetings/transcripts/`
- A local **MCP server** so Claude Desktop can run transcription as a tool from any chat
- An auto-install script for the Claude Desktop config so you never edit JSON by hand
- A `~/Meetings/` folder structure: `audio/`, `transcripts/`, `notes/`
- Convenience `.command` files for macOS users who prefer double-clicking

## Requirements

- macOS (Apple Silicon recommended — uses MPS GPU) **or** Linux (CPU; CUDA if available)
- Python 3.10+
- `ffmpeg` (setup tries to install it for you via Homebrew or apt)
- ~4 GB free disk for the model + venv

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
4. Installs `openai-whisper` + the MCP SDK
5. Whisper Large v3 (~3 GB) downloads on **first transcription**, into `~/.claude101-stt/models/`

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

Prefer to do it by hand? Use `mcp-server/claude_desktop_config.example.json` as a template — edit the two `REPLACE_WITH_*` placeholders to match your install, then merge into `~/Library/Application Support/Claude/claude_desktop_config.json` (Linux: `~/.config/Claude/`).

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
| `transcribe_audio`  | Run Whisper Large v3 on a recording; saves to `~/Meetings/transcripts/`|
| `read_transcript`   | Return the full text of a saved transcript                             |

## Configuration

Defaults are designed for the workshop (Spanish, max accuracy). Override via env vars in the MCP config:

| Variable           | Default                  | Notes |
|--------------------|--------------------------|-------|
| `WHISPER_MODEL`    | `large-v3`               | Also valid: `large-v3-turbo`, `medium`, `small`, `base`, `tiny` |
| `WHISPER_LANGUAGE` | `Spanish`                | Use the English name, e.g. `English`, `French`, `German`. Or set empty `""` for auto-detect. |

For the CLI: prefix the command with the env vars, e.g.

```bash
WHISPER_LANGUAGE=English bash bin/transcribe.sh ~/Meetings/audio/foo.wav
```

## Troubleshooting

**`whisper: command not found` / setup says it didn't install.** Re-run `bash setup.sh`. Check Python is ≥ 3.10 (`python3 --version`).

**`ffmpeg not found` during transcription of `.m4a` / `.mp3`.** Install via `brew install ffmpeg` (macOS) or `sudo apt-get install ffmpeg` (Linux).

**First run is slow.** The Large v3 model (~3 GB) downloads to `~/.claude101-stt/models/` once. Subsequent runs use the cached file and roughly run real-time-or-faster on Apple Silicon.

**Transcript has subtitle-looking garbage at the start.** That's Whisper v3's known hallucination bug; we already pass `--condition_on_previous_text False` to suppress it. If you still see it, switch to `WHISPER_MODEL=large-v3-turbo`.

**MCP server doesn't show up in Claude Desktop.** Restart Claude Desktop. Check the config file landed correctly:
```bash
cat "~/Library/Application Support/Claude/claude_desktop_config.json"
```
On Linux it's `~/.config/Claude/claude_desktop_config.json`.

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
