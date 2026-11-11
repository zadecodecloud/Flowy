# NotchFlow license API (contract between app and backend)

Implemented on the app side in Phase 2 (`Features/Licensing/`). The backend (Phase 3) must match this exactly. All requests are `POST`, JSON, HTTPS only. Base URL comes from `NotchFlowLicenseAPIURL` in Info.plist; when it is empty the app falls back to activating directly with Lemon Squeezy.

## Device identity

- Each install creates an Ed25519 key pair (CryptoKit). The private key stays in the Keychain (`app.notchflow.license` / `deviceKey`).
- `devicePublicKey` = base64 (standard, padded) of the 32-byte raw public key.
- `devicePublicKeyHash` = lowercase hex SHA-256 of those 32 raw bytes.
- No serial number, MAC address or hardware ID is collected. Deleting the Keychain item or reinstalling macOS creates a new device; support can free the old seat.

## Signed requests (refresh, deactivate)

Headers:

| Header | Value |
| --- | --- |
| `X-NF-Timestamp` | Unix seconds |
| `X-NF-Nonce` | random UUID, lowercase |
| `X-NF-Device-Key` | `devicePublicKey` |
| `X-NF-Signature` | base64url (no padding) Ed25519 signature |

Signed message (UTF-8, `\n` separators, no trailing newline):

```
POST
/v1/licenses/refresh
1800000000
3f0c…-nonce
<lowercase hex SHA-256 of the exact raw request body>
```

Server must: verify the signature with the device key stored on the activation (not the header value alone; it must equal the stored key), reject timestamps outside ±5 minutes, and reject a nonce already seen for that device within the window. `activationId` is not a secret and never authenticates on its own.

## Endpoints

### `POST /v1/licenses/activate`
Body: `{ "licenseKey": "…", "devicePublicKey": "…", "deviceName": "Phúc's MacBook" }` (unsigned; rate limited per IP and per key hash).

- Validate the key with Lemon Squeezy: right store, right product, right mode (test/live), status active.
- In one transaction: if this device key already has an active activation for the license, return a fresh certificate for it (no new seat); else if active activations < 2, create one; else `409 limit_reached`.
- `200 { "certificate": "NFC2…" }`

### `POST /v1/licenses/refresh` (signed)
Body: `{ "activationId": "…" }` → `200 { "certificate": "NFC2…" }`, or `403 revoked` / `404 activation_not_found` when refunded, disabled or removed.

### `POST /v1/licenses/deactivate` (signed)
Body: `{ "activationId": "…" }` → `200 {}`. The app clears local data only after a 2xx.

### `POST /v1/webhooks/lemonsqueezy`
Verified on the raw body with the Lemon Squeezy signing secret; idempotent; safe when duplicated or out of order. (Event names and fields to be taken from the current Lemon Squeezy docs in Phase 3.)

## Errors

`{ "error": "<code>" }` with these codes, which the app maps:

| Code | HTTP | App behavior |
| --- | --- | --- |
| `invalid_key` | 400/404 | "That key isn't valid" |
| `wrong_product` | 400 | same as invalid |
| `limit_reached` | 409 | "Already used on 2 Macs" |
| `revoked`, `activation_not_found` | 403/404 | Pro off, state "revoked" |
| any, status 429 | 429 | "Too many attempts" |
| anything else / 5xx / network | — | **not** revocation; Pro kept within offline grace |

## Certificate `NFC2`

`NFC2.<base64url(payload)>.<base64url(Ed25519 signature)>`, signature over the ASCII bytes `NFC2.<base64url(payload)>` exactly as sent. Payload JSON:

```json
{
  "schemaVersion": 1,
  "issuer": "notchflow",
  "audience": "app.notchflow.mac",
  "licenseId": "…",
  "activationId": "…",
  "devicePublicKeyHash": "<hex sha256>",
  "entitlements": ["notchflow.pro"],
  "licenseType": "lifetime",
  "issuedAt": "2027-01-01T00:00:00Z",
  "refreshAfter": "2027-01-02T00:00:00Z",
  "expiresAt": "2027-01-31T00:00:00Z",
  "keyId": "k1"
}
```

- Dates: ISO 8601 UTC **without fractional seconds**.
- No email, license key or payment data in the certificate.
- App trusts the keys in `NotchFlowCertificateKeys` (Info.plist dictionary `keyId → base64 public key`). To rotate: add the new key to the app, ship an update, then start signing with it; remove the old key after old certificates have expired. Debug builds trust a local test key `dev-1` when none is configured.
- This signing key is separate from the Sparkle update key and from Apple signing.

## App timing

| | Value |
| --- | --- |
| Background refresh | when `refreshAfter` passes or 24 h after `issuedAt`; checked hourly and at launch |
| Certificate lifetime (server sets) | 30 days |
| Offline grace after `expiresAt` | 14 days, then Pro pauses ("Verify again"); settings and files are kept |
| Network/server error | never treated as revocation |

## Owner configuration still empty

- `NotchFlowLicenseAPIURL` — the deployed backend URL.
- `NotchFlowCertificateKeys` — the production certificate public key(s).
