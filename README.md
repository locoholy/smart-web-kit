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
- **`smart-search`** (skill) — search router with a hard budget: max **1 AI
  source + 1–2 vertical sources** per question, no engine re-spam, mandatory
  Search Balance report at the end of every answer.

## Install (macOS / Linux)

Prerequisites: `node >= 18`, Chrome, [OpenCLI](https://opencli.com) installed and authorized (`opencli doctor`).

```bash
git clone https://github.com/<you>/smart-web-kit.git && cd smart-web-kit
./install.sh              # binary → ~/.local/bin, skills → ~/.claude/skills
./install.sh --project    # additionally copy skills into ./.claude/skills and ./.agents/skills
# or via npm:
npm install -g .          # provides the `swr` binary
```

## The `swr` escalation ladder

```
L1  curl (5s)  ──ok──►  HTML → Markdown ──► exit 0
 │ fail score ≥ 1.0
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

| Signal | Score |
|---|---|
| HTTP 403 / 429 / 503 | 1.0 |
| Cloudflare / DataDome / PerimeterX / captcha markers | 1.0 |
| `Enable JavaScript` wall | 0.6 |
| SPA shell (`id="root"/__next/__nuxt/app`) with < 200 chars of text | 0.6 |
| login wall ("Sign in to continue") | 0.5 |
| 200 OK with body < 500 B and no text | 0.5 |

## Reliability guarantees

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
| 0 | content on stdout | parse it |
| 1 | all levels failed | report "page unreadable", offer screenshot fallback |
| 2 | bad usage | fix arguments |
| 3 | timeout / session busy | retry once, then give up |
| 4 | opencli unavailable | run `opencli doctor`, ask user |

Configuration via env: `SWR_TOTAL_BUDGET` (seconds, default 45),
`SWR_L1_TIMEOUT` (seconds, default 5).

## Skills

- [`skills/smart-web-read/SKILL.md`](skills/smart-web-read/SKILL.md) — teaches the agent to *always* use `swr` for URLs.
- [`skills/smart-search/SKILL.md`](skills/smart-search/SKILL.md) — EN/RU search routing with budget enforcement.

## License

MIT
