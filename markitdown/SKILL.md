---
name: markitdown
description: Convert documents (PDF, Word, PowerPoint, Excel, CSV, HTML, EPUB, images, audio, ZIP, Outlook .msg, Jupyter notebooks) and YouTube URLs to clean Markdown using Microsoft's MarkItDown library, then work on the Markdown instead of the raw file to save tokens. ALWAYS use this skill when the user invokes /markitdown, says "convert to markdown" or "markdownify", mounts/uploads/points to a document file and wants it summarized, analyzed, extracted, or transformed, or pastes a YouTube URL wanting its transcript or content. Trigger even if the user doesn't say "markdown" — any task that requires reading the contents of a PDF/Office/EPUB file should go through this conversion first.
---

# MarkItDown — document to Markdown conversion

Convert a document to Markdown once, then perform the user's actual task (summarize, extract, rewrite, answer questions) against the Markdown file. Never try to read PDF/Office binaries directly — the conversion is dramatically cheaper in tokens and more reliable.

## Core command

The bundled script handles everything below — output naming, the YouTube fallback, and empty-output detection — so prefer it for single conversions:

```bash
bash <skill-dir>/scripts/convert.sh <input-file-or-url> [output.md]
```

For batch jobs or custom flags, call MarkItDown directly. It is not installed system-wide; run it through `uvx` (isolated, cached after first run). Pin Python 3.12 for dependency compatibility:

```bash
uvx --python 3.12 --from "markitdown[all]" markitdown <input-file> -o <output.md>
```

- Always use `-o` to write to a file rather than piping stdout — the tool emits harmless warnings on stderr and stdout piping mixes them in.
- Write outputs next to the source file as `<basename>.md`, unless the user asks for a different location. If the source directory isn't writable (e.g., a read-only mount), write to the current working directory or `/tmp` and tell the user where.
- The first run downloads dependencies (~30s); later runs are instant. Use a generous Bash timeout (120s+) on the first conversion.

## Supported inputs

PDF, .docx, .pptx, .xlsx/.xls, .csv, HTML, EPUB, images (EXIF + OCR), audio (.wav/.mp3, speech transcription), ZIP (iterates contents), Outlook .msg, Jupyter .ipynb, plain text/JSON/XML.

**YouTube URLs** work as input directly — MarkItDown fetches the title, metadata, and transcript:

```bash
uvx --python 3.12 --from "markitdown[all]" markitdown "https://www.youtube.com/watch?v=VIDEO_ID" -o video.md
```

Quote the URL (the `?` and `&` break the shell otherwise).

YouTube sometimes blocks transcript requests (you'll see `Attempt N failed` on stderr and the output will be just page-footer links instead of a transcript). When that happens, fall back to yt-dlp for subtitles and convert those:

```bash
uvx yt-dlp --skip-download --write-auto-sub --sub-lang en --sub-format vtt -o "/tmp/yt_video" "URL"
# then strip the VTT timestamps/cues to plain text for the .md
```

Always check the output actually contains a transcript before declaring success.

## Workflow

1. **Locate the input.** If the user mounted/uploaded a file, find its actual path first (check the working directory, mount paths mentioned in context, or `ls` likely locations). If they gave a URL, use it directly.
2. **Convert** with the core command above.
3. **Sanity-check the output**: `wc -l` plus reading the first ~50 lines. If it's empty or garbled (common with scanned/image-only PDFs), tell the user and suggest OCR alternatives rather than silently proceeding.
4. **Do the user's actual task using the Markdown file.** For large outputs, don't read the whole file into context — `grep` for relevant sections or Read with offset/limit, pulling in only what the task needs. This is the entire point of the skill: the Markdown is now the working copy.
5. **Report**: tell the user where the .md file was saved and then deliver the requested result.

If the user only says "convert this" with no follow-up task, just convert, verify, and report the output path with a one-line description of what's inside.

## Batch conversion

For multiple files, loop rather than invoking uvx per-file in separate turns:

```bash
for f in /path/to/docs/*.pdf; do
  uvx --python 3.12 --from "markitdown[all]" markitdown "$f" -o "${f%.*}.md"
done
```

## Troubleshooting

- **Audio files fail or warn about ffmpeg**: speech transcription needs ffmpeg (`brew install ffmpeg`). Ask before installing.
- **Scanned PDFs come out empty**: MarkItDown extracts the text layer only; a pure-image PDF has none. Say so and offer an OCR route instead.
- **Very large spreadsheets**: every cell becomes a Markdown table row. If the .md is huge, consider converting only the needed sheet or summarizing with `head`/`grep` instead of full reads.
- **Network-restricted environments**: YouTube and URL inputs need outbound network access; local files don't.
