# Downbeat Local Test Builds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce installable Android APK and Windows EXE test builds that browse, accept shared links, download MP4 or MP3 locally, show real queue progress, and save verified output to Downloads.

**Architecture:** Preserve the Flutter Browser/Queue shell and replace simulated/remote job behavior with a platform-neutral `LocalJobCoordinator`. Windows executes pinned private `yt-dlp` and FFmpeg tools through a Dart adapter; Android invokes pinned native libraries through a Kotlin method/event-channel bridge and runs jobs in a foreground service. Both platforms emit the same structured events into the existing SQLite repository.

**Tech Stack:** Flutter/Dart 3.13, Kotlin/JVM 17, Android API 24+, `dev.ffmpegkit-maintained:yt-dlp-android:2.0.2`, `dev.ffmpegkit-maintained:ffmpeg-kit-full:8.1.7`, Python 3.13 processor tests, SQLite, PowerShell packaging, CMake/MSIX-compatible Windows runner.

**Spec:** `docs/superpowers/specs/2026-10-18-downbeat-local-processing-design.md`

## Global Constraints

- Product name is **Downbeat** on Android and Windows.
- Android supports `arm64-v8a` physical devices and `x86_64` emulators, with minimum API 24.
- Android processes one job at a time.
- Each device has an independent local queue; no server, pairing, cloud queue, or cloud media storage is used.
- Only HTTPS source URLs are accepted.
- Cookies are scoped to the target site, isolated per job, redacted from logs, and deleted on every terminal path.
- DRM circumvention is out of scope.
- Completion requires a non-empty verified file published to the user-visible Downloads location.
- The initial test artifacts may use test signing; production signing and automatic component updates follow hands-on validation.
- Run Flutter commands from `apps/client`; run Python, PowerShell, and repository commands from the repository root unless a step says otherwise.

## Review Focus

- A shared message containing extra prose and multiple URLs selects the first valid HTTPS URL and never executes non-URL text; Task 1 pins this in parser and coordinator tests.
- A title containing Windows/Android-invalid characters, reserved names, or duplicate names produces a safe unique output; Task 3 pins this in delivery tests.
- Cancellation during download or conversion kills the owned work only, deletes secrets/partials, and persists Cancelled; Tasks 2, 4, and 6 pin this.
- Process death, reboot, or app restart never turns an incomplete artifact into Completed; Tasks 2 and 6 pin recovery reconciliation.
- Unknown total size or malformed tool progress produces an indeterminate UI state rather than NaN, a false percentage, or a crash; Tasks 2 and 5 pin event parsing and UI behavior.

---

### Task 1: Local Processing Contracts and Branding

**Files:**
- Create: `apps/client/lib/processing/local_processor.dart`
- Create: `apps/client/lib/processing/processing_event.dart`
- Create: `apps/client/test/processing/processing_event_test.dart`
- Modify: `apps/client/lib/jobs/job.dart`
- Modify: `apps/client/lib/browser/browser_page.dart`
- Modify: `apps/client/lib/app.dart`
- Modify: `apps/client/pubspec.yaml`
- Modify: all `apps/client/test/**/*.dart` imports from `package:episode_downloader` to `package:downbeat` as one mechanical rename
- Modify: `apps/client/android/app/build.gradle.kts`
- Move: `apps/client/android/app/src/main/kotlin/app/episode/downloader/episode_downloader/MainActivity.kt` to `apps/client/android/app/src/main/kotlin/app/downbeat/client/MainActivity.kt`
- Modify: `apps/client/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/client/windows/runner/Runner.rc`

**Interfaces:**
- Produces: `abstract interface class LocalProcessor { Stream<ProcessingEvent> run(LocalProcessRequest request); Future<void> cancel(String jobId); }`
- Produces: `LocalProcessRequest(jobId, sourceUrl, format, workspacePath, cookieFilePath)` and sealed `ProcessingEvent` variants `stage`, `progress`, `artifact`, and `failure`.
- Produces: `Job.localSequence`, `Job.bytesReceived`, `Job.totalBytes`, and `Job.outputPath`; remove remote-only naming from new execution paths while retaining a database migration reader for `remoteSequence`.

- [ ] **Step 1: Write failing contract tests**

