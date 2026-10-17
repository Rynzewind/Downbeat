# Downbeat

Personal Android and Windows media downloader with an in-app browser, device-local queue, and cloud processing.

The first development slice runs with a simulated processor so the client experience can be tested before Cloudflare deployment.

## Development

- `make generate` prepares derived brand assets.
- `make test` runs contract, tool, and Flutter tests.
- `make lint` analyzes the Flutter client.

See the approved [design](docs/superpowers/specs/2026-10-17-cross-platform-media-downloader-design.md) and [implementation plan](docs/superpowers/plans/2026-10-17-cross-platform-media-downloader.md).
