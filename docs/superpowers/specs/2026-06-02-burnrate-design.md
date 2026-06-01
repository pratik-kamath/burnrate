# burnrate — Design Spec

**Date:** 2026-06-02
**Status:** Approved design, pre-implementation
**Goal:** A native macOS floating overlay that shows live usage against your Claude and Codex (ChatGPT) plan rate limits, built primarily to learn macOS/Swift development and to be fully owned/customizable.

---

## 1. Summary

burnrate is a small, draggable, always-on-top floating panel (SwiftUI on an `NSPanel`) showing two **ring gauges** — **Claude** and **Codex**. Each ring's fill represents that provider's **5-hour window usage %**. Hovering a ring reveals the **weekly %** and **reset countdowns**. Rings change color as you approach a limit (green → amber → red). macOS notifications fire as usage crosses 50% / 75% / 90% milestones.

This is a personal, single-user tool for this machine. It is not intended for distribution.

### Non-goals (explicitly out of scope)
- Tracking **OpenAI Platform API** (pay-as-you-go API key) spend — that is a separate billing world from the ChatGPT subscription and does not expose the 5h/weekly window the user cares about.
- Tracking **browser chat** usage (claude.ai / chatgpt.com web) beyond what the shared Claude quota already reflects — there is no local footprint or API for web-only usage.
- Dollar/cost tracking, charts, history, multi-machine sync. (Possible future work, not v1.)
- Distribution / notarization / App Store packaging.

---

## 2. Data sources (and why)

| Provider | Source | What we get | Why this source |
|---|---|---|---|
| **Claude** | `GET https://api.anthropic.com/api/oauth/usage` with the OAuth token from the macOS Keychain (the entry Claude Code maintains) | 5h %, weekly %, reset timestamps | Claude Code transcripts log **tokens only, no rate-limit %**, so the endpoint is the *only* source of the authoritative plan %. Undocumented; shared across claude.ai + Desktop + Claude Code (one quota). |
| **Codex** | Newest `~/.codex/sessions/**/rollout-*.jsonl`, last `rate_limits` event | `primary` (300-min / 5h window) + `secondary` (10080-min / weekly), each with `used_percent` and `resets_at` | The % is computed by OpenAI's backend and returned on each request; Codex **writes the official number to disk**. Reading the file gives the authoritative value with zero network/auth/risk. Only downside is staleness between Codex sessions, which we handle (see §5). |

**Known constraint — Claude endpoint rate-limits hard:** `/api/oauth/usage` is known to return persistent HTTP 429s if polled frequently. Polling must be conservative and backoff-aware (§4).

**Asymmetry to remember:** Claude *must* hit the network (no local %); Codex *must not* (official % already on disk).

---

## 3. Architecture

Components are split so each has one purpose, a typed interface, and is independently testable.

- **`UsageSnapshot`** (value type) — `{ fiveHourPct, weeklyPct, fiveHourResetsAt, weeklyResetsAt, asOf, status }` where `status ∈ { ok, stale, unavailable }`. The common currency between providers and UI.

- **`ClaudeUsageProvider`** — reads the OAuth token from Keychain, calls `oauth/usage`, maps the response to a `UsageSnapshot`. Owns its 429 backoff state. Does **not** refresh the token itself (Claude Code keeps it fresh; on 401 we surface `unavailable`).

- **`CodexUsageProvider`** — finds the newest `rollout-*.jsonl` under `~/.codex/sessions/`, scans for the last `rate_limits` event, maps `primary`/`secondary` to a `UsageSnapshot`. Pure local file read. Applies reset-in-past logic (§5).

- **`UsageStore`** — `ObservableObject` holding the latest `UsageSnapshot` for each provider plus last-updated/error state. Single source of truth for the UI.

- **`RefreshCoordinator`** — owns the timers, calls each provider on its own cadence (§4), writes results into `UsageStore`.

- **`MilestoneNotifier`** — observes `UsageStore`; fires macOS notifications on upward threshold crossings, with per-`(provider, window)` anti-spam state (§7).

- **`OverlayPanel`** — borderless, non-activating `NSPanel`, `.floating` level, transparent background, draggable, position persisted to `UserDefaults`. Hosts the SwiftUI content.

- **`RingView`** — renders one provider's gauge; default shows 5h %, hover expands to weekly % + reset countdowns. The **only** visual component (so restyling never touches data logic).

### 3.1 Data flow

