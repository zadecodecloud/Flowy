# Licensing & distribution — Phase 1 survey

Survey of the repository against the "NotchFlow distribution, licensing and updates" spec (2026-11-11). Nothing in this document has been implemented yet; it records what exists, what is missing, and what blocks the next phases.

## 0. Blocker: the source is GPL-3.0

- `LICENSE` is GPL-3.0. `README.md` says NotchFlow contains code derived from an earlier open-source notch project whose authors keep their copyright, and that complete corresponding source must ship with any modified binary.
- The spec requires the source to stay in a private repository and only binaries to be published. Under GPL-3.0, anyone who receives the binary is entitled to the complete corresponding source, and may modify it (including removing license checks) and redistribute it.
- Selling GPL software is allowed; keeping its source from the people you give the binary to is not.
- This is a product/legal decision for the owner (not legal advice). Options:
  1. **Keep GPL.** Sell Pro and updates, and provide source to recipients. Licensing still works for honest users, but it can be legally removed.
  2. **Get permission.** Ask the upstream copyright holders for a separate (commercial) license for their code.
  3. **Replace the derived code.** Rewrite or remove every part derived from the upstream project, so the remaining code is entirely yours and can be closed. This needs a careful audit of the file headers and `THIRD_PARTY_NOTICES/`.
- Third-party packages: Lottie (Apache-2.0) and Sparkle (MIT) are fine in closed apps; their notices must be kept.

Phases 2–7 can be built either way, but **publishing a closed binary must wait for this decision.**

## 1. What already exists

| Spec item | Current state | File(s) |
| --- | --- | --- |
| Ed25519 signed entitlement, verified in the app | `NF1` token (base64url payload + signature); checks product, kind, expiry. No issuer/audience/device binding/keyId. Debug has a test public key; Release has none configured. | `Licensing/LicenseVerifier.swift`, `scripts/license-tool.swift` |
| Store integration | App talks **directly** to Lemon Squeezy's License API (activate/validate/deactivate), 2 seats, 7-day recheck, 30-day grace. Spec wants the app to talk to **our backend** instead. | `Licensing/OnlineLicensing.swift`, `Licensing/LicenseStore.swift` |
| Keychain | Online record and trial start are stored in the Keychain. `NF1` tokens are still in UserDefaults. | `LicenseStore.swift` |
| License UI | Free / Trial / Pro, buy, trial, enter key, deactivate, error messages. | `Licensing/SettingsLicenseView.swift` |
| Pro gates | Checked where features run (File Tray import, AirDrop, lock-screen music panel), not only in the UI. Debug page needs a developer token. | `NotchEventCoordinator`, `NotchDragAndDropEventsHandler`, `AirDropController`, `LockScreenPanelManager` |
| Free/Pro list | Pro = File Tray imports + lock-screen music panel (+ AirDrop from the notch). Docs say the rest of the split is undecided; not in one central place. | scattered `hasPro` checks |
| Lemon Squeezy | Store "Flowdy" (520808), product "NotchFlow Pro (Lifetime)" (1517617), €6.99, keys on, 2 activations, no expiry, published, **test mode**. | `Info.plist` |
| Sparkle | Sparkle 2.9.4 package linked, but not used: no `SPUStandardUpdaterController`, no feed URL, no EdDSA public key. | `project.pbxproj` |
| Signing | Debug signed with the owner's Apple Development cert (team WP4578MNNL). No Developer ID, notarization or release script. Hardened Runtime on. Bundle id `app.notchflow.mac`, macOS 26.0+. | `project.pbxproj` |
| Backend, database, webhooks | None. | — |
| Repos | No git remote configured. No public releases repo. | — |
| Trial | 14-day local trial (owner decision earlier; not in the new spec). | `LicenseStore.swift` |

## 2. Gaps against the spec

**App**
- Device identity: a per-install key pair (CryptoKit, private key in the Keychain) — missing.
- Certificate v2: issuer, audience (bundle id), licenseId, activationId, devicePublicKeyHash, entitlements, licenseType, issuedAt/refreshAfter/expiresAt, keyId; verify over the exact transmitted bytes; key rotation (several trusted keyIds) — missing (current `NF1` covers only part).
- `LicenseAPIClient` to our backend with signed refresh/deactivate requests (device signature + nonce/timestamp against replay) — missing; current client calls Lemon Squeezy directly.
- States: Free, activating, Pro verified, Pro offline, needs re-verification, revoked — partly (no offline/revoked distinction).
- Policy changes: refresh every 24 h, certificate valid 30 days, plus 14 days offline grace (currently 7 days / 30 days).
- One central Free/Pro feature list (`EntitlementService`).
- Sparkle `AppUpdateController`, and a check that the Keychain survives updates.

**Backend (new, TypeScript + PostgreSQL)**
- Endpoints: activate, refresh, deactivate, Lemon Squeezy webhook.
- Tables: licenses, activations, webhook_events, audit_events.
- HMAC-hashed key lookup, encrypted key at rest only if needed, no secrets in logs, rate limiting, transactional seat counting, idempotent and out-of-order-safe webhooks (signature checked on the raw body), reconciliation job.
- Ed25519 certificate signing with keyId; a separate key from Sparkle's and Apple's.
- Admin/support: reset a lost Mac's activation, with an audit entry.

**Release**
- Release build script: Developer ID signing, notarize, staple, Sparkle archive + EdDSA signature, GitHub Releases upload, appcast on a domain you control, artifact check (no `.swift`, `.env`, secrets, test data).

## 3. What the owner needs to provide or decide

1. **GPL decision** (section 0) — blocks publishing a closed binary.
2. **Backend hosting** for TypeScript + PostgreSQL with HTTPS and secrets. Suggested low-cost options: Cloudflare Workers + Neon Postgres, Fly.io + Postgres, or Supabase (Postgres + Edge Functions). You create the account; I write the code, migrations and deploy config.
3. **Domain** for the API, appcast and website (none yet). Until then the API can use the host's default `https://…` address.
4. **Free/Pro list**: confirm Pro = File Tray imports, AirDrop from the notch, lock-screen music panel; everything else Free.
5. **Trial**: keep the 14-day trial (not in the new spec)? If kept, it should move to the backend (one trial per device key).
6. **Apple Developer ID Application certificate** for distribution (only Apple Development exists now) and an app-specific password or API key for notarization.
7. **Private GitHub repo** for the source (+ a public repo for releases).
8. Later: Lemon Squeezy webhook secret, and leaving test mode, payout and tax details.

## 4. Proposed order

1. Phase 2 (app, testable now with a mocked backend): device identity, certificate v2 verifier with keyId rotation, signed requests, state machine, central entitlements, policy timings, UI states. Keep Lemon Squeezy-direct activation working until the backend is live.
2. Phase 3 (backend, runnable locally with Docker Postgres and tests): endpoints, schema, signing, rate limits, webhook handling, reconciliation, admin reset.
3. Phase 4: test-mode checkout → webhook → backend, refunds.
4. Phase 5: switch the app to the backend.
5. Phase 6: release pipeline and Sparkle.
6. Phase 7: acceptance checklist from the spec, run end to end and recorded.
