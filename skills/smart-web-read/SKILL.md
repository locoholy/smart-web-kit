---
name: smart-web-read
description: >-
  READ any web page (docs, articles, blog posts, research, raw JSON API
  endpoints) via the `swr` binary. It tries cheap HTTP fetch first, detects
  SPA shells / Cloudflare / antibot walls / login redirects, and escalates to
  the user's real logged-in Chrome via opencli, then to network JSON capture.
  stdout is ALWAYS clean Markdown or JSON. Triggers: "read this url",
  "open the docs", "what does this page say", "прочитай страницу",
  "открой ссылку". NOT for search, NOT for browser forms, NOT for scraping a
  catalog into records — drive the browser with `opencli` for those.
allowed-tools: Bash(swr:*), Bash(opencli:*), Read
---

# smart-web-read — one command, not a ceremony

## Iron rule

Never improvise web reading (raw `curl` archaeology, headless browsers,
repeated search-by-fragments). Always run `swr`:

```bash
swr <url>          # clean Markdown → stdout, telemetry → stderr
swr --json <url>   # {url, final_url, ok, source, elapsed_ms, content}
                   # on failure: {url, ok:false, reason, detail, elapsed_ms}
```

**A whole page is rarely what you need — pipe it.** Bytes that never enter your
context cost nothing, and `swr` has no flags for this on purpose: your shell
already does it better.

```bash
swr <url> | grep -n -A5 -i 'reasoning effort'   # one answer, not the page
swr <url> | grep '^#'                           # the outline: is it worth reading?
swr <url> | head -c 40000                       # cap a page of unknown size
```

Read `stdout` only. `swr doctor` says whether Chrome escalation is available.
If `swr` is missing: ask the user to install smart-web-kit
(`git clone <repo> && cd smart-web-kit && npm install -g .`), then run
`swr init` to reproduce this skill. Do NOT fall back to raw `curl`.

## Where this tool ends

`swr` reads one page and hands back its text. It is not a searcher and not a
scraper:

- **Searching** is your own search tool's job. Never hand a search-engine
  results page to `swr` — it has no search-session cookies and lands on the
  antibot wall. A snippet is a lead, not evidence: open the source before
  treating a fact as found, and never present a page as checked when only its
  snippet was seen.
- **Structured records** — a catalog, a marketplace grid, prices across
  listings — are not reading. Drive the live browser directly
  (`opencli browser <session> open|find|extract`) and pull the fields you need.

## Exit codes → what to do

The exit code says how badly it failed; `--json` says **why**, in one word, so
you do not have to read English prose off stderr to pick your next move. Act on
`reason`: `http-404` is gone for good, `login-wall` needs the user to sign in,
`binary-payload:*` means the URL is a PDF or an archive and no reader will help,
`unreadable` is the only one worth driving the browser for.

| code | meaning | action |
|---|---|---|
| 0 | content on stdout | parse and use |
| 1 | page unreadable / real error (404, login wall, binary payload, Chrome error page) | read `reason`, act per the line above |
| 2 | bad usage | fix your arguments |
| 3 | timeout / session busy | retry **once**, then give up |
| 4 | Chrome bridge down and `swr` could not revive it (it starts Chrome and restarts the daemon on its own) | a human has to act: relay the line stderr printed, verbatim |