Add tests asserting percentage clamping to `0..100`, null totals remain indeterminate, a shared message chooses its first valid HTTPS URL, and non-HTTPS input is rejected.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `flutter test test/processing/processing_event_test.dart test/sharing/shared_url_parser_test.dart`

Expected: FAIL because the local processing contracts and new fields do not exist.

- [ ] **Step 3: Add the local contracts and update product identifiers**

Implement the exact interfaces above. Rename Dart package metadata to `downbeat`, Android namespace/application ID to `app.downbeat.client`, Kotlin package to `app.downbeat.client`, and Windows resource display strings to Downbeat. Keep stored database compatibility explicit rather than silently discarding existing test history.

- [ ] **Step 4: Run contract, model, sharing, and static checks**

Run: `flutter test test/processing test/jobs test/sharing && flutter analyze`

Expected: all tests pass and analysis reports no issues.

- [ ] **Step 5: Commit**

```bash
git add apps/client
git commit -m "refactor: define local processing contracts"
```

### Task 2: Local Job Coordinator and Recovery

**Files:**
- Create: `apps/client/lib/processing/local_job_coordinator.dart`
- Create: `apps/client/lib/processing/job_workspace.dart`
- Create: `apps/client/test/processing/local_job_coordinator_test.dart`
- Create: `apps/client/test/processing/job_workspace_test.dart`
- Modify: `apps/client/lib/jobs/job_repository.dart`
- Modify: `apps/client/lib/storage/database.dart`

**Interfaces:**
- Consumes: `LocalProcessor.run`, `LocalProcessor.cancel`, `ProcessingEvent`, and `JobRepository` from Task 1.
- Produces: `LocalJobCoordinator.submit(Uri, JobFormat, {String? cookieHeader})`, `cancel(String)`, `retry(String)`, `redownload(String)`, `start()`, and `dispose()`.
- Produces: `JobWorkspace.create(root, jobId)`, `writeCookieFile(String)`, and idempotent `cleanup()`.

- [ ] **Step 1: Write failing coordinator tests**

Use a fake processor to assert FIFO single-job scheduling, stage/progress persistence, unknown-total handling, terminal cleanup, job-specific cancellation, retry with a new attempt, fresh re-download with a new ID, and startup reconciliation that marks an interrupted non-resumable conversion Failed rather than Completed.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/processing/local_job_coordinator_test.dart test/processing/job_workspace_test.dart`

Expected: FAIL because coordinator and workspace do not exist.

- [ ] **Step 3: Implement coordinator and schema migration**

Implement one active job on Android and a configurable limit with default one on Windows. Persist every state transition transactionally. Migrate existing rows without data loss and add output path/byte fields. Guarantee workspace cleanup in `finally`, including cancellation and malformed processor events.

- [ ] **Step 4: Run processing and repository tests**

Run: `flutter test test/processing test/jobs test/storage`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/client/lib/processing apps/client/lib/jobs apps/client/lib/storage apps/client/test
git commit -m "feat: coordinate local download jobs"
```

### Task 3: Verified Local File Delivery

**Files:**
- Modify: `apps/client/lib/delivery/file_delivery.dart`
- Modify: `apps/client/lib/delivery/android_file_delivery.dart`
- Modify: `apps/client/lib/delivery/windows_file_delivery.dart`
- Modify: `apps/client/lib/jobs/filename.dart`
- Modify: `apps/client/test/delivery/file_delivery_test.dart`
- Modify: `apps/client/test/jobs/filename_test.dart`

**Interfaces:**
- Consumes: artifact event path, filename, media type, size, and optional digest from Task 1.
- Produces: `Future<DeliveredFile> deliver(ProcessorArtifact artifact)` where `DeliveredFile` contains final path/URI, byte size, and verified digest when supplied.

- [ ] **Step 1: Extend failing delivery tests**

Assert zero-byte rejection, size/digest mismatch rejection, atomic temporary naming, collision suffixes, invalid characters, Windows reserved names, long Unicode names, Android content-URI delivery, and cleanup after a failed copy.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/delivery/file_delivery_test.dart test/jobs/filename_test.dart`

Expected: FAIL on the new verification and edge cases.

- [ ] **Step 3: Implement verified platform delivery**

Use a `.downbeat-part` destination, verify before the final rename/publish, and never overwrite an existing file. Windows resolves the Downloads known folder; Android publishes through MediaStore on supported API levels.

- [ ] **Step 4: Run focused and full Flutter tests**

Run: `flutter test test/delivery test/jobs && flutter test`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/client/lib/delivery apps/client/lib/jobs apps/client/test
git commit -m "feat: verify and publish local downloads"
```

