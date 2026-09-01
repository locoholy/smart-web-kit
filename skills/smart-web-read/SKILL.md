---
name: smart-web-read
description: >-
  Use when the agent needs to READ a web page (any URL: docs, articles, blog
  posts, research, raw JSON API endpoints). Runs the `swr` binary, which tries
  a cheap HTTP fetch first, detects SPA shells / Cloudflare / antibot walls /
  login redirects, and escalates to the user's real logged-in Chrome via
  opencli, then to network JSON capture. stdout is ALWAYS clean Markdown or
  JSON; stderr carries one-line telemetry. Triggers: "read this url",
  "open the docs", "what does this page say", "прочитай страницу", "открой
  ссылку". NOT for forms/clicks/logged-in flows (use opencli-browser); NOT for
  search routing (use smart-search).
allowed-tools: Bash(swr:*), Bash(opencli:*), Read
---

# smart-web-read — one command, not a ceremony

## Iron rule

Never improvise web reading (raw `curl` archaeology, headless browsers,
repeated search-by-fragments). Always:

```bash
swr <url>          # clean Markdown → stdout, telemetry → stderr
swr --json <url>   # envelope: {url, source, elapsed_ms, content}
```

Read `stdout` only. `stderr` lines like `[SWR] L1 fail (HTTP 403) → L2
extract ok (12.3KB, 4.1s)` tell you *how* the content was obtained — useful
for judging freshness, not for parsing.

## Exit codes → what to do

| code | meaning | action |
|---|---|---|
| 0 | content on stdout | parse and use |
| 1 | L1+L2+L3 all failed | tell the user "page unreadable"; offer a screenshot via `opencli browser swr-<site> screenshot` as last resort |
| 2 | bad usage | fix your arguments |
| 3 | timeout or session busy | retry **once**; if it repeats, give up and say so |
| 4 | opencli unavailable | run `opencli doctor`; ask the user to fix the bridge |

## Escalation ladder (what swr does internally)

1. **L1** — plain HTTP fetch with browser headers, 5 s timeout.
2. **L2** — `opencli browser swr-<hash> open/extract/close` in the user's
   real Chrome (JS rendered, cookies present, Cloudflare already passed).
3. **L3** — if DOM extract is empty (pure SPA): intercept API JSON via
   `opencli browser ... network`.

You never call these levels manually — the binary owns the ladder and
guarantees tab cleanup (finally + signal handlers + stale-lock orphan sweep).

## If `swr` is not installed

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/smart-web-kit/main/install.sh | bash
```

Then verify with `swr --version`. Do NOT fall back to raw `curl` scraping —
install the tool instead.
