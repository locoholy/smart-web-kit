# smart-web-kit

Agent-native web reading for Claude Code / Antigravity / Cline / any CLI
agent. One primitive, zero npm dependencies, one install command.

## Why

Agents burn ~80% of their time and context reading the web through raw `curl`
(403s, Cloudflare walls, empty SPA shells) or heavyweight headless browsers
(RAM hogs, custom drivers, no login sessions). `smart-web-kit` gives them:

- **`swr <url>`** — Smart Web Read. One binary. `stdout` is *always* clean
  Markdown or JSON. Cheap HTTP fetch first; on detected failure escalates to
  the user's **real logged-in Chrome** via [OpenCLI](https://opencli.com)
  (Cloudflare already passed, sessions alive), then to network JSON capture.
- **`smart-web-read`** (skill) — teaches the agent to reach for `swr` on every
  URL, and where the tool ends: searching is the agent's own search tool, and
  scraping a catalog into records is a job for driving `opencli` directly.

## Install (macOS / Linux)

Prerequisites: `node >= 18` at runtime, Chrome.

- **L1 works out of the box** — plain HTTP fetch, no extras needed.
- **Full ladder (L2/L3)** needs [OpenCLI](https://opencli.com):
  `npm install -g @jackwener/opencli`, then add the **OpenCLI Chrome extension**
  (Chrome Web Store) and check `opencli doctor` — it must say
  `Extension: connected` (without it, Chrome escalation in `swr` cannot run;
  `swr doctor` checks this too). The extension runs **inside** Chrome, so the
  ladder is only live while Chrome itself is open. `swr` handles that itself:
  before escalating it checks the bridge, starts Chrome and restarts the
  daemon if needed, and only then gives up (`SWR_BRIDGE_REPAIR=off` to
  disable, `no-launch` to allow everything but starting Chrome).

```bash
git clone https://github.com/locoholy/smart-web-kit.git && cd smart-web-kit
./install.sh              # builds a standalone binary into ~/.local/bin, then runs `swr init`
./install.sh --link       # development: symlink tools/swr from this checkout instead
```

`install.sh` compiles `tools/swr` plus the skill text into one executable
(`bun` is a build-time dependency only: `brew install oven-sh/bun/bun`). The
installed `swr` is a real binary, not a link into the clone, and it carries the
skill inside it — so it keeps working after you move or delete the checkout, and
`swr init` needs no repository on the machine.

```bash
swr init                 # SKILL.md → ~/.agents/skills + every agent root you already have
swr doctor               # "ready" / "not-ready" + exactly what to install (incl. the Chrome extension) for escalation
swr doctor --skills      # per-root status: synced, stale, modified, or missing
```

`init` writes to `~/.agents/skills` and to any of `~/.claude`, `~/.codex`,
`~/.cursor`, `~/.gemini`, `~/.cline` that already exist — it never creates a
root for an agent you do not run. A copy left behind in one of those roots
wins over the canonical one inside that agent, so a root left unsynced is a
root quietly serving an old skill; `doctor --skills` checks all of them.

That's it: one install, one command (`swr <url>`), one honest result — any
agent that supports Agent Skills can use the tool. No project-local copies or
per-agent adapters.

### The version stamp

`init` writes one extra line into the frontmatter of every copy it deploys:

```yaml
version: 1.7.1+swr
```

The number comes from `package.json` at build time, so a release cannot deploy
a stamp it does not own. That line is what lets `doctor --skills` tell a copy
from an older release (`STALE`) apart from a copy someone edited by hand
(`MODIFIED`) apart from a copy predating stamping (`UNSTAMPED`), instead of
just reporting "differs".

## The `swr` escalation ladder

```text
L1  curl (15s)  ──ok──►  HTML → Markdown ──► exit 0
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
| `stdout` | clean Markdown (default) or JSON envelope (`--json`): `{url, final_url?, ok, source, truncated, elapsed_ms, content}` — `truncated:true` means the page was cut (over 2 MB or out of budget); it is never cut silently |
| `stderr` | one-line telemetry events: `[SWR] L1 fail (HTTP 403) → L2 extract ok (12.3KB, 4.1s)` |

| Exit code | Meaning | Agent action |
|---|---|---|
| 0 | real content on stdout | parse it |
| 1 | page unreadable / real error (404, login wall, error page) | report "page unreadable", offer screenshot fallback |
| 2 | bad usage | fix arguments |
| 3 | timeout / session busy | retry once, then give up |
| 4 | Chrome bridge down and unrepairable (`swr` starts Chrome and restarts the daemon first) | relay the line stderr printed — a human has to act |

Configuration via env: `SWR_TOTAL_BUDGET` (seconds, default 45),
`SWR_L1_TIMEOUT` (seconds, default 15), `SWR_BROWSER_WINDOW`
(`background` by default; `foreground` only when requested), and
`SWR_BROWSER=off` for L1-only runs, `SWR_BRIDGE_REPAIR` (`on` / `no-launch` / `off`).

## Tests

```bash
./tests/run.sh                              # local server + fake OpenCLI; no network/Chrome/focus change
SWR="$HOME/.local/bin/swr" ./tests/run.sh   # the same suite against the installed binary
```

## Skills

- [`skills/smart-web-read/SKILL.md`](skills/smart-web-read/SKILL.md) — teaches the agent to *always* use `swr` for URLs, and where the tool ends.

`init` also removes skills this kit used to ship (`swr-search`, `swr-research`)
from every root, so a retired copy cannot keep being loaded.

## License

MIT
