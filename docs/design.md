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
| **Codex** | Live `GET https://chatgpt.com/backend-api/codex/usage`, authed with the OAuth token from `~/.codex/auth.json` (+ `ChatGPT-Account-Id` header) | `rate_limit.primary_window` (5h) + `rate_limit.secondary_window` (weekly), each with `used_percent` and `reset_at` (epoch seconds) | **Revised during implementation (2026-06-02):** originally specced as reading the newest `~/.codex/sessions/**/rollout-*.jsonl`, but that only updates when the Codex CLI runs and lags the live dashboard (observed ~7h stale; web/cloud usage never lands locally). User chose **live-only, no fallback** for accuracy. The endpoint is read-only (does not consume quota). Access token expires ~hourly → refresh on 401 via `https://auth.openai.com/oauth/token` (client_id `app_EMoamEEZ73f0CkXaXp7hrann`, `grant_type=refresh_token`), kept in memory only (auth.json never rewritten). |

**Known constraint — Claude endpoint rate-limits hard:** `/api/oauth/usage` is known to return persistent HTTP 429s if polled frequently. Polling must be conservative and backoff-aware (§4).

**Both providers now hit the network** with undocumented OAuth endpoints (Claude reads its token from Keychain; Codex from `~/.codex/auth.json`). Either can break if the vendor changes things; both fail to `unavailable` ("—") rather than showing wrong/stale numbers.

---

## 3. Architecture

Components are split so each has one purpose, a typed interface, and is independently testable.

- **`UsageSnapshot`** (value type) — `{ fiveHourPct, weeklyPct, fiveHourResetsAt, weeklyResetsAt, asOf, status }` where `status ∈ { ok, stale, unavailable }`. The common currency between providers and UI.

- **`ClaudeUsageProvider`** — reads the OAuth token from Keychain, calls `oauth/usage`, maps the response to a `UsageSnapshot`. Owns its 429 backoff state. Does **not** refresh the token itself (Claude Code keeps it fresh; on 401 we surface `unavailable`).

- **`CodexLiveProvider`** (app target) — reads the OAuth token + account id from `~/.codex/auth.json`, calls `backend-api/codex/usage`, and maps `primary_window`/`secondary_window` to a `UsageSnapshot`. Refreshes the access token on 401 (in memory). The pure JSON→snapshot mapping lives in `CodexUsageResponse` in `BurnrateCore`. *(Originally `CodexUsageProvider`, a local rollout-file reader — replaced; see §2.)*

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
  ~/.codex/auth.json token  │ ┌──────────────────────┐   ┌──────────────────┐
  ──▶ GET backend-api/      └─│ CodexLiveProvider     │   │ MilestoneNotifier │──▶ macOS notifications
      codex/usage (live)      └──────────────────────┘   └──────────────────┘
```

---

## 4. Refresh cadence

- **Claude:** poll `oauth/usage` **every 5 minutes**, never faster. On HTTP 429, exponential backoff (5 → 10 → 20 min, capped) while continuing to display the last good value dimmed. Conservatism is the whole point given the endpoint's aggressive 429 behavior.
- **Codex:** call the live usage endpoint **every 60 seconds**. It's read-only and doesn't consume quota, but 60s keeps the traffic polite. Token refresh happens lazily (only on a 401).
- **Reset countdowns:** the ring shows the time-until-reset from `reset_at`. (v1 recomputes on each refresh tick rather than every second; per-second smoothing is a possible enhancement.)

---

## 5. Errors & edge cases

- **No Keychain token / not signed into Claude Code** → Claude ring shows muted "—" with a "sign in to Claude Code" tooltip; Codex continues to work independently.
- **Claude 429 / network failure** → keep last good value, dimmed, with a "stale" indicator.
- **Claude 401 (token expired/revoked)** → `unavailable` state, prompt to re-auth in Claude Code.
- **No `~/.codex/auth.json` / not signed into Codex** → Codex ring muted "—".
- **Codex token expired** → refresh via the stored refresh token and retry once; if refresh fails → `unavailable` ("—").
- **Codex endpoint error / offline** → `unavailable` ("—"). Per the live-only decision there is no local fallback, so the ring blanks rather than showing a stale number. (The live `used_percent` already reflects post-reset state, so no reset-in-past zeroing is needed.)
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

> **Implementation note (2026-06-02):** the build machine has Command Line Tools only — no Xcode — so neither `XCTest` nor `Testing` is available and `swift test` cannot run. Per decision, the automated test target was dropped. Logic was verified by `swift build` at each step, by running the live provider probes against real data (Codex weekly `used_percent` matched the dashboard), and by running the app. The logic remains split behind protocols/value types, so a standard test target can be added later once Xcode is installed. The plan below is retained as the intended coverage.

- **`CodexUsageResponse`** — mapping the live `rate_limit.primary_window`/`secondary_window` JSON → snapshot; missing fields → 0; `reset_at` → Date.
- **`ClaudeUsageProvider`** — tests against captured `oauth/usage` JSON: happy path mapping, 429 → backoff state machine, 401 → `unavailable`, network error → `stale`.
- **`MilestoneNotifier`** — crossing logic: fires once per threshold, never downward, re-arms on window reset.
- **Color/threshold mapping** — pure function tests.
- **`UsageStore`** — driven by fake providers.
- **`RingView`** — SwiftUI previews with mock snapshots (no heavy UI automation).

---

## 9. Open questions / future work

- ~~Optional live Codex refresh~~ — **implemented 2026-06-02** (the live `backend-api/codex/usage` route is now the only Codex source). It turned out to be a read-only endpoint that does *not* consume quota, so the original "may consume the limit" worry didn't apply.
- **Persist refreshed Codex token?** Currently refreshed in memory only. If hourly refreshes become noticeable, consider writing back to `auth.json` — but carefully, to avoid disrupting Codex's own auth (refresh-token rotation risk).
- **Add a test target** once Xcode is installed (see §8).
- Restyle / alternate layouts — architecture already isolates this to `RingView`.
- Possible later additions: token-volume/cost detail in the expanded view, simple history sparkline, per-second reset countdown smoothing.
