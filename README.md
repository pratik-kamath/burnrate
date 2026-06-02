# burnrate

A floating, always-on-top macOS overlay showing your **Claude** and **Codex** plan usage as two ring gauges, with desktop notifications at 50 / 75 / 90%.

The ring center shows the **5-hour window** percentage; hover a ring for the **weekly** percentage and reset countdowns. The ring turns amber above 75% and red above 90%. Drag the panel anywhere (its position is remembered). Right-click it for **Refresh Now**, a **Notifications** toggle, and **Quit**.

## Why
Claude (claude.ai + Desktop + Claude Code all share one quota) and Codex (your ChatGPT plan) both enforce rolling 5-hour and weekly limits, but neither surfaces them well while you work. burnrate keeps both in the corner of your screen.

## How it gets the numbers
Both providers are read live from **undocumented** OAuth endpoints, using credentials the official CLIs already store on your machine:

- **Claude:** `GET https://api.anthropic.com/api/oauth/usage`, authed with the OAuth token Claude Code keeps in your macOS **Keychain** (item `Claude Code-credentials`). Polled every **5 minutes** with backoff — this endpoint rate-limits (HTTP 429) aggressively if hit too often, so polling is deliberately conservative.
- **Codex:** `GET https://chatgpt.com/backend-api/codex/usage`, authed with the token in **`~/.codex/auth.json`** (refreshed automatically when it expires). Read-only — it does **not** consume your quota. Polled every **60 seconds**.

Neither is an official API. Both can break if Anthropic or OpenAI change things; when that happens the affected ring shows `—` rather than a wrong number.

---

## Run it on your own Mac

### Requirements
- **macOS 13+**
- **Swift toolchain.** Xcode is *not* required — the Xcode **Command Line Tools** are enough:
  ```sh
  xcode-select --install      # if `swift --version` doesn't already work
  ```
- **Signed into [Claude Code](https://www.claude.com/product/claude-code)** with a Claude Pro/Max plan (this is what populates the Claude ring). Run `claude` once and sign in if you haven't.
- **Signed into the [Codex CLI](https://developers.openai.com/codex)** with a ChatGPT plan (populates the Codex ring). Run `codex` once and sign in with ChatGPT so `~/.codex/auth.json` exists.

> You don't need *both* — if you only use one, that ring works and the other shows `—`.

### Build & run
```sh
git clone <this-repo> burnrate
cd burnrate
./Scripts/make-app.sh        # builds release binary, assembles burnrate.app, ad-hoc signs it
open burnrate.app
```

The script produces `burnrate.app` in the repo root. You can move it to `/Applications` if you like.

### First launch
- macOS will show a **Keychain access prompt**: *"burnrate wants to use the confidential information stored in 'Claude Code-credentials'…"* — this asks for your **Mac login / Touch ID**, not a Claude password. Click **Always Allow** so the Claude ring can read the token. (This is normal: burnrate is a different app than Claude Code, so macOS gates access to the item.)
- macOS will also ask to allow **notifications** — allow them if you want the 50/75/90% alerts.

### Run from the terminal (to see logs)
```sh
./burnrate.app/Contents/MacOS/burnrate
```

### Quit
Right-click the panel → **Quit** (it has no Dock icon by design — it's a menu-bar-less accessory app).

---

## Troubleshooting
- **Claude ring stays `—`.** You're not signed into Claude Code, you denied the Keychain prompt, or your install stores the token under a different Keychain item. Check it exists:
  ```sh
  security find-generic-password -s "Claude Code-credentials"   # attributes only; omit -w
  ```
- **Claude ring is dimmed / lags the website.** It only refreshes every 5 minutes (and backs off further on 429s). Right-click → **Refresh Now** to force an update. Compare against the **5-hour** figure on the usage page, not the weekly one.
- **Codex ring stays `—`.** `~/.codex/auth.json` is missing (not signed into Codex) or the token couldn't be refreshed. Run `codex` and sign in again.
- **No notifications.** Ad-hoc-signed apps can have notification permission denied by macOS. Check **System Settings → Notifications → burnrate**. The rings still work regardless.
- **"burnrate is damaged / unidentified developer."** It's ad-hoc signed, not notarized. Right-click the app → **Open**, or run the terminal command above.

---

## Architecture
- **`BurnrateCore`** — UI-free, dependency-light logic: models, `ClaudeUsageProvider` (with `TokenStore` / `HTTPClient` seams), `OAuthUsageResponse` + `CodexUsageResponse` decoders, `BackoffPolicy`, `MilestoneNotifier`, `UsageStore`, color thresholds.
- **`burnrate`** (executable) — AppKit/SwiftUI shell: `OverlayPanel` (borderless always-on-top `NSPanel`), `RingView`/`OverlayView`, `RefreshCoordinator` (timers), `CodexLiveProvider`, and the real Keychain / URLSession / UserNotifications adapters.

Design details and decisions: `docs/design.md`.

## Tests
There is no automated test suite: the Command Line Tools toolchain ships no `XCTest`/`Testing` framework, so `swift test` can't run without full Xcode. Logic is verified by building (`swift build`) and by running the app against real data. The core logic is split behind protocols/value types, so a standard test target can be added once Xcode is installed.

## Not tracked
OpenAI Platform API (pay-as-you-go) spend, browser-only chat usage that never touches the CLIs, and dollar costs. This is a personal tool, not built for distribution.
