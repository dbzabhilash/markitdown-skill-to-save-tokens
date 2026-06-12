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

## Measured token savings

Controlled experiment (June 2026): two independent Claude Code agent sessions were given the **identical task** — "summarize this PDF into 5 key bullet points" — on the same mounted PDF, a 25-page, 27.7 MB image-heavy presentation deck. One session followed this skill (convert to Markdown, summarize from the .md); the other worked on the raw PDF directly (rendering pages as images, the standard path for PDFs without a text-extraction step).

| Metric | With skill | Without skill (raw PDF) | Improvement |
|---|---|---|---|
| Total session tokens | **27,244** | 69,345 | **60.7% fewer tokens** |
| Wall-clock time | 52 s | 398 s | **7.6× faster** |
| Tool calls | 6 | 50 | 8.3× fewer |
| Document coverage | All 25 pages | 20 of 25 pages | Full coverage |

What drove the difference:

- The entire 27.7 MB PDF reduced to a **7.9 KB Markdown file (~2,000 tokens)**. The raw-PDF session instead ingested 20 high-resolution page images, each costing far more tokens than the text it contained.
- The raw-PDF session **never achieved full coverage**: after 20 large page images, the API's many-image request limits rejected further pages, so the last 5 pages (the prototype-analysis section) were summarized from their mere existence. The skill session read everything. The true cost of full-coverage raw-PDF processing is therefore *higher* than the 69k measured.
- Image rendering also caused environment friction (missing `pdftoppm`, retries) that text conversion sidesteps entirely — reflected in the 50-vs-6 tool-call count.

Caveats: this is a single-document experiment (n=1), and absolute numbers vary with document type. Text-heavy PDFs will show a smaller gap than this image-heavy deck; multi-question workflows over the same document will show a *larger* gap, since the Markdown is converted once and re-read cheaply while a raw PDF pays the image cost on every read. Summary quality was equivalent in both runs — except the skill run also covered the pages the baseline couldn't reach.
