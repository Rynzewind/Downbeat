# Cross-Platform Media Downloader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal Android and Windows downloader with an in-app browser, floating MP4/MP3 capture control, independent local queues, and secure Cloudflare-hosted `yt-dlp`/FFmpeg processing.

**Architecture:** A Flutter client supplies the shared Android/Windows experience and delegates platform browser, storage, notifications, and update behavior through adapters. A Cloudflare Worker authenticates devices and coordinates jobs; a Python container performs media work; R2 holds completed output only until verified delivery. The API contract and job state machine are shared sources of truth, while each installation retains its own queue history locally.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite, Android WebView, Windows WebView2, TypeScript Cloudflare Workers, Durable Objects, R2, Python 3.13, FastAPI, `yt-dlp`, FFmpeg, pytest, Vitest, Flutter test, Playwright API tests.

**Spec:** `docs/superpowers/specs/2026-10-17-cross-platform-media-downloader-design.md`

## Global Constraints

- The first release targets Android APK and Windows executable/installer only.
- Android and Windows installations have independent device identities and independent local queue histories.
- Browser state, cookies, tabs, and login sessions persist independently inside each app.
- Arbitrary web content receives no general JavaScript-to-native bridge.
- Each queue item independently selects MP4 video or MP3 audio.
- Authentication cookies are limited to the active URL's domain, never logged, and deleted after job termination.
- Cloud output is deleted only after verified device delivery; abandoned output expires automatically.
- Re-download creates a fresh job from retained URL and format metadata.
- Original image assets remain unchanged; platform-specific derivatives are generated inside the repository.
- Color never serves as the only indication of queue state.
- Secrets, cookies, signed URLs, and credentials never appear in logs or local queue history.
- Production releases require real-device acceptance on Android and Windows.

## Review Focus

- A malicious URL resolving or redirecting to a private, loopback, link-local, or cloud-metadata address must be rejected before any backend request.
- A filename containing Windows-reserved names, path separators, control characters, or an existing destination name must save safely without overwrite.
- A client retry after a lost job-creation response must return the original job rather than start duplicate processing.
- An app restart or network loss during processing or file delivery must reconcile the active job and resume safely.
- Authentication cookies must not escape their domain, survive job termination, appear in logs, or enter persisted queue records.

---

### Task 1: Repository Bootstrap, Contract, and Brand Assets

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `Makefile`
- Create: `package.json`
- Create: `contracts/openapi.yaml`
- Create: `contracts/examples/job-created.json`
- Create: `contracts/examples/job-progress.json`
- Create: `contracts/examples/job-completed.json`
- Create: `apps/client/pubspec.yaml`
- Create: `services/api/package.json`
- Create: `services/processor/pyproject.toml`
- Create: `assets/source/Icon.png`
- Create: `assets/source/Download.png`
- Create: `assets/source/Notification.png`
- Create: `tools/prepare_assets.dart`
- Test: `contracts/tests/test_contract_examples.mjs`
- Test: `tools/test/prepare_assets_test.dart`

**Interfaces:**
- Consumes: approved design specification and the three supplied PNG files.
- Produces: OpenAPI schemas `JobCreateRequest`, `JobRecord`, `ProgressEvent`, `DeliveryAck`, and `ApiError`; generated asset destinations under `apps/client/assets/`; root commands `make test`, `make lint`, and `make generate`.

- [ ] **Step 1: Initialize version control and the monorepo skeleton**

Create the directories above, initialize Git, declare the Node workspace packages, and add ignore rules for Flutter, Node, Python, Cloudflare, secrets, build outputs, and generated platform binaries. Do not copy or edit anything under `sources/`.

- [ ] **Step 2: Write the failing contract-example test**

The test must validate all three JSON examples against `contracts/openapi.yaml` and assert the exact states `queued`, `fetching`, `downloading`, `converting`, `paused`, `completed`, `failed`, and `cancelled`.

- [ ] **Step 3: Run the contract test and verify it fails**

