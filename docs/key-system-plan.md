# NotchFlow key system: plan for review

Status: **draft, nothing built yet.** Please mark the decisions in section 2, then I'll implement.

## 1. What already exists

| Part | File | State |
| --- | --- | --- |
| Signed key format `NF1.<payload>.<signature>` (Ed25519, CryptoKit) | `Features/Licensing/LicenseVerifier.swift` | Done, offline check, expiry supported |
| Storing and checking the key, `hasPro` / `hasDeveloperAccess` | `Features/Licensing/LicenseStore.swift` | Done, stored in UserDefaults |
| License page (enter key, activate, remove) | `Features/Licensing/SettingsLicenseView.swift` | Done |
| Pro gates | File Tray, AirDrop, lock screen music, Debug page | Done |
| Public key | Debug: built-in test key. Release: `NotchFlowLicensePublicKey` in Info.plist | **Release key missing**, so Release can't activate anything |
| Issuing keys | none | **Missing**: no tool creates keys |

Problems with what exists:
- The key is long (~150 characters), awkward to type or paste from email.
- A key works on any number of Macs; sharing it is free.
- Stored in UserDefaults: anyone can copy it with `defaults read`.
- No way to revoke a key (refund, leak).

## 2. Decisions for you

**D1. Offline or online activation?**
- **A. Offline only (recommended to start).** The signed key is checked inside the app; no server. Cheap and private, but a key can't be limited to N Macs or revoked.
- **B. Online activation.** The app sends a short key to a server once; the server checks the device limit and returns a signed token bound to this Mac. Supports device limits and revocation, but needs a server (e.g. a Cloudflare Worker + KV, ~free tier).
- **C. Use a store's license API** (Lemon Squeezy / Paddle / Gumroad license keys). They host keys, payment, device limits and revocation; the app calls their activate/validate endpoint.

**D2. Key look:** short `NFPRO-XXXX-XXXX-XXXX-XXXX` (needs B or C) or keep the long signed token (works with A).

**D3. Kinds:** keep `pro` (perpetual) + `developer`? Add time-limited (trial 7/14 days, yearly)?

**D4. Devices per key** (B/C only): 1, 2, 3?

**D5. Where people buy:** Lemon Squeezy, Paddle, Gumroad, or you send keys by hand for now.

## 2b. Your answers (2026-11-11)

- D1: B or C — **recommended: C with Lemon Squeezy** (no server to run). B kept as fallback behind the same app interface.
- D2: short key `NFPRO-XXXX-XXXX-XXXX-XXXX` (format is whatever the store issues; Lemon Squeezy uses UUID-like keys, we just display them).
- D3: Pro lifetime + trial.
- D4: 2 Macs per key.
- D5: buy on the web and inside the app.

## 2c. Proposed design with these answers

**Purchase**
- Product "NotchFlow Pro (Lifetime)" in Lemon Squeezy, license keys on, activation limit 2, no expiry.
- Web: no website needed. Lemon Squeezy hosts a store page and a checkout link (`<store>.lemonsqueezy.com/buy/…`) you can share anywhere (social posts, GitHub README, Product Hunt). Key emailed + shown on receipt. A real website can be added later and just links to the same checkout.
- In the app: "Buy Pro" on the License page opens the same checkout (in the browser; optional in-app sheet with a web view). After paying, the app's `notchflow://activate?key=…` link (set as the checkout's redirect) fills in and activates the key automatically.
- Not Mac App Store / StoreKit: Apple doesn't allow outside license keys there. If you later want the App Store, that's a separate StoreKit path.

**Activation (app → Lemon Squeezy License API)**
1. User enters the short key → app calls `activate` with key + instance name (Mac name) → gets `instance_id`.
2. 3rd Mac → store refuses ("limit reached") → page shows "Used on 2 Macs, deactivate one" with a link to the customer portal.
3. "Deactivate this Mac" calls `deactivate`, freeing the seat.
4. App re-validates every 7 days; works offline for up to 30 days since the last good check, then falls back to Free until it can check again. Refunded/disabled keys stop working at the next check.
5. Stored in the Keychain: key, instance id, last-validated date.

**Trial**
- 14-day Pro trial, started by a button ("Try Pro for 14 days"), one per Mac.
- Simple version (no server): trial start date in the Keychain. Can be reset by a determined user; acceptable.
- Stronger version (needs B's server): trial tied to a hashed hardware ID on the server.
- During trial: all Pro features, a "Trial · N days left" badge; at the end, back to Free with a Buy button.

**Kept from today:** the existing `NF1` offline signed tokens stay working for developer keys and keys you issue by hand.

**Code**
- `LicenseProvider` protocol (`activate`, `validate`, `deactivate`) with `LemonSqueezyLicenseProvider`; a `CustomServerLicenseProvider` for B can be added later.
- `LicenseStore` gains state: free / trial(daysLeft) / pro / needsRecheck / limitReached / error; `hasPro` becomes true for pro or active trial.
- License page: Buy Pro, Try Pro, enter key, this Mac's status, deactivate.
- Tests with a mocked provider: activate, limit reached, refund at revalidation, offline grace, trial start/end, Keychain migration.

**What you need to do (I can't):** create the Lemon Squeezy store + product, and give me the store/product IDs. No API secret goes in the app (the License API activation endpoints don't need one).

## 3. Earlier draft for D1 = A (kept for reference)

1. **Key generator tool** (`Tools/nf-license`, Swift command line, not shipped in the app)
   - `keygen` creates the Ed25519 key pair; private key saved to a file you keep outside the repo (and `.gitignore`d).
   - `issue --kind pro --id <buyer/order id> [--expires 2027-01-01]` prints a key.
   - `inspect <key>` decodes a key to check it.
2. **Release public key**: put the real public key in Info.plist; Debug keeps the test key. Add a test that Release fails loudly if the key is missing.
3. **Keychain storage**: move the saved key from UserDefaults to the Keychain, with a one-time migration of existing keys.
4. **Easier entry**: accept the key with spaces/new lines (from email), a "Paste" button, and a link `notchflow://activate?key=…` that opens the License page pre-filled.
5. **Clearer License page states**: Free / Pro (who, since when) / expires on … / expired / invalid key with a reason (wrong product, damaged, expired).
6. **Trial (if D3 says so)**: a signed trial key, or a local one-time trial start date.
7. **Tests**: generator → verifier round trip, expiry, tampered key, Keychain migration, Pro gates turn on/off live.

If you pick **B or C**, add:
8. `LicenseActivationService`: send the short key + a hashed device ID, get back a signed token bound to this Mac; recheck every ~7 days with a 30-day offline grace period.
9. Server (B) or store integration (C), plus "Deactivate this Mac" to free a seat.

## 4. Not changing
- Which features are Pro (File Tray, AirDrop, lock screen music, Debug for developer).
- Signing, entitlements, bundle id, deployment target.
- No private key ever goes into the app or the repo.

## 5. Risks
- Offline keys can be shared; only B/C stops that.
- Any local check can be patched out of the binary; this keeps honest people honest, not crackers.
- Losing the private key means old keys keep working but no new ones can be signed with it: back it up.
