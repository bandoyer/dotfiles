# Agents

This is a user-owned clone of Omarchy's Agents plugin with Grok Build usage,
Codex 0.149+ app-server compatibility, subscription status and renewal dates,
and exact local reset dates displayed in 12-hour time. It is based on
[`basecamp/omarchy`](https://github.com/basecamp/omarchy), specifically
`shell/plugins/agents`, and retains Omarchy's MIT license.

The repository contains no credentials, generated usage records, or personal
screenshots. Grok credentials remain managed by the Grok CLI, and live usage
records remain outside the repository in
`~/.local/state/omarchy/agents/usage/`.

## Installation

This complete plugin copy is managed by the parent dotfiles repository. After
reviewing the Chezmoi diff, apply the repository and rescan the shell plugins:

```bash
chezmoi apply -v
omarchy-shell shell rescanPlugins
```

The parent `shell.json` selects `dlb.agents` in the bar. Do not enable
`omarchy.agents` at the same time; this clone replaces it.

To return to the packaged plugin:

```bash
omarchy plugin remove dlb.agents
omarchy plugin enable omarchy.agents
```

The generated records under `~/.local/state/omarchy/agents/usage/` can be left
in place or removed separately; they are runtime state and are never committed
here.

## Validation

Validated locally on August 20, 2026 with Grok CLI 1.0.5:

- all 14 upstream Grok collector fixture tests passed;
- Python, shell, JSON, and Omarchy plugin validation passed;
- isolated wrapper and file-permission tests passed;
- live Grok output matched `/usage`, including its reset timestamp;
- refresh IPC updated Grok and packaged providers;
- all provider panels were visually checked in dark mode, and Grok was also
  checked in light mode.

The Codex compatibility fix was validated on August 21, 2026 with Codex CLI
0.149.0: the upstream collector tests passed, an isolated wrapper run emitted
only a valid Codex record, and a live refresh restored the plan and weekly
limit without an error status.

This is a personal prototype rather than an upstream Omarchy release. No pull
request has been opened from this repository.

One bar icon and one panel for every AI coding subscription on the machine.
The panel is strictly a display: it watches the usage records that
`omarchy-agent-usage-update` writes to `~/.local/state/omarchy/agents/usage/`
and draws whatever appears there. `Panel.qml` owns the bar button and the
popup; `Main.qml` discovers and watches the records (and handles the optional
cross-device aggregation); `Agent.qml` is the per-record file watcher.

## Panel

- **Hero** — the mark, the tool, and the plan it runs on ("Max 20x", "Pro").
  Auth and endpoint problems replace the plan line and repeat in a card.
- **Subscription switch** — one chip per enabled agent (`h`/`l` or click).
  It appears only when more than one agent is enabled.
- **Subscription status** — active, inactive, or unavailable for every agent,
  followed by its exact renewal/end date when the provider exposes one.
  Canceled plans say when access ends; prepaid accounts explicitly say that
  they do not renew. The plugin never guesses from a plan creation date.
- **Limits** — the percentage of each allowance used, a matching meter, the
  local reset date and 12-hour time, and the remaining countdown.
- **Tokens by day** — one row per day for the last week: day, bar, tokens, with today
  bolded at the bottom. Hover today for its prompt and session count.
- **Tokens by model** — tokens per model with the bar behind each row scaled
  to the heaviest model,
  the same way the weekly chart scales to its busiest day. Hover for the
  input / output / cache split.

An enabled agent appears when it has usage or when its collector can make an
explicit active/inactive subscription determination. That keeps inactive
agents visible long enough to say that they are inactive. A future collector
that reports neither status nor usage stays hidden. With one visible agent
there is no switch row. A CLI installed mid-session shows up at the next
refresh, so nothing polls the disk waiting for it. Drop the widget with
`omarchy plugin disable dlb.agents`.

## Data

Each agent is one JSON record in `~/.local/state/omarchy/agents/usage/`,
written by `omarchy-agent-usage-update`. That command runs one
`omarchy-agent-usage-<agent>` collector per agent; the widget invokes it
on its refresh timer and whenever you ask for a refresh, and picks up any
record that lands in the directory regardless of who wrote it.

This user-owned clone runs Claude, Codex, and Grok through the clone-local
`scripts/update` wrapper. Omarchy's packaged Claude collector remains
authoritative for usage; a thin local wrapper adds subscription metadata. The
local Codex copy changes its app-server approval policy from the removed
`untrusted` value to the noninteractive `never` value required by Codex
0.149+; the local Grok collector adds Grok usage and subscription data.

Adding an agent therefore never touches this plugin: ship a collector that
prints the record contract (see the `claude` and `codex` collectors in
`bin/`), and the panel gains a tab. An `assets/<id>.svg` mark is optional —
with an `assets/<id>-light.svg` twin if the mark needs a dark variant for
light surfaces — and the bar glyph stands in when there is none.

| Collector | Subscription | Limits | Local stats |
|---|---|---|---|
| `claude` | Exact current period end, next charge, and scheduled cancellation from Anthropic's signed-in `/subscription_details` response; OAuth profile status is the fallback | Anthropic's OAuth usage endpoint (5-hour session + 7-day weekly) | `~/.claude/projects` transcripts, opencode sessions on an Anthropic provider, plus `stats-cache.json` and `history.jsonl` as fallback |
| `codex` | Exact active/inactive state, current period end, and renewal flag from ChatGPT's signed-in `/backend-api/subscriptions` response | The Codex app-server RPC, launched read-only and noninteractively | native Codex CLI session files (plus pi and opencode sessions) |
| `grok` | Exact active/inactive state, current period end, and cancellation flag from Grok's signed-in `/rest/subscriptions` response | Grok ACP `_x.ai/billing` over `grok agent stdio` | `~/.grok/sessions/*/*/updates.jsonl` completed-turn ledgers |

The subscription object in each generated record is account-local, just like
rate limits and balances: it is never written into cross-device snapshots.
Only status, dates, and boolean cancellation/estimate flags reach the record;
tokens, account IDs, email addresses, and other identity fields do not.

Claude's billing endpoint does not accept Claude Code OAuth tokens. Its
collector therefore reads only `sessionKeyV3` (or the older `sessionKey`) for
`claude.ai` from the default Chromium/Chrome cookie database, decrypts it in
memory through the desktop keyring, and uses it for that read-only request.
The cookie and keyring secret are never logged, cached, or written to a usage
record. Override the browser locations with `CLAUDE_BROWSER_COOKIE_DB` and
`CLAUDE_BROWSER_SAFE_STORAGE_APP` when needed.

Claude limits need a signed-in CLI; without credentials the panel says so and
falls back to local stats only. A non-default Claude directory is honored via
`CLAUDE_CONFIG_DIR`, Codex via `CODEX_HOME`.

## Interactions

- Bar icon: left = panel, right = launch agent, middle = next subscription.
- Panel: `h`/`l` switch subscription, `j`/`k` scroll, `r` or Enter refresh,
  Tab moves to the neighboring bar panel, Esc closes.
- IPC: `omarchy-shell omarchy.agents <open|close|toggle|refresh|next>`.

## Settings

Settings live in the widget's entry in `~/.config/omarchy/shell.json`. The
top-level keys can be set with
`omarchy bar set omarchy.agents <key> <value>`:

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `900` | How often the usage records regenerate |
| `syncMode` | `"Off"` | `"On"` writes this machine's snapshot and merges the others |
| `syncDir` | `""` | A folder synced by Syncthing, Dropbox, rsync, … |
| `syncFileName` | `<hostname>.json` | This machine's snapshot file |
| `syncDeviceId` | hostname | Stable device name inside the snapshot |

Numbers need `--json`, or they land in `shell.json` as strings:

```bash
omarchy bar set omarchy.agents refreshIntervalSec 300 --json
omarchy bar set omarchy.agents syncDir '~/Sync/agent-usage'
```

Per-agent enablement is nested, and `set` writes its key literally rather
than walking a dotted path — so pass the whole `providers` object as JSON (or
edit `shell.json` directly):

```bash
omarchy bar set omarchy.agents providers '{
  "claude": { "enabled": true },
  "codex": { "enabled": false },
  "grok": { "enabled": true }
}' --json
```

`enabled` defaults to `true` for every discovered agent; set it to `false` to
hide a subscription that is installed. Disabled agents are also skipped when
the records regenerate.

With `syncMode` on, every `*.json` snapshot in `syncDir` is merged, so today,
the last 7 days, and the all-time totals cover every machine you code on —
active days are unioned by date rather than summed. Rate limits stay
per-account and are never merged. A record may declare `"scope": "account"`
when its stats are account-global rather than machine-local; those merge by
taking the widest value instead of summing, so the same account synced from
two machines is not counted twice.

One caveat on "all-time": the Codex collector only reads native session files
touched in the last 30 days, so its totals and day counts cover that window.
Claude's cover every transcript still on disk.
