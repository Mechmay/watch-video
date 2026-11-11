#!/usr/bin/env bash
# Rank a channel's recent videos against that channel's OWN median, so you
# watch what outperformed instead of whatever the algorithm served you.
#
# Usage: channel-scan.sh <channel-url | any-video-url-from-it> [--last N] [--cookies BROWSER]
#
# WHY. Watching whatever the algorithm happens to serve you gives you a pile of
# random videos, and nothing in a random pile can be called a pattern. Pick
# videos by a rule instead, for $0, using only yt-dlp.
#
# The rule: rank on MEDIAN VIEWS, not on follower count, and always against
# the channel's OWN median -- a 40k-follower
# account pulling 200k views beats a 500k account averaging 8k. Comparing two
# channels' raw view counts measures audience size. Comparing a video to its
# own channel's median measures the VIDEO.
#
# Median, not mean, on purpose: one viral outlier drags a mean up so far that
# every other video looks like a failure.
set -euo pipefail

URL=""; LAST=25; COOKIES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --last)    LAST="$2"; shift 2 ;;
    --cookies) COOKIES="$2"; shift 2 ;;
    -*)        echo "unknown flag: $1" >&2; exit 2 ;;
    *)         URL="$1"; shift ;;
  esac
done
[ -n "$URL" ] || { echo "usage: channel-scan.sh <channel-or-video-url> [--last N] [--cookies BROWSER]" >&2; exit 2; }

command -v yt-dlp >/dev/null || { echo "missing yt-dlp (brew install yt-dlp)" >&2; exit 3; }

YT=(yt-dlp --no-warnings --no-progress)
[ -n "$COOKIES" ] && YT+=(--cookies-from-browser "$COOKIES")

# Accept a video URL and walk up to its channel, so you never have to go find
# the channel page yourself.
case "$URL" in
  *"/watch?v="*|*"youtu.be/"*|*"/video/"*|*"/reel/"*|*"/p/"*)
    CH="$("${YT[@]}" --no-playlist --print "%(channel_url)s" "$URL" 2>/dev/null | head -1)"
    [ -n "$CH" ] && [ "$CH" != "NA" ] && URL="$CH"
    ;;
esac
case "$URL" in *youtube.com/channel/*|*youtube.com/@*) [ "${URL%/videos}" = "$URL" ] && URL="$URL/videos" ;; esac

echo "scanning: $URL (last $LAST)"
RAW="$("${YT[@]}" --flat-playlist --playlist-items "1-$LAST" \
        --print "%(view_count)s|%(duration)s|%(id)s|%(title)s" "$URL" 2>/dev/null || true)"
[ -n "$RAW" ] || { echo "no videos returned — private/blocked, or this site needs --cookies" >&2; exit 4; }

printf '%s\n' "$RAW" | python3 "$(dirname "$0")/rank.py"
