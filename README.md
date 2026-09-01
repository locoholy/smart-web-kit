# smart-web-kit

Agent-native web **reading** and **searching** for Claude Code / Antigravity / Cline / any CLI agent.
Two primitives, zero npm dependencies, one install command.

## Why

Agents burn ~80% of their time and context reading the web through raw `curl`
(403s, Cloudflare walls, empty SPA shells) or heavyweight headless browsers
(RAM hogs, custom drivers, no login sessions). `smart-web-kit` gives them:

- **`swr <url>`** — Smart Web Read. One binary. `stdout` is *always* clean
  Markdown or JSON. Cheap HTTP fetch first; on detected failure escalates to
  the user's **real logged-in Chrome** via [OpenCLI](https://opencli.com)
  (Cloudflare already passed, sessions alive), then to network JSON capture.
- **`smart-search`** (skill) — search discipline for agents that already have
  native search: direct routes only (native search → `swr` → say what
  failed), hard budget of max **3 real calls** per question, no engine
  re-spam, mandatory Search Balance report at the end of every answer.
  No "ask another AI" middlemen.

## Install (macOS / Linux)

Prerequisites: `node >= 18`, Chrome.

- **L1 works out of the box** — plain HTTP fetch, no extras needed.
- **Full ladder (L2/L3) + smart-search** need [OpenCLI](https://opencli.com):
  `npm install -g @jackwener/opencli`, then add the **OpenCLI Chrome extension**
  (Chrome Web Store) and check `opencli doctor` — it must say
  `Extension: connected` (without it, Chrome escalation in `swr` cannot run;
  `swr doctor` checks this too).

```bash
git clone https://github.com/<you>/smart-web-kit.git && cd smart-web-kit
npm install -g .          # provides the `swr` binary (L1 works immediately)
# or: ./install.sh        # binary → ~/.local/bin, skills → ~/.claude/skills
#     ./install.sh --project  # also copy skills into ./.claude/skills and ./.agents/skills
```

Then, inside any project an AI agent will work on, wire the agent to `swr`:

```bash
swr init                 # SKILL.md → ./.agents/skills AND ./.claude/skills (one command, both)
swr init --global        # same, into ~/.agents, ~/.claude, ~/.codex, ~/.cursor, ~/.gemini — wires ALL projects on this machine
swr doctor               # "ready" / "not-ready" + exactly what to install (incl. the Chrome extension) for escalation
```

That's it: one install, one command (`swr <url>`), one honest result — any
agent that can run a CLI can use the tool. No per-agent adapters.

## The `swr` escalation ladder

```text
L1  curl (5s)  ──ok──►  HTML → Markdown ──► exit 0
 │ fail score ≥ 1.0 (hard marker: 4xx/5xx, antibot, login wall, JS wall)
 ▼
L2  opencli browser swr-<hash> open → extract (real Chrome, 20s)
 │ DOM extract empty
 ▼
L3  opencli browser ... network → API JSON capture (15s)
 │ nothing found
 ▼
exit 1, stderr explains why
```

Failure detector (Bayesian-ish scoring, escalate at score ≥ 1.0):
any 4xx/5xx (403/404/429/503/...), Cloudflare/DataDome/PerimeterX/captcha,
login wall, "Enable JavaScript" shell, empty SPA shell. A *short valid 200*
(bare JSON API, one-line reply) is NOT a failure — it reads fine on L1.

## Honesty contract (the dot that matters)

`swr` never sells an error as content:

| Input | stdout | exit |
|---|---|---|
| real page / valid JSON | clean Markdown or JSON | 0 |
| 404, 5xx, login wall, captcha wall | **nothing** | 1 |
| unreachable host (Chrome error page) | **nothing** | 1 |
| bad usage / invalid URL | nothing (usage on stderr) | 2 |

Success means *real content was read*. `swr init` + `swr doctor` exist so any
new agent gets wired up in seconds, not per-agent ceremony.

## Reliability guarantees

- **Real 45-second budget**: every L2/L3 step (open/extract/network) is clamped
  to the time actually left, so the total cannot run away.
- **Zero orphan tabs**: `opencli close` runs in `finally`, on SIGINT/SIGTERM,
  and on total-budget timeout. A lockfile (`/tmp/swr-<hash>.lock`) acts as a
  will: the *next* `swr` run detects a dead PID / stale lock (> 10 min) and
  closes the orphan tab of the dead process.
- **Deterministic session isolation**: session id = `sha1(host + path)` —
  query strings never spawn new tabs; one URL → one tab → closed.
- **Concurrency-safe**: parallel `swr` runs on the same URL wait on the lock
  (up to 12 s) instead of racing on the same tab.

## Contract

| Stream | Content |
|---|---|
| `stdout` | clean Markdown (default) or JSON envelope (`--json`): `{url, source, elapsed_ms, content}` |
| `stderr` | one-line telemetry events: `[SWR] L1 fail (HTTP 403) → L2 extract ok (12.3KB, 4.1s)` |

| Exit code | Meaning | Agent action |
|---|---|---|
| 0 | real content on stdout | parse it |
| 1 | page unreadable / real error (404, login wall, error page) | report "page unreadable", offer screenshot fallback |
| 2 | bad usage | fix arguments |
| 3 | timeout / session busy | retry once, then give up |
| 4 | opencli unavailable (escalation needed) | run `swr doctor`, ask user |

Configuration via env: `SWR_TOTAL_BUDGET` (seconds, default 45),
`SWR_L1_TIMEOUT` (seconds, default 5).

## Tests

```bash
./tests/run.sh     # local server, no network/Chrome needed — asserts the
                   # honesty invariants (200/JSON → 0; 404/5xx/wall → 1+empty)
```

## Skills

- [`skills/smart-web-read/SKILL.md`](skills/smart-web-read/SKILL.md) — teaches the agent to *always* use `swr` for URLs.
- [`skills/smart-search/SKILL.md`](skills/smart-search/SKILL.md) — EN/RU search discipline: direct routes, budget enforcement, balance report.

## License

MIT
