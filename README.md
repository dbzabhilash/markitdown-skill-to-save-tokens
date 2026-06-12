# markitdown-skill — convert documents to Markdown to save tokens

A [Claude Code skill](https://code.claude.com/docs/en/skills) that wraps Microsoft's [MarkItDown](https://github.com/microsoft/markitdown) library. Instead of feeding raw PDFs, Office documents, or YouTube pages into the chat (expensive and unreliable), the skill converts them to clean Markdown once and then performs your instructions against the Markdown — reading only the sections the task needs.

## What it converts

| Input | Notes |
|---|---|
| PDF | Text layer extraction (scanned/image-only PDFs need OCR instead) |
| Word (.docx), PowerPoint (.pptx), Excel (.xlsx/.xls), CSV | Tables become Markdown tables |
| HTML, EPUB | |
| Images | EXIF metadata + OCR |
| Audio (.wav/.mp3) | Speech transcription (needs ffmpeg) |
| ZIP | Iterates over contents |
| Outlook .msg, Jupyter .ipynb, JSON/XML | |
| YouTube URLs | Title + transcript; automatic `yt-dlp` subtitle fallback when YouTube blocks the transcript API |

## Requirements

- [uv](https://docs.astral.sh/uv/getting-started/installation/) (`curl -LsSf https://astral.sh/uv/install.sh | sh`) — the skill runs MarkItDown through `uvx`, so no permanent Python package installation is needed. The first conversion downloads dependencies (~30s); later runs are instant.
- ffmpeg (optional, only for audio transcription): `brew install ffmpeg`

## Install

Copy the `markitdown/` folder into your personal skills directory:

```bash
git clone https://github.com/dbzabhilash/markitdown-skill-to-save-tokens.git
cp -r markitdown-skill-to-save-tokens/markitdown ~/.claude/skills/
```

Optionally register a slash trigger in `~/.claude/CLAUDE.md`:

```markdown
# markitdown
- **markitdown** (`~/.claude/skills/markitdown/SKILL.md`) - convert PDFs, Office docs, EPUB, images, audio, YouTube URLs to Markdown via Microsoft MarkItDown, then work on the Markdown to save tokens. Trigger: `/markitdown`
When the user types `/markitdown`, invoke the Skill tool with `skill: "markitdown"` before doing anything else.
```

## Usage

In a Claude Code or cloud chat session with the skill installed:

- `/markitdown ~/Downloads/report.pdf` — convert and report where the .md landed
- "Summarize the key findings in `quarterly-review.docx`" — the skill triggers automatically, converts, then summarizes from the Markdown
- Paste a YouTube URL and ask for the transcript or a summary

You can also run the bundled script directly without Claude:

```bash
bash markitdown/scripts/convert.sh <file-or-youtube-url> [output.md]
```

## Repository layout

```
markitdown/
├── SKILL.md            # skill definition: triggers, workflow, troubleshooting
└── scripts/
    └── convert.sh      # conversion wrapper: output naming, YouTube fallback,
                        # empty-output detection
```

## Why this saves tokens

Parsing a PDF or .docx in-context burns tokens on layout noise, encoding artifacts, and repeated re-reads. Converting once to Markdown produces a compact, grep-able working copy — the chat then pulls in only the relevant sections with targeted reads instead of ingesting the whole document.
