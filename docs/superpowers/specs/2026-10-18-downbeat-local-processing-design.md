# Downbeat Local Processing Design

## Status

This specification replaces the hosted processing architecture in `2026-10-17-cross-platform-media-downloader-design.md` and the portable server design in `2026-10-18-downbeat-portable-server-installer-design.md`.

## Purpose

Downbeat is a personal Android and Windows media downloader. Each installation contains everything required to resolve, download, merge, convert, save, and track media locally. There is no Downbeat account, hosted processor, pairing flow, cloud queue, temporary cloud storage, or required server computer.

The primary experience is:

1. Browse normally in Downbeat or share a link to it from another app.
2. Tap the floating Download control.
3. Choose MP4 video or MP3 audio.
4. Follow progress in the independent Queue view or system notification.
5. Open the completed file from the device's normal Downloads location.

## Scope

The first testable release includes:

- An Android APK and Windows desktop build named **Downbeat**.
- A shared Flutter presentation and application layer.
- Persistent, app-owned browsing sessions and tabs.
- Android share-target support for HTTPS links.
- The supplied Downbeat icon, floating download artwork, and monochrome notification artwork.
- Local direct-file and `yt-dlp` processing paths.
- Local FFmpeg merging, remuxing, and MP3 conversion.
- A persistent local queue with progress, clear errors, cancellation, retry, and fresh re-download.
- User-visible file delivery and completion notifications.
- Signed component and application update mechanisms.

The first release does not include iPhone support, DRM circumvention, synchronized queues, remote processing, cloud storage, multiple Android jobs running concurrently, or public app-store distribution.

## Architecture

### Shared client layer

Flutter supplies the branded Browser and Queue interface plus platform-independent job semantics. Each platform implements explicit adapters for browsing, secure cookie extraction, background execution, processing, file delivery, notifications, and updates.

The application is divided into these components:

- **Browser controller:** maintains navigation, tabs, app-owned cookies, and login state.
- **Download capture:** reads the active HTTPS URL, asks for MP4 or MP3, and creates a local job.
- **Job repository:** persists queue history, stages, progress, source metadata, and recoverable state in SQLite.
- **Processing coordinator:** owns job scheduling, cancellation, recovery, free-space checks, and cleanup.
- **Downloader adapter:** invokes direct download or the embedded `yt-dlp` runtime using structured inputs and progress events.
- **Media processor:** invokes packaged FFmpeg components for merge, remux, and MP3 conversion.
- **File delivery:** verifies output and publishes it atomically to a user-visible Downloads location.
- **Notification adapter:** reports active, completed, and failed work using native Android and Windows notifications.
- **Update manager:** verifies and applies compatible signed downloader-definition updates and full application releases.

These boundaries allow a future remote processor to implement the processing interface without changing browser, queue, or file-history behavior.

### Android runtime

The APK packages an application-private Python runtime capable of invoking `yt-dlp` as a library plus Android-compatible FFmpeg binaries or libraries for the supported CPU architectures. Users do not install or configure Termux, Python, `yt-dlp`, or FFmpeg separately.

Processing occurs in job-specific directories inside app-private storage. Android work continues through a foreground service with an ongoing notification. The first release processes one Android job at a time to limit heat, memory pressure, and battery consumption.

### Windows runtime

The Windows package contains the standalone Windows `yt-dlp` and FFmpeg executables in a versioned private runtime directory. A background worker survives UI navigation and continues while the application window is minimized. The application does not depend on system-wide Python or media tools.

## Browser and Sharing

The in-app browser supports ordinary HTTPS navigation and retains its state when the Queue view is selected. Browser logins belong to Downbeat and remain independent of Chrome, Edge, and other browsers.

The floating Download control uses the supplied `Download.png`. It submits the active page URL after the user selects:

- **MP4 — Video**
- **MP3 — Audio only**
- **Cancel**

Android registers for shared plain-text HTTPS links. Sharing a link from TikTok, Facebook, YouTube, a browser, or another application opens Downbeat and immediately shows the same format selector for the shared URL.