Run: `node --test contracts/tests/test_contract_examples.mjs`

Expected: FAIL because the contract and examples are not implemented.

- [ ] **Step 4: Define the minimal API contract**

Define `POST /v1/jobs`, `GET /v1/jobs/{jobId}`, `POST /v1/jobs/{jobId}/commands`, `GET /v1/jobs/{jobId}/events`, `POST /v1/jobs/{jobId}/delivery`, and `GET /v1/releases/{platform}`. Pin formats to `mp4|mp3`, commands to `cancel|pause|resume|retry`, and represent percentage as nullable `0..100`.

- [ ] **Step 5: Copy source artwork and write failing asset tests**

Copy the three attachments without modification into `assets/source/`. Test that launcher and floating-button outputs preserve full color, while notification outputs contain transparency plus a single white foreground silhouette at Android density sizes.

- [ ] **Step 6: Implement `tools/prepare_assets.dart`**

Expose `Future<AssetManifest> prepareAssets(Directory source, Directory destination)`. Generate Android launcher sizes, Windows ICO inputs, the floating control asset, and cleaned monochrome notification images without overwriting source PNGs.

- [ ] **Step 7: Verify bootstrap artifacts**

Run: `node --test contracts/tests/test_contract_examples.mjs`

Run: `flutter test tools/test/prepare_assets_test.dart`

Expected: all tests PASS and generated assets exist at declared sizes.

- [ ] **Step 8: Commit**

Commit message: `chore: bootstrap downloader workspace and contracts`

---

### Task 2: Client Job Domain and Durable Local Queue

**Files:**
- Create: `apps/client/lib/jobs/job.dart`
- Create: `apps/client/lib/jobs/job_state.dart`
- Create: `apps/client/lib/jobs/job_transition.dart`
- Create: `apps/client/lib/jobs/job_repository.dart`
- Create: `apps/client/lib/jobs/drift_job_repository.dart`
- Create: `apps/client/lib/storage/database.dart`
- Test: `apps/client/test/jobs/job_transition_test.dart`
- Test: `apps/client/test/jobs/job_repository_test.dart`
- Test: `apps/client/test/jobs/filename_test.dart`

**Interfaces:**
- Consumes: OpenAPI state and format values from Task 1.
- Produces: `Job`, `JobState`, `JobFormat`, `JobAction`; `JobTransition.apply(Job, JobEvent) -> Job`; `JobRepository.watchAll()`, `upsert(Job)`, `reorder(List<String>)`, `remove(String)`, and `clearFinished()`.

- [ ] **Step 1: Write failing state-machine tests**

Cover every legal transition, reject regressions from terminal states, retain completed metadata after delivery, and ensure re-download creates a new local and remote identity while retaining URL and format.

- [ ] **Step 2: Run the state tests and verify failure**

Run: `flutter test test/jobs/job_transition_test.dart`

Expected: FAIL because the job domain does not exist.

- [ ] **Step 3: Implement the immutable job model and transition function**

Use exhaustive enums and a pure transition function. Store no cookies, authorization headers, or signed URLs on `Job`.

- [ ] **Step 4: Write failing repository and filename tests**

Test persistence across reopen, independent `deviceId`, stable user ordering, active-job deletion refusal, clear-finished behavior, Windows reserved names, traversal text, control characters, Unicode, and collision suffixes.

- [ ] **Step 5: Implement SQLite persistence and filename policy**

Expose `String safeFilename(String proposed, Set<String> existing)` and preserve the requested `.mp4` or `.mp3` extension.

- [ ] **Step 6: Run client domain tests**

Run: `flutter test test/jobs`

Expected: all tests PASS.

- [ ] **Step 7: Commit**

Commit message: `feat: add durable device-local job queue`

---

### Task 3: Shared Client Shell and Queue Experience

