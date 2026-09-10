---
name: swr-search
description: Use when the user needs a specific lookup, a direct site search, or initial source discovery. Do not use for multi-source research, exhaustive collection, or market comparison; use swr-research.
---

# swr-search — direct lookup and source discovery

Use native search first. When the user names a site, go directly to that site;
use `swr <url>` to read pages that native fetch cannot read. Never hand-roll
curl or launch a second browser.

Search and read are two tiers of one loop: native search discovers candidate
URLs, `swr <url>` reads them. A snippet is a lead, not evidence — open the
source before treating a fact as found. Never hand a search-engine results
page (google, duckduckgo, bing) to `swr`: it is a reader with no
search-session cookies, and every such call lands on the antibot wall.

Search until the answer is justified. There is no call cap and no reading
quota: read the sources the answer needs, and keep going while you can name
what is still unknown and how the next step would settle it. When a path
stops paying, change the query, the source, or the way you verify — do not
re-run a query that already came back empty (a retry after a transient
failure is a different thing, and fine). Stop when the claims are backed by
sources you actually opened, or when you can say what could not be
established and why the available paths do not settle it.

Check the contradictions that matter and know what your confidence rests on.
If answering needs data collected across many sources, hand off to
`swr-research`.

When `swr` exits 1 (antibot wall, real error) or 4 (bridge down), name the
broken tier instead of working around it. Exit 4 carries its own fix on
stderr, and that fix is usually "start Google Chrome" — the browser tier
lives inside the user's Chrome, so a closed browser disables it. Relay the
line, do not diagnose past it.
Hand-written HTTP calls, python fetch one-liners, and raw curl are not
fallbacks — they are the symptom of a broken cascade. A dead tier does not
end the lookup: while native search works, keep the search → `swr` read loop
on the candidates it returns. Report the broken tier and what it blocked;
stop only the blocked path.

Name the sources the answer stands on and anything you could not reach. Never
present a source as checked when only its snippet was seen. The full call log
belongs in the transcript, not in the answer.
