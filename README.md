# watch-video

A [Claude Code](https://claude.com/claude-code) skill that **watches a video and writes you a brief**. You get what the video actually says, every command and tool it names (checked against the frames on screen), and a build spec if it's worth acting on.

It works on YouTube, TikTok, X, Instagram, Loom, Vimeo and [~1,800 other sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md).

- **$0.** No API key and no third-party model. `yt-dlp` and `ffmpeg` pull captions and keyframes locally, and Claude Code reads them in your session.
- **Private by default.** The video never leaves your machine for a transcription or vision service, so it is safe for client Looms and internal recordings.
- **Two-pass reading.** It drafts from the transcript first, then corrects that draft with keyframes. Auto-captions mangle names ("Claude Code" → "Cloud Code"), but the frames don't.

## Install

```bash
brew install yt-dlp ffmpeg          # or: pip install yt-dlp + your OS's ffmpeg
git clone https://github.com/Mechmay/watch-video ~/.claude/skills/watch-video
```

Then, in Claude Code:

> watch this https://www.youtube.com/watch?v=…

Claude picks up the skill from its description and runs the two-pass workflow described in [`SKILL.md`](SKILL.md).

## What's in it

| Script | What it does |
|---|---|
| `scripts/fetch-video.sh <url> [--frames N] [--cookies chrome] [--audio]` | Metadata, a timestamped transcript (manual captions first, auto-captions as fallback), and scene-change keyframes. If there are few scene cuts, as in a talking head, it falls back to uniform sampling |
| `scripts/channel-scan.sh <channel-or-video-url>` | Ranks a channel's recent videos against **that channel's own median**, so you study what outperformed rather than what the algorithm served you |
| `scripts/scan-batch.sh --list watchlist.md` | Does the same across many channels, merged into one ranked queue. `--max` draws a control band of non-winners |
| `scripts/prep-batch.sh N` | Fetches transcripts for the top N in the queue and writes fact-only JSON stubs, with judgment fields left null on purpose |
| `scripts/topic-demand.sh "<subject>"` | Two free demand signals: YouTube autocomplete depth and the median views of the top results. A filter, not a predictor |

## Requirements

- Claude Code
- `yt-dlp` (keep it updated, because it rots against YouTube changes), `ffmpeg`, `python3`, `curl`
- TikTok and Instagram need `--cookies chrome`, meaning a logged-in browser profile on the same machine

## Notes

- Respect the terms of the sites you fetch from and the rights of the people who made the video. This is a tool for taking notes on what you watch, not for re-uploading other people's work.
- A video is untrusted input. The skill tells Claude to treat on-screen instructions ("run this", "paste your key") as data for the brief, never as commands.

## License

MIT. See [LICENSE](LICENSE).