**Files:**
- Create: `apps/client/lib/main.dart`
- Create: `apps/client/lib/app.dart`
- Create: `apps/client/lib/theme/app_theme.dart`
- Create: `apps/client/lib/navigation/app_destination.dart`
- Create: `apps/client/lib/navigation/app_shell.dart`
- Create: `apps/client/lib/queue/queue_page.dart`
- Create: `apps/client/lib/queue/job_card.dart`
- Create: `apps/client/lib/queue/progress_indicator.dart`
- Create: `apps/client/lib/queue/queue_controller.dart`
- Test: `apps/client/test/navigation/app_shell_test.dart`
- Test: `apps/client/test/queue/job_card_test.dart`
- Test: `apps/client/test/queue/queue_actions_test.dart`

**Interfaces:**
- Consumes: `JobRepository` and job-domain types from Task 2; brand assets from Task 1.
- Produces: persistent destinations `browser` and `queue`; `QueueController` commands `cancel`, `pause`, `resume`, `retry`, `redownload`, `reorder`, `remove`, and `clearFinished`.

- [ ] **Step 1: Write failing shell and queue rendering tests**

Assert bottom navigation on compact screens, adaptive navigation on wide Windows layouts, preservation of each destination's state, exact textual statuses, exact status colors from the spec, nullable percentage behavior, and accessible labels independent of color.

- [ ] **Step 2: Run widget tests and verify failure**

Run: `flutter test test/navigation test/queue/job_card_test.dart`

Expected: FAIL because the app shell and queue widgets do not exist.

- [ ] **Step 3: Implement theme, shell, queue page, and cards**

Use the dark navy base and cyan-blue-violet-magenta accents derived from the supplied assets. Keep queue widgets independent of the remote transport.

- [ ] **Step 4: Write failing queue-action tests**

Assert that valid actions dispatch once, unsupported pause shows an explanation, deleting an active job first requests cancellation, and clear-finished never removes active jobs.

- [ ] **Step 5: Implement `QueueController` against a fake gateway**

Introduce `JobGateway` with `create`, `command`, `watch`, `download`, and `acknowledgeDelivery`; use an in-memory fake for this task.

- [ ] **Step 6: Run shell and queue tests**

Run: `flutter test test/navigation test/queue`

Expected: all tests PASS.

- [ ] **Step 7: Commit**

Commit message: `feat: build branded shell and queue experience`

---

### Task 4: Persistent In-App Browser and Floating Capture

**Files:**
- Create: `apps/client/lib/browser/browser_page.dart`
- Create: `apps/client/lib/browser/browser_controller.dart`
- Create: `apps/client/lib/browser/browser_tab.dart`
- Create: `apps/client/lib/browser/browser_adapter.dart`
- Create: `apps/client/lib/browser/android_webview_adapter.dart`
- Create: `apps/client/lib/browser/windows_webview_adapter.dart`
- Create: `apps/client/lib/browser/download_capture.dart`
- Create: `apps/client/lib/browser/format_sheet.dart`
- Test: `apps/client/test/browser/browser_controller_test.dart`
- Test: `apps/client/test/browser/download_capture_test.dart`
- Test: `apps/client/integration_test/browser_survival_test.dart`

**Interfaces:**
- Consumes: `JobGateway.create`, `JobRepository.upsert`, and generated `Download.png`.
- Produces: `BrowserAdapter.currentUrl`, `navigate`, `back`, `forward`, `reload`, `openTab`, `closeTab`, `cookiesFor(Uri)`; `DownloadCapture.submit(Uri, JobFormat)`.

- [ ] **Step 1: Write failing browser-controller tests**

Cover URL/search normalization, HTTPS enforcement, blocking `file:`, `javascript:`, `intent:`, loopback, and malformed navigation, tab persistence, and back/forward state.

- [ ] **Step 2: Implement the adapter contract and controller**

Use Android WebView and Windows WebView2 behind the same interface. Do not expose a general native bridge to page JavaScript.

- [ ] **Step 3: Write failing capture tests**

Assert that tapping the floating control uses the active tab URL, requires MP4 or MP3 selection, prevents empty/unsafe submissions, creates one local queued job, and never persists cookies.

