---
name: smart-search
description: >-
  Use when the user wants to SEARCH, LOOK UP, RESEARCH or FIND information:
  "search for", "find out", "look up", "research", "what's the latest on",
  "google it", "check online", "найди", "поищи", "погугли", "поиск", "узнай",
  "что нового", "исследуй", "наведи справку". Governs HOW to search with the
  tools you already have (native web search / fetch, swr for reading): direct
  routes only, a hard budget of max 3 real calls per question, no engine
  re-spam, mandatory Search Balance report. Escalation order: native search →
  swr (Chrome escalation built in) → only if everything failed, say so.
  NOT for reading a known URL (use smart-web-read) and NOT for browser
  automation.
---

# smart-search — direct routes only, spend the budget, report the balance

## Route map (in escalation order — never skip a level)

1. **Native search** (agent's built-in web search / fetch). This is the
   default: no middlemen, fastest, cheapest. If results are readable — done.
2. **`swr <url>`** for every page read and for pages native fetch failed on:
   swr escalates to the real Chrome by itself (Cloudflare, SPA, login walls).
   Do NOT hand-roll curl, do NOT open a headless browser, do NOT ask another
   AI to search for you — that is a middleman, not a source.
3. **Everything failed** (walls + timeouts + swr exit 1): say what is
   unreachable and why, and stop. Do not "route to another AI source" —
   another AI searching for you adds fragility, latency and zero authority.

The user names a site → go there directly (search on that site, or
`swr <site-url>`). No substitutes, no routing tables.

## Budget per question (the only hard rule that matters)

One question = one intent; clarifications and follow-ups do NOT reset it.

- **Max 3 real calls** (searches or page fetches) per question.
- A 2nd call to the same source needs a *changed* query (added time / region
  / language / platform / filter). Same normalized query to the same source
  is always blocked.
- A failed call (error, timeout, captcha, wall) counts as 1 call. No
  infinite retries.
- Budget spent and info still missing → **say what's missing**. Do not
  escalate, do not "just one more search".

## Mandatory Search Balance

End every search-driven answer with this fixed block (compact, 3–5 lines):

```md
**Search Balance**
- native search ×1: "rust async runtimes 2026 comparison"
- swr ×2: docs.rs/tokio (403 → Chrome ok); blog.example.com/post (exit 1, wall)
- budget: 3/3 calls used
```

Rules: every real call appears exactly once with its query/url and count;
skipped steps appear with the skip reason. **No balance block = the search
did not happen properly.** Fix it before answering.

