#!/usr/bin/env python3
"""Rank `views|duration|id|title` lines from stdin against their own median."""
import sys, statistics

rows = []
for line in sys.stdin:
    p = line.rstrip("\n").split("|", 3)
    if len(p) < 4:
        continue
    v, d, vid, title = p
    if not v.isdigit():          # members-only / premiere / no public count
        continue
    rows.append((int(v), int(d) if d.isdigit() else 0, vid, title))

if not rows:
    print("no public view counts on this platform — median ranking not possible")
    sys.exit(4)

med = statistics.median(r[0] for r in rows)
print("\nvideos with public counts: %d   channel median: %s views" % (len(rows), format(med, ",.0f")))
print("NOTE: YouTube rounds public counts (26,000 not 26,431). Fine for ranking, never quote as exact.\n")
print("%9s  %9s  %6s  %s" % ("x median", "views", "len", "url  title"))
print("-" * 96)
for v, d, vid, title in sorted(rows, key=lambda r: -r[0]):
    mark = "  <-- watch" if v >= med * 1.5 else ""
    print("%8.2fx  %9s  %4d:%02d  https://youtu.be/%s  %s%s"
          % (v / med, format(v, ","), d // 60, d % 60, vid, title[:44], mark))
hits = sum(1 for r in rows if r[0] >= med * 1.5)
print("\n%d video(s) at 1.5x median or better — those are the ones worth watching." % hits)
print("Pass channel_median=%.0f into the brief JSON so outperformance is stored, not recomputed." % med)