- [ ] **Step 4: Implement the browser page, floating control, and format sheet**

Use the generated full-color download image and maintain browser state when Queue is selected.

- [ ] **Step 5: Add browser survival integration test**

Navigate a local fixture, set a cookie and form value, switch Browser → Queue → Browser, and assert URL, cookie, and form state remain.

- [ ] **Step 6: Run browser tests**

Run: `flutter test test/browser`

Run: `flutter test integration_test/browser_survival_test.dart -d windows`

Expected: all supported tests PASS; Android equivalent is exercised later on-device.

- [ ] **Step 7: Commit**

Commit message: `feat: add persistent browser and floating download capture`

---

### Task 5: Device-Scoped Cloudflare Job API

**Files:**
- Create: `services/api/wrangler.jsonc`
- Create: `services/api/src/index.ts`
- Create: `services/api/src/auth/device-auth.ts`
- Create: `services/api/src/jobs/job-object.ts`
- Create: `services/api/src/jobs/job-routes.ts`
- Create: `services/api/src/jobs/job-schema.ts`
- Create: `services/api/src/security/url-policy.ts`
- Create: `services/api/src/logging/redaction.ts`
- Test: `services/api/test/jobs.test.ts`
- Test: `services/api/test/url-policy.test.ts`
- Test: `services/api/test/redaction.test.ts`

**Interfaces:**
- Consumes: `contracts/openapi.yaml`.
- Produces: device-authenticated API endpoints; `JobObject` authoritative active state; idempotency key `(deviceId, clientRequestId)`; processor dispatch interface `start(ProcessorRequest)` and `command(jobId, command)`.

- [ ] **Step 1: Write failing authentication and job-route tests**

Assert missing/invalid device credentials receive `401`, cross-device job access receives `404`, malformed state/format receives `400`, and repeated `clientRequestId` returns the original job ID.

- [ ] **Step 2: Run API tests and verify failure**

Run: `npm test --workspace services/api -- jobs.test.ts`

Expected: FAIL because API handlers do not exist.

- [ ] **Step 3: Implement device authentication, schema validation, and Durable Object routes**

Return contract-shaped errors and dispatch to a fake processor binding in tests.

- [ ] **Step 4: Write failing SSRF and redaction tests**

Cover direct and redirected IPv4/IPv6 loopback, RFC1918, link-local, `.local`, integer/hex IP forms, DNS rebinding checks, cloud metadata addresses, cookie headers, signed URLs, and nested exception data.

- [ ] **Step 5: Implement URL policy and structured redaction**

Validate every redirect and resolved address immediately before connecting; log stable identifiers and error codes only.

- [ ] **Step 6: Run API tests**

Run: `npm test --workspace services/api`

Expected: all tests PASS.

- [ ] **Step 7: Commit**

Commit message: `feat: add secure device-scoped job API`

---

### Task 6: Media Processor and Structured Progress

**Files:**
- Create: `services/processor/src/app.py`
- Create: `services/processor/src/models.py`
- Create: `services/processor/src/downloader.py`
- Create: `services/processor/src/direct_download.py`
- Create: `services/processor/src/ytdlp_download.py`
- Create: `services/processor/src/ffmpeg.py`
- Create: `services/processor/src/progress.py`
- Create: `services/processor/src/workspace.py`
- Create: `services/processor/src/secrets.py`
- Create: `services/processor/Dockerfile`
- Test: `services/processor/tests/test_direct_download.py`
- Test: `services/processor/tests/test_ytdlp_download.py`
- Test: `services/processor/tests/test_progress.py`
- Test: `services/processor/tests/test_cleanup.py`

**Interfaces:**
- Consumes: `ProcessorRequest` with job ID, URL, format, callback credential, and ephemeral domain-scoped cookie bundle.
- Produces: progress callbacks matching `ProgressEvent`; a completed local artifact plus metadata; command handling for cancel and capability-reported pause/resume.

- [ ] **Step 1: Write failing direct-download tests**

