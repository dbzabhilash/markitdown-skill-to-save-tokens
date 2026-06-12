#!/usr/bin/env bash
# Convert a document or YouTube URL to Markdown using Microsoft's MarkItDown.
# Usage: convert.sh <input-file-or-url> [output.md]
# Output defaults to <input-basename>.md next to the source file,
# or ./youtube_<video-id>.md for YouTube URLs.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input-file-or-url> [output.md]" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-}"
MARKITDOWN=(uvx --python 3.12 --from "markitdown[all]" markitdown)

is_youtube() {
  [[ "$1" =~ ^https?://(www\.)?(youtube\.com|youtu\.be)/ ]]
}

if [[ -z "$OUTPUT" ]]; then
  if is_youtube "$INPUT"; then
    vid=$(echo "$INPUT" | sed -E 's#.*(v=|youtu\.be/)([A-Za-z0-9_-]{6,}).*#\2#')
    OUTPUT="./youtube_${vid}.md"
  elif [[ -f "$INPUT" ]]; then
    OUTPUT="${INPUT%.*}.md"
  else
    OUTPUT="./output.md"
  fi
fi

"${MARKITDOWN[@]}" "$INPUT" -o "$OUTPUT" 2>/dev/null || true

# YouTube transcript fetches are often blocked; detect a useless result
# (no real content, just page-footer links) and fall back to yt-dlp subtitles.
if is_youtube "$INPUT"; then
  if [[ ! -s "$OUTPUT" ]] || ! grep -qiv 'youtube\.com\|google llc\|^\s*$' "$OUTPUT"; then
    echo "MarkItDown transcript fetch blocked; falling back to yt-dlp subtitles..." >&2
    tmp=$(mktemp -d)
    uvx yt-dlp --skip-download --write-auto-sub --sub-lang en --sub-format vtt \
      -o "$tmp/video" "$INPUT" >&2
    vtt=$(ls "$tmp"/*.vtt 2>/dev/null | head -1)
    if [[ -z "$vtt" ]]; then
      echo "No subtitles available for this video." >&2
      exit 1
    fi
    # Strip VTT headers, timestamps, cue settings, and inline tags; dedupe lines.
    grep -v -E '^(WEBVTT|Kind:|Language:|NOTE)|-->' "$vtt" \
      | sed -E 's/<[^>]*>//g' \
      | awk 'NF && $0 != prev {print; prev=$0}' > "$OUTPUT"
    rm -rf "$tmp"
  fi
fi

if [[ ! -s "$OUTPUT" ]]; then
  echo "Conversion produced an empty file (scanned/image-only PDF? try OCR)." >&2
  exit 1
fi

echo "Saved: $OUTPUT ($(wc -l < "$OUTPUT" | tr -d ' ') lines)"