When authentication is needed, Downbeat exports only cookies applicable to the target site into that job's temporary directory. Cookie values never appear in queue history, user-facing errors, analytics, or logs. The temporary cookie file is removed on success, failure, or cancellation.

## Local Download Lifecycle

1. The user submits the active or shared URL and selects MP4 or MP3.
2. Downbeat validates the URL, creates a local queue entry, and estimates required working space when possible.
3. The processing coordinator creates an isolated job directory and writes any required site-scoped cookies.
4. The downloader chooses a direct-media path or runs `yt-dlp` extraction.
5. MP4 processing chooses compatible video and audio streams, merging or remuxing with FFmpeg when required.
6. MP3 processing selects the best practical audio input and converts it locally with FFmpeg.
7. Structured events update the Queue and native notification with stage, progress, speed, and transferred size when available.
8. Downbeat validates that the output exists, is non-empty, and matches the expected container sufficiently for safe delivery.
9. The file is copied or moved into Downloads using a sanitized, collision-safe filename and an atomic completion step.
10. Temporary media, cookie material, and job working files are deleted.
11. The queue entry remains Completed until the user clears it.

**Download again** creates a fresh job from the retained URL and format. It does not depend on temporary files from the earlier run.

## Queue and Interface

Browser and Queue remain persistent top-level destinations. Switching between them never reloads the active browser solely because of navigation.

Each queue card displays title, source site, MP4/MP3 choice, intended filename, text status, and either a percentage or an indeterminate progress treatment. Available actions depend on state: cancel, retry, download again, open, remove, or clear.

Status presentation remains:

| State | Appearance | Meaning |
| --- | --- | --- |
| Queued | Blue-grey | Waiting for the local processor |
| Fetching info | Cyan | Resolving the page and available media |
| Downloading | Blue-to-violet | Receiving media directly from the source |
| Converting | Violet-to-magenta | Merging or converting locally |
| Completed | Green | Verified file saved to Downloads |
| Failed | Red | Actionable error available |
| Cancelled | Muted grey | User stopped the job |

Color is never the only status indicator.

## Android Background Behavior

Starting an Android job starts a foreground service and ongoing notification using the supplied monochrome `Notification.png` derivative. The notification shows the title, stage, measurable progress, and actions to open the Queue or cancel.

The service maintains a persistent recovery record. If Android stops the process, the device reboots, connectivity disappears, or the application crashes, Downbeat reconciles the queue when it next runs. It resumes a partial download when the protocol and downloader support safe continuation; otherwise it restarts that job cleanly. It never reports completion until the published Downloads file has been verified.

Downbeat detects common battery-optimization restrictions and explains how to open the relevant system setting. It does not claim that every device manufacturer will permit indefinite background work.

## Storage and Resource Controls

- Android runs one processing job at a time in the first release.
- Windows may use configurable concurrency, initially capped conservatively.
- Before starting, Downbeat reserves headroom for separate video/audio streams, output, and conversion intermediates.
- Large estimated downloads show a confirmation containing expected size and available space.
- An unknown size uses conservative monitoring and stops safely before exhausting storage.
- Cancellation terminates downloader and FFmpeg work, removes partial intermediates, and retains the queue record.
- File delivery uses platform storage APIs rather than broad unrestricted filesystem access.

## Site Compatibility and DRM

Downbeat targets compatible non-DRM media supported by the bundled downloader, including many public or authenticated pages from YouTube, social-media sites, BBC iPlayer, and other websites. A site appearing in the `yt-dlp` extractor list is not a permanent guarantee: sites change frequently and individual media may have different authentication, region, token, or protection requirements.

Downbeat may use current site-scoped browser cookies and supported proof/token provider mechanisms where necessary. It does not bypass geographic restrictions, access controls, subscription entitlements, or usage limits.

