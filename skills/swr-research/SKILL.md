---
name: swr-research
description: Use when the user asks to research, compare, inventory, scan marketplaces, find every relevant option, or investigate a topic across multiple sources and pages.
---

# swr-research — collect before judging

Research is a data-collection job, not a sequence of search snippets. `swr`
reads one URL; this skill controls the queue of sources and preserves the
dataset for analysis.

## Procedure

1. State the research question and record constraints as fields to evaluate
later. Do not filter during collection.
2. Discover candidate sources with native search, named sites, and links found
in evidence. Add each canonical source URL once to a queue.
3. For every source, prefer its catalog, native search, sitemap, API, and
pagination/cursors over a search engine. Read every reachable result page.
4. Retain every raw record and source URL. Record missing fields as `unknown`;
do not infer a subscription, price, duration, or seller type.
5. Normalize only after collection: currency, time period, product variant,
seller, availability, and duplicates. Then give the complete dataset to the
LLM for sorting, filtering, and comparison.

Do not use `head`, first-screen snippets, or early price filters as evidence.
Do not repeat a canonical URL, identical query, filter, or cursor. Google is a
discovery fallback, never the primary catalog.

Stop only when the source queue and every reachable pagination chain are
exhausted, or when the user-defined time/cost limit is reached. In a partial
result, list unvisited sources and why; never call it exhaustive.

Return the raw dataset or a compact table with source URL for every record,
then answer the user's selection question from that dataset. Include a
**Research Balance**: sources discovered, sources fully collected, records
retained, and unfinished work.