### Task 4: Windows Local Processor and Runtime Bundle

**Files:**
- Create: `apps/client/lib/processing/windows_local_processor.dart`
- Create: `apps/client/lib/processing/tool_progress_parser.dart`
- Create: `apps/client/test/processing/windows_local_processor_test.dart`
- Create: `apps/client/test/processing/tool_progress_parser_test.dart`
- Create: `tools/runtime/windows-runtime.json`
- Create: `tools/fetch_windows_runtime.ps1`
- Create: `tools/test/fetch_windows_runtime.Tests.ps1`
- Modify: `apps/client/windows/CMakeLists.txt`
- Modify: `services/processor/src/models.py`
- Modify: `services/processor/src/downloader.py`
- Modify: `services/processor/src/ytdlp_download.py`
- Modify: `services/processor/tests/test_ytdlp_download.py`

**Interfaces:**
- Consumes: `LocalProcessor` and `LocalProcessRequest` from Task 1.
- Produces: `WindowsLocalProcessor(runtimeDirectory, environment)` using argument lists only, never a shell command string.
- Produces: line-delimited progress mapping for `fetching`, `downloading`, `converting`, artifact, and categorized failure.

- [ ] **Step 1: Write failing parser, cancellation, and manifest tests**

Assert representative `yt-dlp` progress, missing totals, FFmpeg stage messages, hostile URL characters passed as one argument, cancellation of the owned process tree, secret redaction, pinned HTTPS URLs, and required SHA-256 values in the runtime manifest.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/processing/windows_local_processor_test.dart test/processing/tool_progress_parser_test.dart`

Run: `Invoke-Pester tools/test/fetch_windows_runtime.Tests.ps1`

Expected: FAIL because the adapter, parser, and manifest do not exist.

- [ ] **Step 3: Implement the Windows adapter and deterministic runtime fetch**

Pin exact `yt-dlp.exe` and FFmpeg archive release URLs plus SHA-256 digests in the JSON manifest. Fetch into an ignored cache, verify before extraction, and stage only required binaries/licenses beside the packaged app. Adapt reusable processor selection logic to local request fields and remove callback requirements from core processing models without changing the obsolete HTTP service tests unintentionally.

- [ ] **Step 4: Run Windows, processor, and security tests**

Run: `flutter test test/processing && python -m pytest services/processor/tests -q`

Expected: PASS with no cookie values in output.

- [ ] **Step 5: Commit**

```bash
git add apps/client/lib/processing apps/client/test/processing apps/client/windows services/processor tools
git commit -m "feat: process downloads locally on Windows"
```

### Task 5: Connect Real Processing to Browser and Queue

**Files:**
- Modify: `apps/client/lib/browser/browser_page.dart`
- Modify: `apps/client/lib/navigation/app_shell.dart`
- Modify: `apps/client/lib/queue/queue_page.dart`
- Modify: `apps/client/lib/queue/job_card.dart`
- Modify: `apps/client/lib/app.dart`
- Modify: `apps/client/lib/main.dart`
- Delete: `apps/client/lib/api/api_client.dart`
- Delete: `apps/client/lib/api/device_identity.dart`
- Delete: `apps/client/lib/api/remote_job_gateway.dart`
- Delete: `apps/client/lib/sync/job_synchronizer.dart`
- Delete: `apps/client/test/api/remote_job_gateway_test.dart`
- Delete: `apps/client/test/sync/job_synchronizer_test.dart`
- Modify: `apps/client/test/browser/download_capture_test.dart`
- Modify: `apps/client/test/queue/job_card_test.dart`
- Modify: `apps/client/test/navigation/app_shell_test.dart`

**Interfaces:**
- Consumes: `LocalJobCoordinator` from Task 2 and delivered output from Task 3.
- Produces: Browser submission into real local jobs and Queue actions `cancel`, `retry`, `redownload`, `open`, and `remove`.

- [ ] **Step 1: Write failing widget tests**

Assert the format sheet labels MP4 as Video and MP3 as Audio only, submission calls the coordinator once, Browser remains mounted while Queue is active, unknown progress is indeterminate, byte progress is human-readable, Cancel targets the correct job, and Open is available only after verified completion.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/browser/download_capture_test.dart test/queue/job_card_test.dart test/navigation/app_shell_test.dart`

