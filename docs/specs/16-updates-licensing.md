# 16 · Updates, licensing and third-party code

## Purpose
- Ship updates.
- Separate Free from Pro with signed licence tokens.
- List the third-party code that may be used.

The licensing scheme is NotchFlow's own work. `LicenseStore`, `LicenseVerifier` and
`scripts/license-tool.swift` are carried over in `Imported/`. The owner's notes live in the
old project's `docs/LICENSING-AND-RELEASE.md`.

## Updates
- **Use Sparkle** for update checks.
  - The feed URL and EdDSA public key come from build settings.
  - With no feed configured, every update UI says "updates not configured" and does
    nothing.
- **Behaviour:**
  - Check automatically at launch, then on Sparkle's schedule. The user can turn automatic
    checks off.
  - *Check for updates* is in the menu-bar menu, the notch's right-click menu and Settings.
- **When an update is found:** show a *software update* notice in the notch, with system
  priority "update" ([02](02-content-engine.md)).
  - Compact: an update symbol.
  - Expanded: the new version, a short note, and *Install* and *Later* buttons.
  - *Install* hands over to Sparkle.
- **Manual check, nothing new:** a short "up to date" alert.

## Licensing

### Tiers
- **Free:** everything except the Pro features below.
- **Pro:** new file-tray imports ([07](07-file-tray.md)) and the lock-screen music panel
  ([06](06-lock-screen-music.md)).
  - Files already in the tray stay reachable without Pro.
  - The rest of the feature split is still to be decided by the owner.
- **Developer:** a separate token that shows developer diagnostics. It is not shown in normal
  navigation.

### Tokens
- **Format:** an `NF1` prefix, then a base64url JSON payload, then a base64url signature
  over the payload, joined with dots.
  - **Payload fields:** format version, product, licence ID, kind (pro / developer), and an
    optional expiry time.
  - **Signature:** Ed25519.
- **Verification is local**, against the public key from a build setting.
  - Debug builds fall back to a local test key.
  - **Debug builds count as Pro while no token is stored**, so Pro features can be tried
    during development. A stored token, valid or not, decides as usual. A debug-only toggle
    *Simulate Free* turns this off.
  - Release builds have no fallback. With no production key configured, activation is shown
    as not configured and cannot succeed.
- **Storage:** tokens are stored locally and treated as bearer secrets. Never log them.
  Removing a token deactivates it.
- **Expiry** uses the local clock. When a token expires during use, Pro features close
  gracefully, and the user's files are never deleted.
- **Settings → About** shows:
  - the version;
  - the licence status (Free / Pro / expired), with a field to paste a token and buttons to
    activate and remove it;
  - a developer token field.
- **Not in scope:** a purchase flow, an activation server, revocation and device limits.
  These are separate future work.

## Third-party
| Component | Licence | Use |
|---|---|---|
| Sparkle | MIT | Updates |
| Lottie | Apache-2.0 | Onboarding animations, with **new** animation files |
| MediaRemoteAdapter | BSD-3-Clause | Reading the now-playing session ([04](04-media-lyrics.md)) |

- Each licence text ships in the app's About and notices.
- Re-check each pinned version's licence before release.
- Nothing else from the old project may be used: no code, strings, animations, sounds,
  icons or images.

## Release (phase 7 reminders)
- Developer ID signing, hardened runtime, notarisation, and a tested Sparkle feed.
- **Bundle ID:** `app.notchflow.mac` for release; `app.notchflow.next` during development.
- **Migrating settings from the current app** is a separate, reviewed step. Its mapping table
  is written by the spec side during phase 7.
- A lawyer reviews the clean-room process and the result before any closed-source release.

## Acceptance checks
1. With no feed configured, *Check for updates* says updates are not configured.
2. With a test feed offering a newer build, the notch shows the update notice, and Install
   starts Sparkle.
3. A valid Pro token enables the lock-screen music panel and tray imports. Removing it
   disables them, and the tray files are kept.
4. A tampered, wrong-product or expired token is rejected with a clear message.
5. In a Release build without a production key, activation says it is not configured.
6. About lists every third-party component that ships (today Sparkle and MediaRemoteAdapter) with its licence.