Use a local HTTP fixture to test known and unknown content lengths, timeout, retryable `5xx`, non-retryable `4xx`, interrupted resume, size limit, cancellation, and sanitized collision-safe filenames.

- [ ] **Step 2: Implement isolated workspace and direct downloader**

Expose `download_direct(request, workspace, progress_sink) -> Artifact` and stream to a job-specific temporary path.

- [ ] **Step 3: Write failing `yt-dlp`/FFmpeg command tests**

Assert MP4 selects video plus audio with an MP4-compatible result, MP3 selects best audio and converts to MP3, arguments are passed without shell interpolation, cookies use an ephemeral file, and user-controlled text cannot become command options.

- [ ] **Step 4: Implement `yt-dlp` and FFmpeg adapters**

Expose `download_with_ytdlp(...) -> Artifact` and `convert_audio_to_mp3(...) -> Artifact`; parse machine-readable output into structured stages and percentages.

- [ ] **Step 5: Write failing cleanup tests**

Assert cookies and partial files are deleted after success, failure, timeout, and cancellation; assert logs never contain test cookie values.

- [ ] **Step 6: Implement guaranteed cleanup and API entry point**

Use `try/finally` around every job workspace and secret lifecycle. Report stable error codes for unsupported URL, authentication required, unavailable media, rate limited, size limit, timeout, conversion failure, and cancelled.

- [ ] **Step 7: Run processor tests and container smoke test**

Run: `pytest services/processor/tests -q`

Run: `docker build -t episode-downloader-processor services/processor`

Expected: tests PASS and image builds successfully.

- [ ] **Step 8: Commit**

Commit message: `feat: add isolated yt-dlp and ffmpeg processor`

---

### Task 7: R2 Delivery, Live Events, and Lifecycle Cleanup

**Files:**
- Create: `services/api/src/jobs/processor-client.ts`
- Create: `services/api/src/jobs/progress-stream.ts`
- Create: `services/api/src/delivery/r2-delivery.ts`
- Create: `services/api/src/delivery/delivery-routes.ts`
- Create: `services/api/src/cleanup/expiry.ts`
- Modify: `services/api/src/jobs/job-object.ts`
- Modify: `services/api/src/index.ts`
- Test: `services/api/test/progress-stream.test.ts`
- Test: `services/api/test/delivery.test.ts`
- Test: `services/api/test/expiry.test.ts`
- Test: `services/api/test/processor-integration.test.ts`

**Interfaces:**
- Consumes: processor progress/artifact result from Task 6 and API state from Task 5.
- Produces: event stream with resumable sequence numbers; short-lived device-scoped delivery URL; `POST delivery` acknowledgement; automatic expiry and partial cleanup.

- [ ] **Step 1: Write failing progress and reconnect tests**

Assert monotonic event sequence, no state regression, reconnect from last sequence, indeterminate progress support, and terminal events delivered exactly once.

- [ ] **Step 2: Implement processor binding and progress stream**

Persist the latest authoritative state in `JobObject` and replay missed events within the bounded active-job window.

- [ ] **Step 3: Write failing delivery tests**

Assert wrong-device access fails, signatures expire, an interrupted transfer does not delete R2 output, a valid size/hash acknowledgement deletes it, and duplicate acknowledgement is harmless.

- [ ] **Step 4: Implement R2 upload, signed delivery, and acknowledgement**

Return no permanent object URL. Bind the delivery token to device, job, expiry, expected size, and hash.

- [ ] **Step 5: Write failing expiry tests**

Assert abandoned output, processor partials, job secrets, and stale active metadata expire at configured bounds while delivered local history is unaffected.

- [ ] **Step 6: Implement scheduled cleanup and integration path**

Exercise fake processor → progress → R2 → delivery → acknowledgement as one API test.

- [ ] **Step 7: Run API integration tests**

Run: `npm test --workspace services/api`

Expected: all tests PASS.

- [ ] **Step 8: Commit**

Commit message: `feat: stream progress and verify temporary delivery`

