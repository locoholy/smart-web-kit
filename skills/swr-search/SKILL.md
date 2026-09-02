---
name: swr-search
description: Use when the user needs a specific lookup, a direct site search, or initial source discovery. Do not use for multi-source research, exhaustive collection, or market comparison; use swr-research.
---

# swr-search — direct lookup and source discovery

Use native search first. When the user names a site, go directly to that site;
use `swr <url>` to read pages that native fetch cannot read. Never hand-roll
curl or launch a second browser.

For discovery, collect candidate sources and their direct URLs. A search snippet
is a lead, not evidence and never enough for a final conclusion.

Never repeat an identical normalized query, URL, filter, or pagination cursor.
There is no fixed call cap: each call must advance the answer by discovering a
source, opening an identified page, or verifying a fact. If the work requires
collecting data from several sources, hand off to `swr-research` before making
claims.

End lookup-driven answers with a compact **Search Balance**: each query or URL,
its outcome, and any source not reached. Do not present a source as checked
when only its snippet was seen.
