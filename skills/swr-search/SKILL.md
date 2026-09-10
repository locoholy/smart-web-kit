---
name: swr-search
description: Use when the user needs a specific lookup, a direct site search, or initial source discovery. Do not use for multi-source research, exhaustive collection, or market comparison; use swr-research.
---

# swr-search — direct lookup and source discovery

Use native search first. When the user names a site, go directly to that site;
use `swr <url>` to read pages that native fetch cannot read. Never hand-roll
curl or launch a second browser.

Search and read are two tiers of one loop: native search discovers candidate
URLs, `swr <url>` reads them. Collect a batch of candidates from the results
and read each with `swr` before answering; a search snippet is a lead, not
evidence, and never enough for a final conclusion. Never hand a search-engine
results page (google, duckduckgo, bing) to `swr`: it is a reader with no
search-session cookies, and every such call lands on the antibot wall. When
native search fails, reformulate or scope the query; after three fruitless
general queries, scope to the thematic communities of the domain — owner
clubs, vendor and enthusiast forums; narrow hardware, ownership, and parts
questions live there.

Never repeat an identical normalized query, URL, filter, or pagination cursor.
There is no fixed call cap: each call must advance the answer by discovering a
source, opening an identified page, or verifying a fact. If the work requires
collecting data from several sources, hand off to `swr-research` before making
claims.

When `swr` exits 1 (antibot wall, real error) or 4 (bridge down), name the
broken tier instead of working around it. Exit 4 carries its own fix on
stderr, and that fix is usually "start Google Chrome" — the browser tier
lives inside the user's Chrome, so a closed browser disables it. Relay the
line, do not diagnose past it.
Hand-written HTTP calls, python fetch one-liners, and raw curl are not
fallbacks — they are the symptom of a broken cascade. A dead tier does not
end the lookup: while native search works, keep the search → `swr` read loop
on the candidates it returns. Report the broken tier, what it blocked, and
the **Search Balance**; stop only the blocked path.

End lookup-driven answers with a compact **Search Balance**: each query or URL,
its outcome, and any source not reached. Do not present a source as checked
when only its snippet was seen.