---

### Task 8: Real Client Synchronization, Authenticated Capture, and File Saving

**Files:**
- Create: `apps/client/lib/api/api_client.dart`
- Create: `apps/client/lib/api/device_identity.dart`
- Create: `apps/client/lib/api/remote_job_gateway.dart`
- Create: `apps/client/lib/sync/job_synchronizer.dart`
- Create: `apps/client/lib/delivery/file_delivery.dart`
- Create: `apps/client/lib/delivery/android_file_delivery.dart`
- Create: `apps/client/lib/delivery/windows_file_delivery.dart`
- Create: `apps/client/lib/browser/cookie_scope.dart`
- Test: `apps/client/test/api/remote_job_gateway_test.dart`
- Test: `apps/client/test/sync/job_synchronizer_test.dart`
- Test: `apps/client/test/browser/cookie_scope_test.dart`
- Test: `apps/client/test/delivery/file_delivery_test.dart`

**Interfaces:**
- Consumes: the API contract, `BrowserAdapter.cookiesFor`, `JobGateway`, and `JobRepository`.
- Produces: persistent secure `deviceId` and credential; real-time reconciliation; verified platform file saving; delivery acknowledgement only after local success.

- [ ] **Step 1: Write failing device identity and gateway tests**

Assert identity survives restart in secure storage, never enters logs, every call is authenticated, create uses a stable client request ID, and contract errors map to readable queue failures.

- [ ] **Step 2: Implement API client, identity, and remote gateway**

Use generated contract types and inject transport, secure storage, and clock for tests.

- [ ] **Step 3: Write failing cookie-scope tests**

Cover exact host, parent-domain cookies, host-only cookies, secure cookies, path scope, expiry, unrelated subdomains, public suffixes, and empty-cookie public pages. Assert serialized job persistence contains none of the cookie values.

- [ ] **Step 4: Implement job-scoped cookie capture**

Pass the ephemeral bundle directly to the request serializer and discard the in-memory value after submission completes or fails.

- [ ] **Step 5: Write failing reconciliation and delivery tests**

Cover restart during active processing, missed progress events, network loss during download, same-name collision, insufficient local storage, hash mismatch, and acknowledgement only after a verified final file exists.

- [ ] **Step 6: Implement synchronizer and platform delivery adapters**

Android saves through the platform download mechanism; Windows saves to the configured folder. Use temporary local names and atomic finalization.

- [ ] **Step 7: Run client integration tests against the local API**

Run: `flutter test test/api test/sync test/browser/cookie_scope_test.dart test/delivery`

Expected: all tests PASS.

- [ ] **Step 8: Commit**

Commit message: `feat: connect clients to secure cloud jobs and delivery`

---

### Task 9: Notifications, Queue Commands, and Re-download

**Files:**
- Create: `apps/client/lib/notifications/notification_service.dart`
- Create: `apps/client/lib/notifications/android_notification_service.dart`
- Create: `apps/client/lib/notifications/windows_notification_service.dart`
- Create: `apps/client/lib/updates/release_service.dart`
- Modify: `apps/client/lib/queue/queue_controller.dart`
- Modify: `apps/client/lib/queue/job_card.dart`
- Test: `apps/client/test/notifications/notification_service_test.dart`
- Test: `apps/client/test/queue/queue_commands_integration_test.dart`
- Test: `apps/client/test/updates/release_service_test.dart`

**Interfaces:**
- Consumes: local state transitions, remote gateway commands, prepared monochrome notification assets, and release endpoint.
- Produces: ongoing progress notification; completed/failed notifications opening the correct queue item; working cancel, retry, re-download, reorder, clear, and capability-gated pause/resume; signed update prompts.

- [ ] **Step 1: Write failing notification tests**

Assert active notifications show title, stage, and measurable percentage; indeterminate jobs omit fake percentages; terminal notifications replace ongoing ones; taps deep-link to the originating local queue record.

- [ ] **Step 2: Implement platform notification services**

