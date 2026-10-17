# Cross-Platform Media Downloader Design

## Purpose

Rebuild the existing Windows Episode Downloader as a personal-use downloader for Android and Windows. Both clients provide an in-app browser, a floating download control, and a device-local queue. Downloads are processed on an internet-hosted backend so the Android device or Windows computer does not need to run `yt-dlp` or FFmpeg locally.

The product must make the common path simple: browse to a page, tap Download, choose MP4 or MP3, follow progress in the queue, and receive the completed file on the same device.

## Scope

The first release includes:

- An Android APK.
- A Windows desktop application distributed as an executable/installer.
- A shared Flutter client codebase with platform-specific integrations where needed.
- An in-app browser with persistent, app-owned cookies and login sessions.
- A floating download button on the browser view.
- A separate queue view that does not destroy or reload the browser.
- Per-job MP4 video or MP3 audio selection.
- Public and authenticated page support.
- Cloud-hosted extraction, downloading, merging, and conversion.
- Device-local queue history and independent queues on each installation.
- Progress notifications and clear job states.
- Automatic deletion of cloud media after verified delivery.
- Fresh processing when a completed job is downloaded again.

The first release targets Android and Windows. It does not include iPhone support, shared queues between devices, public multi-user registration, or permanent cloud media storage.

## Existing Application Findings

The reference executable is a 64-bit Python 3.13/Tkinter application packaged with PyInstaller. Its main module is `episode_downloader_gui.py`. It accepts multiple URLs, detects direct media URLs, invokes `yt-dlp`, supports concurrent work, displays progress, saves and loads JSON lists, and provides cancellation. The source code is unavailable, so the new product is a clean rebuild based on its observed behavior rather than a patch to the executable.

## Architecture

### Client applications

Flutter provides a shared presentation and application layer for Android and Windows. Each platform supplies a native web-view adapter, notifications, file saving, secure secret storage, and update integration.

The client is divided into focused components:

- **Browser controller:** navigation, address/search input, browser tabs, history, cookies, and browser persistence.
- **Download capture:** reads the active page URL, collects only cookies applicable to that URL when required, asks for MP4 or MP3, and submits a job.
- **Queue repository:** stores device-local job history and state in SQLite.
- **Queue synchronizer:** receives server progress, reconciles interrupted sessions, and updates local records.
- **File delivery:** downloads completed output, verifies successful transfer, saves it to the user-visible download location, and acknowledges delivery.
- **Notification service:** reports running, completed, and failed jobs.
- **Update service:** checks a signed release manifest and prompts when a native client update is available.

Browser state remains alive while the user switches to the Queue view.

### Cloudflare services

- **Cloudflare-hosted web/API entry point:** validates device credentials, creates jobs, exposes status, issues short-lived file links, and accepts delivery acknowledgements.
- **Job coordinator:** maintains authoritative in-flight job state, enforces per-device isolation, and prevents duplicate execution.
- **Cloudflare Container:** runs Python, `yt-dlp`, and FFmpeg. It performs metadata extraction, direct downloads, format selection, merging, and MP3 conversion.
- **R2:** temporarily stores completed output and, when needed, short-lived intermediate artifacts.
- **Job metadata store:** holds active server job records and expiration data. Completed history remains primarily on the originating device.

No device can enumerate or access another device's jobs or files.

## User Interface

The visual theme is derived from the supplied artwork:

- Near-black and deep navy surfaces.
- Cyan, electric blue, violet, and magenta gradients for primary actions and active states.
- High-contrast text and accessible status labels; color is never the only status signal.

The two persistent top-level destinations are:

1. **Browser:** full-page web content, normal navigation controls, address/search entry, and browser-tab management.
2. **Queue:** pending, active, completed, cancelled, and failed jobs.

On mobile, these destinations use bottom navigation. On Windows, the layout adapts to the wider window but preserves the same destinations and interaction model.

The Browser view places a floating circular button above the lower-right edge using `Download.png`. Tapping it opens a compact selector with:

