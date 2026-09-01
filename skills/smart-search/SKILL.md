---
name: smart-search
description: >-
  Use when the user wants to SEARCH, LOOK UP, RESEARCH or FIND information:
  "search for", "find out", "look up", "research", "what's the latest on",
  "google it", "check online", "найди", "поищи", "погугли", "поиск", "узнай",
  "что нового", "исследуй", "наведи справку". Routes each query to the best
  live source through opencli (Gemini, Grok, Perplexity, GitHub,
  StackOverflow, Kagi, Google, ...) enforcing a hard budget: max 1 AI source
  + 1-2 vertical sources per question, no engine re-spam on empty results.
  Ends every answer with a mandatory Search Balance report. NOT for reading a
  known URL (use smart-web-read) and NOT for browser automation (use
  opencli-browser).
---

# smart-search — route once, spend the budget, report the balance

## Iron rules

1. **Live pre-check** before the first search of a session:
   - `opencli list -f yaml` → confirm which sources actually exist; check
     `strategy` / `browser` / `domain` fields.
   - `opencli <site> -h` → real subcommands and flags. Never trust hardcoded
     signatures — this file routes, live help defines syntax.
2. **Budget per question** (one question = one intent; clarifications and
   follow-ups do NOT reset it):
   - AI source: **exactly 1 call**. Never a second call, even with a reworded
     query.
   - Vertical source: **max 2 calls**; the 2nd only with a *changed* query
     (added time / region / language / platform / filter).
   - Same normalized query to the same source is always blocked. An empty
     result means "change the SOURCE, not re-spam the same engine".
   - A failed call (error, timeout, captcha, login wall) counts as 1 call.
     No infinite retries.
3. Budget spent and info still missing → **say what's missing**. Do not
   escalate, do not "just one more search".

## Routing: 1 AI source + 1–2 verticals

| Intent (detected by) | AI (1) | Vertical 1 | Vertical 2 |
|---|---|---|---|
| Error / stack trace: `/error\|exception\|stack ?trace\|traceback/i` | gemini | stackoverflow | github |
| Code / library: `/github\|library\|sdk\|npm\|pip\|package\|api doc/i` | — | github | stackoverflow |
| News / real-time: `/news\|latest\|today\|breaking\|сейчас\|новости\|последн/i` | grok | google | — |
| Research with citations: `/research\|sources\|compare\|источники\|сравн/i` | perplexity | kagi | — |
| Hard query everything else failed on | kagi | — | — |
| Default (no match) | gemini | — | — |

- If the user names a site — use it. No routing, no substitutes.
- AI source choice: **gemini** (default, global), **grok** (real-time, X/Twitter
  context), **perplexity** (answer must carry citations).
- The user's language does NOT change routing. Answer in the user's language;
  query sources in the language that yields the best data (usually EN;
  RU-context queries may stay RU).

## Query construction (AI sources)

`<subject> + <question to answer> + <limits: time / region / language / platform>`

Bad: `rust async`. Good: `rust async runtime 2026 — tokio vs smol performance comparison`.
Never a bare noun. Never a hot-topic question without a time range.

## Handling unavailable sources

- One source failing does not abort the search. Record it, fall back to a
  same-class source (vertical → another vertical; AI → the default AI).
- Only trust `opencli list -f yaml` for availability. No source is "always up".

## Mandatory Search Balance

End every search-driven answer with this fixed block (compact, 3–5 lines):

```md
**Search Balance**
- gemini ×1: "rust async runtimes 2026 comparison"
- stackoverflow ×2: "tokio select! borrow error"; "tokio select borrow node:lang" (2nd: narrowed to node)
- github ×0 (skipped: covered by AI source)
- budget: 3/4 calls used
```

Rules: every real call appears exactly once with its query and count;
skipped sources appear with the skip reason; pre-checks (`opencli list`,
`-h`) are free and never listed. **No balance block = the search did not
happen properly.** Fix it before answering.