```
                 ┌──────────────────────┐
  Keychain token │ ClaudeUsageProvider   │── GET /api/oauth/usage ──▶ Anthropic
                 └──────────┬───────────┘   (5h%, weekly%, resets)
                            ▼
                    ┌───────────────┐        ┌─────────────┐
   RefreshCoordinator drives ────▶  │  UsageStore   │◀───────│ RingView ×2 │ (SwiftUI)
                    │ (@Published)  │        └─────────────┘
                    └───────▲───────┘
                            │ observed by
  ~/.codex/sessions/*.jsonl │ ┌──────────────────────┐   ┌──────────────────┐
  (newest rollout, last     └─│ CodexUsageProvider    │   │ MilestoneNotifier │──▶ macOS notifications
   rate_limits event)         └──────────────────────┘   └──────────────────┘
```

---

## 4. Refresh cadence

- **Claude:** poll `oauth/usage` **every 5 minutes**, never faster. On HTTP 429, exponential backoff (5 → 10 → 20 min, capped) while continuing to display the last good value dimmed. Conservatism is the whole point given the endpoint's aggressive 429 behavior.
- **Codex:** re-read the newest rollout file **every 30 seconds** (cheap), or watch `~/.codex/sessions` with a `DispatchSource` file-system watcher.
- **Reset countdowns:** recomputed client-side every second from `resets_at`. No I/O or network just to tick a timer.

---

## 5. Errors & edge cases

- **No Keychain token / not signed into Claude Code** → Claude ring shows muted "—" with a "sign in to Claude Code" tooltip; Codex continues to work independently.
- **Claude 429 / network failure** → keep last good value, dimmed, with a "stale" indicator.
- **Claude 401 (token expired/revoked)** → `unavailable` state, prompt to re-auth in Claude Code.
- **No Codex sessions yet** → Codex ring muted "—".
- **Codex window already reset** (`resets_at` in the past) → show **0%** for that window (fresh cycle), not the stale value.
- **Codex staleness** → when the snapshot's `asOf` is older than a few minutes, show a subtle "as of 14m ago" stamp so the number isn't mistaken for live.
- **Color thresholds** (ring color): green `<75%`, amber `75–90%`, red `>90%`, driven off the **higher** of the 5h/weekly percentages so the ring warns on whichever limit you'll hit first.

---

## 6. Overlay UX

- Two ring gauges side by side (Claude = terracotta, Codex/OpenAI = green).
- Default: 5h % shown large in the ring center.
- Hover a ring: expand to show weekly % and both reset countdowns.
- Draggable anywhere; position persisted across launches.
- **Right-click menu:** Refresh now · Toggle weekly-always-visible · Opacity · Notifications on/off · Launch at login · Quit.

---

## 7. Milestone notifications

- Native macOS notifications via `UNUserNotificationCenter`; authorization requested on first launch.
- Fire when usage **crosses upward** through **50% / 75% / 90%**.
  - Example copy: *"Claude 5-hour usage at 75% — resets in 1h 20m."*
- **Anti-spam:** track the highest milestone already fired per `(provider, window)`. Only fire on a new, higher threshold. When a window **resets** (its `resets_at` passes), clear that window's fired-state so the next cycle can notify again.
- Four independent trackers: Claude-5h, Claude-weekly, Codex-5h, Codex-weekly.
- Toggleable from the right-click menu.

---

## 8. Testing strategy

Providers hold the logic; the UI is thin and reads from `UsageStore`.

- **`CodexUsageProvider`** — unit tests against scrubbed real `rollout-*.jsonl` fixtures: parse `rate_limits`, pick the newest file, `resets_at`-in-past → 0%, missing/empty sessions → `unavailable`.
- **`ClaudeUsageProvider`** — tests against captured `oauth/usage` JSON: happy path mapping, 429 → backoff state machine, 401 → `unavailable`, network error → `stale`.
- **`MilestoneNotifier`** — crossing logic: fires once per threshold, never downward, re-arms on window reset.
- **Color/threshold mapping** — pure function tests.
- **`UsageStore`** — driven by fake providers.
- **`RingView`** — SwiftUI previews with mock snapshots (no heavy UI automation).

---

## 9. Open questions / future work

- Optional **live Codex refresh** (replicate ChatGPT OAuth, hit `backend-api/codex`) if staleness becomes annoying — deferred; fragile and may consume the limit just to read it.
- Restyle / alternate layouts — architecture already isolates this to `RingView`.
- Possible later additions: token-volume/cost detail in the expanded view, simple history sparkline.
