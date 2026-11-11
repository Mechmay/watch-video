#!/usr/bin/env python3
"""Merge per-channel scans into one queue ranked by multiple-of-own-median.

argv: <raw.tsv> <min_multiple> <out.tsv> [max_multiple]

With max_multiple, keeps the band [min, max] instead of everything above min.
That is how the CONTROL group is drawn: same channels, same last-30 window
(so era is roughly matched), same extraction — only the outcome differs.
A corpus selected purely on winning cannot explain winning.
"""
import sys, statistics
from collections import defaultdict

raw, minx, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
maxx = float(sys.argv[4]) if len(sys.argv) > 4 else None

by = defaultdict(list)
for line in open(raw, encoding="utf-8"):
    p = line.rstrip("\n").split("|", 4)
    if len(p) < 5 or not p[1].isdigit():
        continue
    handle, v, d, vid, title = p
    by[handle].append((int(v), int(d) if d.isdigit() else 0, vid, title))

if not by:
    print("nothing scanned")
    sys.exit(4)

merged = []
print("%-28s %8s %8s %s" % ("channel", "videos", "median", "spread (min-max)"))
print("-" * 78)
for handle, rows in by.items():
    med = statistics.median(r[0] for r in rows)
    lo, hi = min(r[0] for r in rows), max(r[0] for r in rows)
    print("%-28s %8d %8s %s - %s" % (handle, len(rows), format(int(med), ","), format(lo, ","), format(hi, ",")))
    for v, d, vid, title in rows:
        # Score against the channel's OWN median before merging. Without this,
        # the queue is just a list of the biggest channel's videos.
        merged.append((v / med, v, med, d, vid, title, handle))

merged.sort(key=lambda r: -r[0])
keep = [m for m in merged if m[0] >= minx and (maxx is None or m[0] <= maxx)]
if maxx is not None:
    keep.sort(key=lambda r: r[0])   # worst first when drawing a control band

with open(out, "w", encoding="utf-8") as fh:
    fh.write("x_median\tviews\tchannel_median\tduration_s\tvideo_id\thandle\ttitle\n")
    for x, v, med, d, vid, title, handle in keep:
        fh.write("%.2f\t%d\t%d\t%d\t%s\t%s\t%s\n" % (x, v, med, d, vid, handle, title))

band = ("between %.2fx and %.2fx" % (minx, maxx)) if maxx is not None else ("at %.1fx or better" % minx)
print("\n%d of %d videos %s their own channel median\n" % (len(keep), len(merged), band))
print("%8s %9s %7s  %-26s %s" % ("x median", "views", "len", "channel", "url  title"))
print("-" * 112)
for x, v, med, d, vid, title, handle in keep[:25]:
    print("%7.2fx %9s %4d:%02d  %-26s https://youtu.be/%s  %s"
          % (x, format(v, ","), d // 60, d % 60, handle[:26], vid, title[:40]))

# A queue full of one channel teaches that channel, not the format.
from collections import Counter
mix = Counter(m[6] for m in keep[:25])
print("\ntop-25 mix:", dict(mix))
print("queue written: %s" % out)
