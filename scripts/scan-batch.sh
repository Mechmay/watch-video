#!/usr/bin/env bash
# Scan every channel on the YouTube watchlist and merge them into ONE ranked
# watch queue.
#
# Usage: scan-batch.sh --list FILE [--last N] [--min 1.5] [--max X] [--out FILE]
#
# FILE is markdown: channel URLs as the first cell of table rows under a
# "## Channels" heading (see examples/watchlist.md). Or set WATCH_VIDEO_LIST.
#
# WHY RANK ACROSS CHANNELS BY MULTIPLE-OF-MEDIAN. Raw view counts are not
# comparable between channels -- a 300k video on a big channel can be a flop
# and a 40k video on a small one can be its best ever. Every video is scored
# against its OWN channel's median first, and only those scores get merged.
# That is what makes a 20k-view channel as useful to study as a 2M one.
#
# Costs nothing and calls no API: yt-dlp reads public counts. ~5s per channel.
set -euo pipefail

LAST=30
MIN=1.5
MAX=""
OUTFILE=""
LIST="${WATCH_VIDEO_LIST:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --last) LAST="$2"; shift 2 ;;
    --min)  MIN="$2"; shift 2 ;;
    --max)  MAX="$2"; shift 2 ;;
    --out)  OUTFILE="$2"; shift 2 ;;
    --list) LIST="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

command -v yt-dlp >/dev/null || { echo "missing yt-dlp (brew install yt-dlp)" >&2; exit 3; }
[ -n "$LIST" ] && [ -f "$LIST" ] || { echo "pass --list FILE (or set WATCH_VIDEO_LIST); see examples/watchlist.md" >&2; exit 3; }

OUT="${TMPDIR:-/tmp}/watch-video"
mkdir -p "$OUT"
RAW="$OUT/scan-raw.tsv"
: > "$RAW"

# Read only rows under "## Channels" whose first cell is a URL, so other tables
# in the same file (a "Rejected" list, say) are never scanned by accident.
CHANNELS="$(python3 - "$LIST" <<'PY'
import sys, re
inside = False
for line in open(sys.argv[1], encoding='utf-8'):
    st = line.strip()
    if st.startswith('## '):
        inside = st.lower().startswith('## channels')
        continue
    if not inside or not st.startswith('|'):
        continue
    cell = [c.strip() for c in st.strip('|').split('|')][0]
    if cell.startswith('https://'):
        print(cell)
PY
)"
[ -n "$CHANNELS" ] || { echo "watchlist has no channel rows" >&2; exit 4; }

n=0
while IFS= read -r ch; do
  [ -n "$ch" ] || continue
  handle="$(basename "${ch%/videos}")"
  printf 'scanning %-28s ' "$handle"
  rows="$(yt-dlp --no-warnings --no-progress --flat-playlist --playlist-items "1-$LAST" \
            --print "%(view_count)s|%(duration)s|%(id)s|%(title)s" "${ch%/videos}/videos" 2>/dev/null || true)"
  got="$(printf '%s\n' "$rows" | grep -cE '^[0-9]+\|' || true)"
  echo "$got videos"
  printf '%s\n' "$rows" | grep -E '^[0-9]+\|' | sed "s|^|$handle\||" >> "$RAW" || true
  n=$((n + 1))
done <<< "$CHANNELS"

echo
Q="${OUTFILE:-$OUT/queue.tsv}"
python3 "$(dirname "$0")/rank-batch.py" "$RAW" "$MIN" "$Q" ${MAX:+"$MAX"}
