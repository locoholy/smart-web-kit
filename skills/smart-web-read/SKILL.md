---
name: smart-web-read
description: >-
  READ any web page (docs, articles, blog posts, research, raw JSON API
  endpoints) via the `swr` binary. It tries cheap HTTP fetch first, detects
  SPA shells / Cloudflare / antibot walls / login redirects, and escalates to
  the user's real logged-in Chrome via opencli, then to network JSON capture.
  stdout is ALWAYS clean Markdown or JSON. Triggers: "read this url",
  "open the docs", "what does this page say", "прочитай страницу",
  "открой ссылку". NOT for search (use smart-search), NOT for browser forms.
allowed-tools: Bash(swr:*), Bash(opencli:*), Read
---

# smart-web-read — one command, not a ceremony

## Iron rule

Never improvise web reading (raw `curl` archaeology, headless browsers,
repeated search-by-fragments). Always run `swr`:

```bash
swr <url>          # clean Markdown → stdout, telemetry → stderr
swr --json <url>   # envelope: {url, source, elapsed_ms, content}
```

Read `stdout` only. `swr doctor` says whether Chrome escalation is available.
If `swr` is missing: ask the user to install smart-web-kit
(`git clone <repo> && cd smart-web-kit && npm install -g .`), then run
`swr init` to reproduce this skill. Do NOT fall back to raw `curl`.

## Exit codes → what to do

| code | meaning | action |
|---|---|---|
| 0 | content on stdout | parse and use |
| 1 | page unreadable / real error (404, login wall, Chrome error page) | say so; offer `swr` retry or screenshot |
| 2 | bad usage | fix your arguments |
| 3 | timeout / session busy | retry **once**, then give up |
| 4 | opencli unavailable for escalation | run `swr doctor`; ask the user to fix the bridge |