Expected: FAIL while the UI still uses simulated progress.

- [ ] **Step 3: Replace simulation and remote synchronization wiring**

Inject the coordinator into `BrowserPage` and `QueuePage`; remove the production `simulateProgress` path and keep fakes only in tests. Remove the obsolete remote gateway/synchronizer from the client. Map categorized failures to concise messages without displaying raw secrets or tool command lines.

- [ ] **Step 4: Run all Flutter tests and analysis**

Run: `flutter test && flutter analyze`

Expected: PASS and no analysis issues.

- [ ] **Step 5: Commit**

```bash
git add apps/client/lib apps/client/test
git commit -m "feat: connect Downbeat UI to local jobs"
```

### Task 6: Android Downloader Bridge and Foreground Service

**Files:**
- Create: `apps/client/lib/processing/android_local_processor.dart`
- Create: `apps/client/test/processing/android_local_processor_test.dart`
- Create: `apps/client/android/app/src/main/kotlin/app/downbeat/client/DownloadBridge.kt`
- Create: `apps/client/android/app/src/main/kotlin/app/downbeat/client/DownbeatDownloadService.kt`
- Create: `apps/client/android/app/src/main/kotlin/app/downbeat/client/DownloadNotification.kt`
- Create: `apps/client/android/app/src/test/kotlin/app/downbeat/client/DownloadBridgeTest.kt`
- Create: `apps/client/android/app/src/test/kotlin/app/downbeat/client/DownloadNotificationTest.kt`
- Modify: `apps/client/android/app/src/main/kotlin/app/downbeat/client/MainActivity.kt`
- Modify: `apps/client/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/client/android/app/build.gradle.kts`
- Modify: `apps/client/pubspec.yaml`
- Add: Android notification resources derived from `apps/client/assets/notification_*.png`

**Interfaces:**
- Consumes: `LocalProcessor` from Task 1 and coordinator cancellation/recovery from Task 2.
- Produces: Flutter method channel `app.downbeat/processor` methods `start`, `cancel`, and `recover`; event channel `app.downbeat/processor-events` with the Task 1 event schema.
- Produces: foreground service notification channel `downbeat_downloads` with open-queue and cancel actions.

- [ ] **Step 1: Add failing Dart and Kotlin bridge tests**

