#!/usr/bin/env python3
"""VTT/SRT -> timestamped plain text. Stdlib only. Run with python3."""
import re, sys

TS = re.compile(r'(\d{2}):(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})')
TAG = re.compile(r'<[^>]+>')

def secs(h, m, s):
    return int(h) * 3600 + int(m) * 60 + int(s)

def main(path, every=30):
    cues = []
    start = None
    buf = []
    for raw in open(path, encoding='utf-8', errors='replace'):
        line = raw.rstrip('\n')
        m = TS.search(line)
        if m:
            if start is not None and buf:
                cues.append((start, buf))
            start = secs(*m.groups()[:3])
            buf = []
            continue
        line = TAG.sub('', line).strip()
        if not line or line == 'WEBVTT' or line.isdigit():
            continue
        if line.startswith(('Kind:', 'Language:', 'NOTE ')):
            continue
        buf.append(line)
    if start is not None and buf:
        cues.append((start, buf))

    # YouTube auto-captions roll: each cue repeats the tail of the previous one.
    out = []
    seen = []
    for t, lines in cues:
        for ln in lines:
            if ln in seen[-6:]:
                continue
            seen.append(ln)
            out.append((t, ln))

    last_stamp = -every
    for t, ln in out:
        if t - last_stamp >= every:
            sys.stdout.write('\n[%02d:%02d] ' % (t // 60, t % 60))
            last_stamp = t
        sys.stdout.write(ln + ' ')
    sys.stdout.write('\n')

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 30)
