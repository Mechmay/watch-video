#!/usr/bin/env python3
"""Build a partial brief JSON from a fetched workdir.

argv: <workdir> <channel_median> <outperformance>
Facts only. Judgment fields stay null — they come from reading, not from a script.
"""
import json, sys

d = json.load(open(sys.argv[1] + "/info.json", encoding="utf-8"))
transcript = open(sys.argv[1] + "/transcript.txt", encoding="utf-8").read()
up = d.get("upload_date")

print(json.dumps({
    "platform": "youtube",
    "video_id": d["id"],
    "url": d.get("webpage_url"),
    "title": d.get("title"),
    "channel": (d.get("uploader") or d.get("channel") or "").lower(),
    "duration_s": d.get("duration"),
    "posted_at": "%s-%s-%sT00:00:00Z" % (up[:4], up[4:6], up[6:]) if up else None,
    "view_count": d.get("view_count"),
    "like_count": d.get("like_count"),
    "comment_count": d.get("comment_count"),
    "watch_mode": "transcript",
    "transcript_kind": "auto",
    "transcript": transcript,
    "channel_median": int(float(sys.argv[2])),
    "outperformance": round(float(sys.argv[3]), 2),
    "format": "longform",
}, indent=1))
