#!/usr/bin/env bash
# Score whether people are ALREADY asking about a subject, before you make
# anything about it.
#
#   topic-demand.sh "how mrna vaccines"
#   topic-demand.sh --file subjects.txt
#
# WHY THIS EXISTS. In the author's own blind tests (n=48 videos, 2026), what a
# video is ABOUT predicted whether it beat its channel median about as well as
# how it was MADE (both ~67%). Topic is half the signal and it is the half you
# can check before you film anything. So check it.
#
# TWO FREE SIGNALS, neither needing an API key:
#   demand   -- YouTube autocomplete suggestion count for the phrase. These are
#               real queries people typed. A subject nobody asks about returns
#               only the echo of what you typed.
#   payout   -- median views of the top search results. High demand with low
#               payout means people ask and nobody watches; both must be there.
#
# It measures ATTENTION, not whether the subject is worth your time. A topic
# can be in demand and still be a bad thing to build a channel on.
set -euo pipefail

score_one() {
  local q="$1" enc sugg n med
  enc="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$q")"

  sugg="$(curl -s --max-time 15 "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=$enc" || echo '[]')"
  # Count suggestions, not counting an exact echo of the query itself -- an
  # echo means YouTube had nothing to offer.
  n="$(printf '%s' "$sugg" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print(0); raise SystemExit
q=d[0].strip().lower()
print(len([s for s in d[1] if s.strip().lower()!=q]))')"

  med="$(yt-dlp --no-warnings --no-progress --flat-playlist "ytsearch8:$q" \
          --print "%(view_count)s" 2>/dev/null \
        | python3 -c '
import sys,statistics
v=[int(x) for x in sys.stdin.read().split() if x.isdigit()]
print(int(statistics.median(v)) if v else 0)')"

  # Verdict is deliberately coarse. Two signals, three buckets; anything finer
  # would be false precision on a proxy.
  local verdict
  if   [ "$n" -ge 7 ] && [ "$med" -ge 100000 ]; then verdict="STRONG   people ask, and the asking pays"
  elif [ "$n" -ge 7 ];                          then verdict="ASKED    demand exists, top results underperform"
  elif [ "$med" -ge 100000 ];                   then verdict="CROWDED  big views, few distinct queries"
  else                                               verdict="DEAD     nobody is asking"
  fi
  printf '%-42s %5s %12s   %s\n' "${q:0:42}" "$n" "$(printf "%'d" "$med" 2>/dev/null || echo "$med")" "$verdict"
}

printf '%-42s %5s %12s   %s\n' "subject" "sugg" "median views" "verdict"
printf '%s\n' "----------------------------------------------------------------------------------------------"

if [ "${1:-}" = "--file" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && [ "${line#\#}" = "$line" ] && score_one "$line"
  done < "$2"
else
  [ $# -gt 0 ] || { echo "usage: topic-demand.sh \"<subject>\" | --file <list>" >&2; exit 2; }
  for q in "$@"; do score_one "$q"; done
fi
