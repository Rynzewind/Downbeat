# Downbeat first-build test checklist

## Android

1. Install `Downbeat-android-arm64-test.apk` and allow notifications when requested.
2. Browse to a public video, tap the floating download icon, and try Video (MP4).
3. Repeat with Audio only (MP3); confirm the saved file opens in another app.
4. Share a link from TikTok, Facebook, or a browser to Downbeat and confirm the format sheet opens.
5. Switch to Queue during a download and verify status/progress. Try Cancel, Retry, and Redownload.
6. Sign in inside Downbeat and try a permitted page that needs that session.

## Windows

1. Extract the entire ZIP before opening `Downbeat.exe`; do not run it from inside the ZIP.
2. Browse to a public video and test both formats.
3. Confirm completed files appear in Downloads and survive clearing the queue.

## Expected limitations

- DRM/protected streams are not bypassed.
- Some sites actively block automated download clients or change frequently and may fail until the bundled extractor is updated.
- This is a test-signed APK; Android may warn that it is from an unknown source.
