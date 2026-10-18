# Downbeat

Personal Android and Windows media downloader with an in-app browser and a device-local queue and processor. No Downbeat server is required.

The Android build accepts shared links, keeps downloads alive with a foreground notification, and saves completed files locally. The Windows build bundles pinned yt-dlp and FFmpeg tools.

## Development

- `make generate` prepares derived brand assets.
- `make test` runs contract, tool, and Flutter tests.
- `make lint` analyzes the Flutter client.
- `powershell -ExecutionPolicy Bypass -File tools/build_test_release.ps1` builds test APK and Windows ZIP artifacts in `dist/`.

Only download media you are permitted to save. Downbeat reports protected/DRM media as unsupported and does not bypass protection.