Use `Notification.png` derivatives on Android and branded Windows toast assets. Never include credentials or signed URLs.

- [ ] **Step 3: Write failing queue-command integration tests**

Assert cancel cleans up, retry starts a new remote execution, re-download creates a fresh job from saved URL/format without browsing, reorder affects only queued jobs, and clearing history leaves active jobs intact.

- [ ] **Step 4: Connect queue commands to the remote gateway**

Make every command idempotent and reconcile after timeout before showing failure.

- [ ] **Step 5: Write failing release-check tests**

Assert valid newer signed manifests prompt, current/older versions stay quiet, invalid signatures fail closed, and update failure never blocks downloads.

- [ ] **Step 6: Implement release service**

Support Android direct APK and Windows installer metadata while allowing internal Play distribution to disable direct APK prompts.

- [ ] **Step 7: Run feature tests**

Run: `flutter test test/notifications test/queue/queue_commands_integration_test.dart test/updates`

Expected: all tests PASS.

- [ ] **Step 8: Commit**

Commit message: `feat: finish notifications queue controls and updates`

---

### Task 10: Deployment, Packaging, and End-to-End Acceptance

**Files:**
- Create: `infra/wrangler.jsonc`
- Create: `infra/README.md`
- Create: `infra/scripts/deploy.ps1`
- Create: `apps/client/android/key.properties.example`
- Create: `apps/client/windows/installer/installer.wxs`
- Create: `.github/workflows/test.yml`
- Create: `.github/workflows/release.yml`
- Create: `tests/e2e/download-flow.spec.ts`
- Create: `tests/acceptance/android-checklist.md`
- Create: `tests/acceptance/windows-checklist.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: all client and backend components.
- Produces: reproducible Cloudflare deployment, signed Android APK, signed Windows installer/executable, automated test pipeline, and recorded real-device acceptance results.

- [ ] **Step 1: Write failing end-to-end API/client fixture test**

Exercise public MP4, public MP3, authenticated fixture, duplicate submission, cancellation, failure/retry, verified delivery/deletion, and fresh re-download using controlled locally hosted media fixtures rather than third-party sites.

- [ ] **Step 2: Add deployment configuration and secret inventory**

Declare Worker, Durable Object, Container, R2, schedules, limits, and environment bindings. Document required secrets without storing values in Git.

- [ ] **Step 3: Add CI and reproducible release builds**

Run contract, Flutter, Worker, processor, container, and end-to-end tests before packaging. Produce checksums and signed release manifests.

- [ ] **Step 4: Run the complete automated suite**

Run: `make lint`

Run: `make test`

Run: `make build`

Expected: zero lint errors, all tests PASS, Android APK and Windows installer artifacts generated.

- [ ] **Step 5: Perform Android acceptance**

On a real Android device, verify independent login persistence, browser survival, floating capture, both formats, background notification progress, completion, local file opening, failure, cancel, retry, history clear, and re-download.

- [ ] **Step 6: Perform Windows acceptance**

On Windows, verify the same functional flow plus WebView2 persistence, destination selection, filename collision handling, native toast routing, and installer update behavior.

- [ ] **Step 7: Deploy a private production environment**

Deploy Cloudflare resources, set conservative personal-use runtime/storage/concurrency limits, smoke-test one MP4 and one MP3, and verify R2 is empty after acknowledged delivery.

- [ ] **Step 8: Commit**

Commit message: `release: package and verify cross-platform downloader`

---

## Completion Criteria

- `make lint`, `make test`, and `make build` succeed from a clean checkout.
- No tracked file contains a cookie, token, signing key, or Cloudflare credential.
- Android and Windows acceptance checklists are completed with evidence.
- One public and one authenticated controlled fixture complete in both MP4 and MP3 modes.
- R2 output disappears after verified delivery and survives interrupted delivery until expiry.
- Re-download succeeds from local history after prior cloud deletion.
- Queues remain independent across two registered device identities.
- Source artwork remains byte-for-byte unchanged.