DRM-protected media is out of scope. Downbeat does not acquire or extract content decryption keys, defeat Widevine or similar systems, or convert encrypted streams into unprotected files. Netflix, Disney+, Prime Video, and similarly protected services are therefore generally unsupported. Browser playback alone does not imply that downloadable unencrypted media exists.

Failure categories shown to the user include:

- Login required or login expired.
- Media unavailable or removed.
- Outside supported region.
- Protected by DRM.
- Website changed or temporarily unsupported.
- Verification/token requirement could not be satisfied.
- Network interruption.
- Insufficient device storage.
- Conversion or file-delivery failure.

## Updates

Every application release includes a known-working downloader and FFmpeg baseline. Updates have two levels:

- **Signed downloader-definition update:** refreshes approved Python downloader code, extractor configuration, or compatible provider plugins without replacing native libraries.
- **Full application update:** replaces Flutter/native code, Python runtime, FFmpeg, or packaging through a new APK or signed Windows installer.

Update manifests and payloads are signed. Downbeat verifies signature, version compatibility, and checksum before activation. It retains the previous downloader bundle and automatically rolls back if the new bundle fails its startup self-test. No downloaded executable code is activated from an unsigned source.

Android direct distribution requires normal user confirmation to install a new APK. Windows updates use a signed installer and preserve local data.

## Privacy and Security

- All jobs and history remain local to the device.
- Downbeat contacts the selected media site and the signed-update endpoint; it has no required Downbeat account or processing service.
- Browser cookies are scoped to the target site, copied only when required, excluded from logs, and destroyed with the job workspace.
- Arbitrary web pages receive no general JavaScript-to-native privileged bridge.
- Downloader input is passed as structured arguments without shell interpolation.
- Redirects and output filenames are validated.
- Packaged runtimes and component updates are integrity checked.
- The interface states that users remain responsible for download rights and applicable service terms.

## Reliability and Recovery

- Queue mutations and recovery checkpoints are transactional.
- Each job has an isolated workspace and process group.
- Stale workspaces are reconciled and cleaned after crashes.
- Partial final files are never exposed as completed downloads.
- Unknown progress is shown honestly rather than as a fabricated percentage.
- Diagnostics retain redacted stage and tool output sufficient to distinguish site, network, conversion, and storage failures.
- A failed component update falls back to the packaged or previous verified version.

## Testing and Acceptance

Automated tests cover:

- Active-page and shared-link capture.
- MP4 and MP3 selection.
- Site-scoped cookie export and cleanup on every terminal path.
- Direct downloads and `yt-dlp` extraction.
- MP4 merge/remux and MP3 conversion.
- Structured determinate and indeterminate progress.
- Sequential Android scheduling, cancellation, retry, and recovery.
- Filename sanitization, duplicate handling, storage checks, and atomic delivery.
- Queue retention, clearing, and fresh re-download.
- Notification routing and controls.
- Signed component validation, self-test, activation, and rollback.
- Specific error mapping, including authentication, region, site-change, and DRM cases.
- Browser preservation while Queue is visible.

The first test build is accepted when a real Android device and Windows computer can each:

1. Open or receive a supported public link.
2. Choose MP4 or MP3.
3. Download and process the media locally.
4. Continue visibly while the app is backgrounded where the platform permits.
5. Save and open the verified file from Downloads.
6. Retain the completed queue entry and start a fresh re-download.

Authenticated-browser and representative YouTube, social-media, and BBC iPlayer cases are tested separately and reported as compatibility results, not universal guarantees.

## Delivery Priorities

The first test build prioritizes a working vertical slice over every final convenience:

1. Complete Windows local processing using the existing processor work adapted behind a local coordinator.
2. Complete Android embedded runtime, foreground service, and Downloads delivery.
3. Connect the existing Browser/Queue interface to real local job state.
4. Add authenticated cookie transfer and shared-link coverage.
5. Add recovery, notifications, specific error mapping, and cleanup hardening.
6. Package installable APK and Windows releases for hands-on testing.
7. Add signed component updating after the packaged baseline passes device testing.

