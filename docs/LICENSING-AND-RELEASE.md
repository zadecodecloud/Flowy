# Licensing and release status

## Local test keys (Debug only)

Debug builds now fall back to a dedicated local test public key when no production
public key is configured. The matching private signing key is stored outside the
project, under the owner's Application Support/NotchFlow/DevelopmentLicensing directory.
Pro and developer test tokens were issued separately and expire on December 2, 2026,
23:59:59 UTC. Enter both tokens in Settings → About to test both Pro features and
developer diagnostics. Release builds compile out the fallback authority and do not
accept these test tokens by default. A configured production public key takes priority.
This does not configure a production activation service.

This is a development build, not a public release. The app starts as Free. Pro currently
enables new File Tray imports and the lock-screen music panel. Files already in the tray
are retained; when Pro is unavailable, Settings offers access to the stored files.
The remaining feature split is undecided. Developer diagnostics require a separately
signed developer token and are hidden from normal navigation.

The app verifies Ed25519 signed `NF1` tokens locally. The verifier key is supplied to
the `NOTCHFLOW_LICENSE_PUBLIC_KEY` Xcode build setting as base64-encoded 32-byte public
key data. No production public key is configured by default: in Release the activation UI says it is not
configured, and neither Pro nor developer activation can succeed in this configuration.
There is no purchase flow, activation server, revocation, device limit, support service,
or payment integration. The format is a local bootstrap, not a claim that arbitrary
future providers are already compatible. A future service can validate purchase keys
and issue these signed tokens, but must be implemented and tested separately. Tokens
are bearer credentials stored locally; never log or publish a customer's token.
Offline expiry relies on the local clock and cannot enforce revocation or device limits.

Local verification so far: the Release app and the Debug test targets compile. A
standalone harness using the production verifier and store checked valid Pro and
developer tokens, wrong/tampered and expired tokens, separate privileges and removal.
The issuer was checked end to end with a disposable test key. The Xcode-hosted test
run stalled at launch and was interrupted; settings, locked-screen presentation, drag
and drop, file recovery, expiry during use, and developer controls have not been
manually verified. These checks are not proof of release readiness.

To provision an issuer **only when you have a secure place for the signing key**:

1. Run `swift scripts/license-tool.swift generate /secure/private/location/notchflow-signing.key`.
   The file is created with owner-only permissions and is not overwritten. Save a secure
   backup separately. Never place the private key in this project, an app, a repository,
   a public source archive, a build log, or a website.
2. Set `NOTCHFLOW_LICENSE_PUBLIC_KEY` to the printed public key in a private build
   configuration or pass it to `xcodebuild`, then rebuild. The public key is not secret.
3. Issue a token using `swift scripts/license-tool.swift issue /secure/private/location/notchflow-signing.key pro LICENSE_ID`
   or replace `pro` with `developer`. An optional final Unix timestamp makes the token
   expire. Deliver the resulting token privately. The tool is a local bootstrap and has
   no order tracking, refund, recovery, or customer-facing activation infrastructure.

Before public distribution: audit and test the inherited integrations and file safety,
prepare a real update feed and release infrastructure, set a unique bundle identifier,
sign with your Developer ID, enable an appropriate hardened runtime, notarize, and test
the downloaded build on clean supported Macs. No distribution certificate, notarization,
website, or public publishing has been configured. Keep the GPL license and all upstream
and third-party notices, and provide complete corresponding source and build information
when distributing the binary. A paid edition does not remove GPL obligations; recipients
can exercise their GPL rights, including modifying the available source.