Assert request serialization, one active Android job, MP4/MP3 option construction, cookie-file argument scoping, progress event translation, malformed native event rejection, cancellation, restart recovery, and notification text for determinate and indeterminate work.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/processing/android_local_processor_test.dart`

Run: `apps/client/android/gradlew.bat -p apps/client/android testDebugUnitTest`

Expected: FAIL because the bridge and service do not exist.

- [ ] **Step 3: Add pinned Android runtimes and native bridge**

Pin `dev.ffmpegkit-maintained:yt-dlp-android:2.0.2` and the non-GPL `dev.ffmpegkit-maintained:ffmpeg-kit-full:8.1.7`; restrict ABIs to `arm64-v8a` and `x86_64`; set minimum API 24. Initialize in app-private storage, route structured progress through the event channel, invoke FFmpeg for merge/audio conversion, and keep raw cookie values out of event payloads.

- [ ] **Step 4: Implement foreground execution and notification controls**

Declare only required permissions and the correct foreground-service type. Persist the active job checkpoint before starting work, update the supplied monochrome icon notification, route Cancel to the owned native work, and expose recovery state after process recreation.

- [ ] **Step 5: Run Android unit tests and build a debug APK**

Run: `flutter test && flutter build apk --debug --target-platform android-arm64`

Expected: tests pass and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 6: Commit**

```bash
git add apps/client
git commit -m "feat: download locally in Android foreground service"
```

### Task 7: Browser Cookies and Shared-Link Completion

**Files:**
- Create: `apps/client/lib/browser/browser_cookie_exporter.dart`
- Create: `apps/client/test/browser/browser_cookie_exporter_test.dart`
- Modify: `apps/client/lib/browser/native_browser_surface.dart`
- Modify: `apps/client/lib/browser/native_browser_surface_io.dart`
- Modify: `apps/client/lib/browser/cookie_scope.dart`
- Modify: `apps/client/lib/sharing/shared_text_receiver.dart`
- Modify: `apps/client/android/app/src/main/kotlin/app/downbeat/client/MainActivity.kt`
- Modify: `apps/client/test/sharing/shared_text_receiver_test.dart`

**Interfaces:**
- Produces: `Future<String?> cookieHeaderFor(Uri target)` returning only matching secure/domain/path cookies.
- Consumes: `LocalJobCoordinator.submit(..., cookieHeader:)` from Task 2.

- [ ] **Step 1: Write failing cookie and lifecycle tests**

Assert domain/path/secure matching, no unrelated cookies, empty-cookie behavior, share cold start, share while running, repeated intent delivery exactly once, and temp cookie cleanup after success/failure/cancel.

- [ ] **Step 2: Run tests and verify failure**

Run: `flutter test test/browser test/sharing`

Expected: FAIL for the new exporter and resumed-share cases.

- [ ] **Step 3: Implement scoped export and complete intent routing**

Use platform WebView cookie APIs, convert only applicable values to the processor cookie format inside the job workspace, and erase the file through coordinator cleanup. Keep the active shared URL in the browser and open the format sheet on both cold and warm delivery.

- [ ] **Step 4: Run browser, sharing, processing, and full tests**

Run: `flutter test test/browser test/sharing test/processing && flutter test`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/client/lib/browser apps/client/lib/sharing apps/client/android apps/client/test
git commit -m "feat: pass scoped browser sessions to local downloads"
```

### Task 8: Package and Smoke-Test the First APK and EXE

**Files:**
- Create: `tools/build_test_release.ps1`
- Create: `docs/testing/downbeat-test-build-checklist.md`
- Modify: `README.md`
- Modify: `.gitignore`
- Modify: `apps/client/windows/CMakeLists.txt`

**Interfaces:**
- Consumes: working Android and Windows local processors from Tasks 4 and 6.
- Produces: `dist/Downbeat-android-arm64-test.apk` and `dist/Downbeat-windows-x64-test.zip` containing `Downbeat.exe`, Flutter runtime files, verified downloader tools, FFmpeg, and notices.

- [ ] **Step 1: Write the packaging preflight checks**

Make the build script fail if branding is wrong, runtime files/checksums are missing, the APK lacks arm64 native libraries or required service declarations, the Windows bundle omits a DLL/tool/licence, or either output contains a server URL or credential.

- [ ] **Step 2: Run preflight and verify it fails before artifacts exist**

Run: `powershell -ExecutionPolicy Bypass -File tools/build_test_release.ps1 -PreflightOnly`

Expected: FAIL with explicit missing-artifact diagnostics.

- [ ] **Step 3: Implement reproducible test packaging**

Fetch and verify the Windows runtime, run all automated tests, build the arm64 debug/test-signed APK and Windows release bundle, include third-party notices, calculate SHA-256 files, and copy only distributable files into ignored `dist/`.

- [ ] **Step 4: Build both artifacts**

Run: `powershell -ExecutionPolicy Bypass -File tools/build_test_release.ps1`

Expected: both named artifacts and matching `.sha256` files exist under `dist/`.

- [ ] **Step 5: Perform clean-machine smoke tests**

Follow `docs/testing/downbeat-test-build-checklist.md` on a real arm64 Android device and Windows x64 machine. Verify one direct public MP4, one representative supported page, one MP3 conversion, background notification, cancellation, completed file opening, app restart, and fresh re-download. Record site-specific failures without weakening completion verification.

- [ ] **Step 6: Run final automated verification**

Run: `flutter test && flutter analyze`

Run: `python -m pytest services/processor/tests -q`

Run: `powershell -ExecutionPolicy Bypass -File tools/build_test_release.ps1 -PreflightOnly`

Expected: all commands pass.

- [ ] **Step 7: Commit**

```bash
git add tools docs/testing README.md .gitignore apps/client/windows
git commit -m "build: package Downbeat Android and Windows test releases"
```

