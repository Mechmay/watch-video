#!/usr/bin/env bash
# Take the top N of the scan queue, fetch each transcript, and write a partial
# brief JSON per video with everything a machine can know already filled in.
#
# Usage: prep-batch.sh [N] [--queue FILE]
#
# The point of the split: metadata, counts, median and transcript are FACTS and
# should never be retyped by hand -- retyping is how a view count becomes wrong.
# Judgment fields (hook, concept, structure, verdict, claims) are left null on
# purpose; those come from reading, and a script that guessed at them would be
# filling the corpus with fiction.
set -euo pipefail

N="${1:-10}"; case "$N" in --*) N=10 ;; *) [ $# -gt 0 ] && shift || true ;; esac
TAG=""
QUEUE="${TMPDIR:-/tmp}/watch-video/queue.tsv"
while [ $# -gt 0 ]; do
  case "$1" in
    --queue) QUEUE="$2"; shift 2 ;;
    --tag)   TAG="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -f "$QUEUE" ] || { echo "no queue at $QUEUE — run scan-batch.sh first" >&2; exit 3; }

HERE="$(dirname "$0")"
OUT="${TMPDIR:-/tmp}/watch-video"
PARTIALS="$OUT/partials"
[ -n "$TAG" ] && PARTIALS="$OUT/partials-$TAG"
mkdir -p "$PARTIALS"

i=0
# Skip the header row; take the next N.
tail -n +2 "$QUEUE" | head -n "$N" | while IFS=$'\t' read -r xmed views cmed dur vid handle title; do
  i=$((i + 1))
  echo "[$i/$N] $handle  ${xmed}x  $title"
  "$HERE/fetch-video.sh" "https://www.youtube.com/watch?v=$vid" >/dev/null 2>&1 || {
    echo "      FETCH FAILED — skipped"; continue; }
  D="$OUT/Youtube-$vid"
  [ -f "$D/transcript.txt" ] || { echo "      no captions — skipped"; continue; }
  python3 "$HERE/partial.py" "$D" "$cmed" "$xmed" > "$PARTIALS/$vid.json"
  echo "      $(wc -w < "$D/transcript.txt" | tr -d ' ') words -> partials/$vid.json"
done

echo
echo "partials: $PARTIALS"
ls "$PARTIALS"/*.json 2>/dev/null | wc -l | xargs echo "ready to judge:"
