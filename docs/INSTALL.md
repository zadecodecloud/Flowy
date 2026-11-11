# Install Flowy

Requires macOS 26 or later, Apple Silicon or Intel.

1. Download `Flowy-<version>.dmg` from the Releases page.
2. Open the `.dmg` and drag **Flowy** onto **Applications**.
3. Open Flowy from Applications. macOS says it can't verify the app — click **Done** (not "Move to Trash").
4. Open **System Settings › Privacy & Security**, scroll down to the message about Flowy and click **Open Anyway**, then confirm with your password or Touch ID.
5. Flowy now opens normally. You only do this once per install.

Why: Flowy is an independent app and isn't notarized by Apple yet, so macOS asks you to confirm it once. You can check the download against the `.sha256` file on the Releases page:

```bash
shasum -a 256 ~/Downloads/Flowy-1.0.dmg
```

## Permissions

Flowy asks for these when you turn on the features that need them:

- **Accessibility** — volume/brightness HUD and notch gestures (System Settings › Privacy & Security › Accessibility).
- **Screen & System Audio Recording** — music bars that follow the beat.
- **Calendar**, **Camera**, **Bluetooth** — only for those notch features.

## Flowy Pro

Pro (File Tray, AirDrop from the notch, lock screen music) is a one-time purchase that never expires and includes all future updates. Buy it from **Settings › License › Buy Pro**; the key arrives by email. Paste it into **Settings › License**. Each key works on 2 Macs; use **Deactivate this Mac** before moving to a new one. Pro needs an internet connection about once a month to stay verified; Free features always work offline.

## License

Flowy is free software under the GNU GPL v3, with no warranty. The source code is available at the link in **Settings › Ứng dụng › Chung**.