- **MP4 — Video**
- **MP3 — Audio only**
- **Cancel**

On Android, the app also registers as a target for shared plain-text links. Sharing from apps such as TikTok or Facebook launches Episode Downloader, extracts the first valid HTTPS URL, opens that URL as the active browser target, and immediately presents the same MP4/MP3 selector. Malformed text and non-HTTPS URLs are rejected. If the source requires an authenticated session that is unavailable from the external app, the user can continue by opening the target in the app-owned browser and signing in there.

A queue card displays:

- Page/media title.
- Source site.
- MP4 or MP3 format.
- Intended output filename.
- Text status.
- Percentage when available.
- Colored progress bar.
- Relevant actions: cancel, pause/resume when supported, retry, re-download, delete/clear, and open/save completed output.

Status presentation:

| State | Appearance | Meaning |
| --- | --- | --- |
| Queued | Blue-grey | Waiting for a processing slot |
| Fetching info | Cyan | Resolving page and media metadata |
| Downloading | Animated blue-to-violet | Media transfer is active |
| Converting | Animated violet-to-magenta | FFmpeg is merging or converting |
| Paused | Amber | User-paused where resumable |
| Completed | Green | File was delivered successfully |
| Failed | Red | Processing or delivery failed |
| Cancelled | Muted grey | User cancelled the job |

If a source does not provide a measurable total, the interface shows an indeterminate animation and transferred size instead of a false percentage.

## Brand Assets

- `Icon.png` is the source for Android launcher icons, Windows application icons, splash treatment, and in-app identity.
- `Download.png` is the floating download action artwork.
- `Notification.png` is converted into Android-compatible monochrome notification assets. The conversion preserves the symbol but removes noisy tonal detail, uses a transparent background, and creates density-specific sizes.

Original source assets remain unchanged. Derived platform assets are generated within the new project.

## Browser and Authentication

The embedded browser uses persistent app-owned storage, cookies, and sessions. Android Autofill/password-manager integration is preferred over storing passwords in the application.

The browser accepts ordinary HTTPS navigation across most websites. It blocks unsafe schemes and prevents web content from invoking privileged native behavior. The application does not expose a general JavaScript-to-native bridge to arbitrary pages.

When a download needs authentication:

1. The client identifies cookies applicable to the active URL.
2. It sends only those cookies with the job over HTTPS.
3. Cookies are encrypted in transit and protected as ephemeral server secrets.
4. Cookie values are excluded from application logs, analytics, errors, and queue history.
5. The backend deletes them when the job terminates, whether by success, failure, or cancellation.

The backend must not silently broaden cookie scope to unrelated domains.

## Download Lifecycle

1. The user navigates to a page and taps the floating download control.
2. The user selects MP4 or MP3.
3. The client creates a local queue record and submits a device-authenticated job.
4. The backend resolves metadata and selects the appropriate processing path:
   - Direct file transfer for supported direct media URLs.
   - `yt-dlp` extraction for supported pages.
5. For MP4, the processor selects compatible video and audio streams and uses FFmpeg when merging or remuxing is required.
6. For MP3, it selects the best practical audio source and converts it to MP3 with FFmpeg.
7. Structured progress events update the originating device's queue and notifications.
8. The finished file is uploaded to temporary R2 storage.
9. The client receives a short-lived download link, saves the file, and verifies that the transfer completed.
10. The client acknowledges delivery.
11. The server deletes the media object and ephemeral credentials only after that acknowledgement.
12. The local record remains marked Completed until the user clears it.

If delivery is interrupted, the cloud file remains temporarily available until a defined expiry window so the device can resume. Expired undelivered files and abandoned partial artifacts are removed automatically.

Re-download creates a new job from the retained source URL and format. It never assumes that the prior cloud object still exists.

## Queue Semantics

Each app installation receives an independent device identity and queue. The Android and Windows queues do not synchronize with each other.

The user may:

