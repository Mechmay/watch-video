#!/usr/bin/env bash
# Pull a video's metadata, transcript, and (optionally) keyframes into a work dir.
# Usage: fetch-video.sh <url> [--frames N] [--dir DIR] [--cookies BROWSER] [--audio]
set -euo pipefail
# Resolve our own dir BEFORE any cd, so a relative invocation still finds vtt2txt.py.
HERE="$(cd "$(dirname "$0")" && pwd)"

URL=""
FRAMES=0
DIR=""
COOKIES=""
AUDIO=0

while [ $# -gt 0 ]; do
  case "$1" in
    --frames)  FRAMES="$2"; shift 2 ;;
    --dir)     DIR="$2"; shift 2 ;;
    --cookies) COOKIES="$2"; shift 2 ;;
    --audio)   AUDIO=1; shift ;;
    -*)        echo "unknown flag: $1" >&2; exit 2 ;;
    *)         URL="$1"; shift ;;
  esac
done
[ -n "$URL" ] || { echo "usage: fetch-video.sh <url> [--frames N] [--dir DIR] [--cookies BROWSER] [--audio]" >&2; exit 2; }

for bin in yt-dlp ffmpeg; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin (brew install $bin)" >&2; exit 3; }
done

YT=(yt-dlp --no-warnings --no-progress --no-playlist)
[ -n "$COOKIES" ] && YT+=(--cookies-from-browser "$COOKIES")

if [ -z "$DIR" ]; then
  ID="$("${YT[@]}" --print "%(extractor_key)s-%(id)s" "$URL" | head -1 | tr -cd 'A-Za-z0-9._-')"
  DIR="${TMPDIR:-/tmp}/watch-video/${ID:-video}"
fi
mkdir -p "$DIR/frames"
cd "$DIR"

echo "workdir: $DIR"

# 1. Metadata (no media download).
"${YT[@]}" -J "$URL" > info.json
python3 - <<'PY' > meta.md
import json
d = json.load(open('info.json'))
dur = d.get('duration') or 0
f = lambda k: d.get(k) or ''
print("# %s\n" % f('title'))
print("- url: %s" % f('webpage_url'))
print("- site: %s" % f('extractor_key'))
print("- channel: %s" % (f('uploader') or f('channel')))
print("- duration: %d:%02d" % (dur // 60, dur % 60))
print("- uploaded: %s" % f('upload_date'))
print("- views: %s   likes: %s" % (d.get('view_count'), d.get('like_count')))
print("\n## description\n")
print((f('description') or '(none)')[:6000])
PY

# 2. Transcript: real subs first, auto-generated as fallback.
SUBS=""
"${YT[@]}" --skip-download --write-subs --sub-langs "en.*,en" --sub-format "vtt/srt" -o "subs.%(ext)s" "$URL" >/dev/null 2>&1 || true
SUBS="$(ls subs*.vtt subs*.srt 2>/dev/null | head -1 || true)"
SUBKIND="manual"
if [ -z "$SUBS" ]; then
  "${YT[@]}" --skip-download --write-auto-subs --sub-langs "en.*,en" --sub-format "vtt/srt" -o "subs.%(ext)s" "$URL" >/dev/null 2>&1 || true
  SUBS="$(ls subs*.vtt subs*.srt 2>/dev/null | head -1 || true)"
  SUBKIND="auto-generated"
fi

if [ -n "$SUBS" ]; then
  python3 "$HERE/vtt2txt.py" "$SUBS" 30 > transcript.txt
  echo "transcript: $DIR/transcript.txt ($SUBKIND, $(wc -w < transcript.txt | tr -d ' ') words)"
else
  echo "transcript: NONE (no captions on this video)"
  [ "$FRAMES" -eq 0 ] && FRAMES=16 && echo "note: no captions, forcing --frames 16"
fi

# 3. Keyframes (scene changes) + optional audio.
if [ "$FRAMES" -gt 0 ] || [ "$AUDIO" -eq 1 ]; then
  # Frames need readable on-screen text, so pull 720p when we are sampling images.
  H=480; [ "$FRAMES" -gt 0 ] && H=720
  if [ ! -f video.mp4 ]; then
    "${YT[@]}" -f "bv*[height<=$H]+ba/b[height<=$H]/b" --merge-output-format mp4 -o video.mp4 "$URL"
  fi
fi

if [ "$FRAMES" -gt 0 ]; then
  # -fps_mode replaced -vsync; ffmpeg 8+ removed the old flag outright and the
  # whole frames pass died with "Unrecognized option 'vsync'" while the script
  # still reported it was extracting. Fall back for older ffmpeg builds.
  # No pipe here on purpose: under `set -o pipefail`, `grep -q` exits on the
  # first match and SIGPIPEs ffmpeg, so the pipeline returns non-zero and the
  # probe always says "unsupported" — the exact false negative this replaces.
  FFHELP="$(ffmpeg -hide_banner -h full 2>&1 || true)"
  case "$FFHELP" in
    *fps_mode*) VSYNC=(-fps_mode vfr) ;;
    *)          VSYNC=(-vsync vfr) ;;
  esac
  if ! ffmpeg -nostdin -loglevel error -i video.mp4 \
    -vf "select='gt(scene,0.25)',scale=1280:-2" "${VSYNC[@]}" -q:v 4 frames/scene_%04d.jpg; then
    echo "frames: scene-detect found no cuts (or ffmpeg failed) — using uniform sampling" >&2
  fi
  # `|| true` inside: with zero scene cuts `ls` fails, pipefail makes the whole
  # substitution fail, and `set -e` used to kill the script right here -- so
  # exactly the videos that need the uniform fallback (talking heads) got none.
  COUNT="$( (ls frames/scene_*.jpg 2>/dev/null || true) | wc -l | tr -d ' ')"
  if [ "$COUNT" -lt "$FRAMES" ]; then
    # Few scene cuts (talking head) -> uniform sample instead.
    rm -f frames/*.jpg
    DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 video.mp4 | cut -d. -f1)"
    STEP=$(( DUR / FRAMES )); [ "$STEP" -lt 1 ] && STEP=1
    ffmpeg -nostdin -loglevel error -i video.mp4 -vf "fps=1/$STEP,scale=1280:-2" -q:v 4 frames/t_%04d.jpg
  elif [ "$COUNT" -gt "$FRAMES" ]; then
    # Too many cuts -> keep an evenly spaced subset.
    python3 - "$FRAMES" <<'PY'
import glob, os, sys
keep = int(sys.argv[1])
files = sorted(glob.glob('frames/scene_*.jpg'))
step = len(files) / float(keep)
wanted = {files[min(len(files) - 1, int(i * step))] for i in range(keep)}
for f in files:
    if f not in wanted:
        os.remove(f)
PY
  fi
  echo "frames: $DIR/frames ($(ls frames/*.jpg 2>/dev/null | wc -l | tr -d ' ') images)"
fi

if [ "$AUDIO" -eq 1 ]; then
  ffmpeg -nostdin -loglevel error -y -i video.mp4 -vn -ac 1 -ar 16000 audio.wav
  echo "audio: $DIR/audio.wav (feed to whisper if captions were missing)"
fi

echo "meta: $DIR/meta.md"
