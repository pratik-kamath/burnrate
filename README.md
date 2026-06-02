# burnrate

A floating macOS overlay showing your **Claude** and **Codex** plan usage as two ring gauges, with notifications at 50/75/90%.

## Why
Claude (claude.ai + Desktop + Claude Code share one quota) and Codex (your ChatGPT plan) both enforce 5-hour and weekly limits but don't surface them well. burnrate keeps both in the corner of your screen.

## How it gets the numbers
- **Claude:** calls the undocumented `https://api.anthropic.com/api/oauth/usage` endpoint using the OAuth token Claude Code stores in your macOS Keychain. Polled every 5 min with backoff (the endpoint 429s if hit too often). First run prompts for Keychain access — choose "Always Allow".
- **Codex:** reads the latest `~/.codex/sessions/**/rollout-*.jsonl`, which already contains the official rate-limit percentages OpenAI returns. No network, no auth.

Neither is an official API; both can break if the vendors change things.

## Build & run
Requires Swift (Command Line Tools are enough — no Xcode needed).

    ./Scripts/make-app.sh
    open burnrate.app

The ring shows the 5-hour window percentage; hover for weekly % and reset countdowns. Right-click the panel for Refresh Now, Notifications toggle, and Quit. Drag it anywhere — position is remembered.

## Architecture
- `BurnrateCore` — UI-free logic: models, `CodexUsageProvider`, `ClaudeUsageProvider` (with `TokenStore`/`HTTPClient` seams), `BackoffPolicy`, `MilestoneNotifier`, `UsageStore`, color thresholds.
- `burnrate` (executable) — AppKit/SwiftUI shell: `OverlayPanel` (always-on-top `NSPanel`), `RingView`, `RefreshCoordinator`, and the real Keychain/URLSession/UserNotifications adapters.

## Tests
There is no automated test suite: the Command Line Tools toolchain on the build machine ships no `XCTest`/`Testing` framework, so `swift test` can't run without installing full Xcode. Logic is verified by building and by running the app against real data. Install Xcode to add a standard test target later — the core logic is already split behind protocols to make that straightforward.

## Not tracked
OpenAI Platform API spend, browser-only chat usage, dollar costs. See `docs/superpowers/specs/2026-06-02-burnrate-design.md`.