- Cancel queued or running work.
- Pause/resume where the underlying transfer supports it; otherwise the interface explains that the job must be cancelled and retried.
- Retry failed or cancelled work.
- Reorder queued work that has not started.
- Re-download completed history as a fresh job.
- Remove individual history entries.
- Clear finished history without affecting active jobs.

Deleting a local active record requires cancelling its server job first. Completed history contains no authentication cookies or temporary file links.

## Reliability and Error Handling

The system uses explicit, user-readable errors for unsupported URLs, authentication expiry, unavailable media, rate limiting, insufficient storage, conversion failure, network loss, and backend unavailability.

- Job creation is idempotent to prevent accidental duplicates during retries.
- The client reconciles active jobs after restart or reconnection.
- The processor emits structured stages and progress rather than relying on raw console text in the UI.
- Partial files are isolated per job and removed on termination.
- Processing has configurable time, size, and concurrency limits.
- Output filenames are sanitized for Android and Windows and receive collision-safe suffixes.
- A failed notification opens the corresponding queue card and its actionable error.
- Completion is declared only after the device has verified local delivery.

## Notifications

Android displays an ongoing notification while a job is active. It includes the title, stage, and progress when measurable. Completion and failure notifications replace the ongoing notification and open the Queue view when tapped.

Windows uses native notifications for equivalent milestones. Notifications never reveal cookies, signed file URLs, or other credentials.

## Updates and Distribution

The personal Android build may be distributed directly as a signed APK or through a private/internal Google Play channel. Direct distribution uses an in-app update check and requires normal Android confirmation before installation.

The Windows application uses a signed installer and update manifest. The common client architecture minimizes platform divergence, while native update packages are produced separately.

Server-side behavior and configuration can be updated without reinstalling either client. Native updates are reserved for client, browser, permission, or platform-integration changes.

## Security and Abuse Controls

- Device credentials are generated per installation and stored using platform-secure storage.
- API requests are authenticated and scoped to one device.
- Short-lived signed URLs protect R2 objects.
- Server-side URL validation blocks private-network and metadata-service targets to prevent server-side request forgery.
- Redirects are revalidated.
- Job limits constrain file size, runtime, concurrency, and storage consumption.
- Secrets and cookies are redacted from all logs.
- Dependencies and `yt-dlp` can be updated independently of client releases.
- The application presents a personal-use notice and leaves responsibility for download rights and site terms with the user.

## Testing and Acceptance Criteria

Automated tests cover:

- URL capture and per-item MP4/MP3 selection.
- Public and authenticated job submission.
- Domain-scoped cookie handling and guaranteed cleanup.
- Direct-file and `yt-dlp` processing paths.
- MP4 merge/remux and MP3 conversion.
- Determinate and indeterminate progress.
- Queue ordering, cancellation, supported pause/resume, retry, clear, and re-download.
- Restart and reconnection reconciliation.
- Filename sanitization and collisions.
- Delivery verification before cloud deletion.
- Expiry cleanup for abandoned jobs.
- Device isolation and signed-link authorization.
- Browser survival when switching to Queue.
- Android and Windows notification routing.

Release acceptance requires successful end-to-end tests on a real Android device and a Windows machine. A user must be able to browse to a supported public or signed-in page, submit either format, leave the browser for the Queue, observe accurate status, receive and open the finished file, clear the history, and start a fresh re-download from retained metadata.

## Delivery Sequence

Implementation planning should stage the work so usable vertical slices appear early:

1. Shared client shell, branding, Browser/Queue navigation, and local queue storage.
2. Secure backend job API and a simulated processor for end-to-end queue behavior.
3. Real `yt-dlp`/FFmpeg container processing with public URLs.
4. File delivery, acknowledgement, R2 cleanup, progress, and notifications.
5. Authenticated-page cookie handoff and security hardening.
6. Retry, cancellation, supported pause/resume, reordering, and re-download.
7. Android and Windows packaging, signing, updates, and real-device acceptance testing.
