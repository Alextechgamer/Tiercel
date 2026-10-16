# Tiercel Lab — iOS 26 background download comparison

This experimental standalone test app is separate from Carry, built on the
MIT-licensed Tiercel v3.3.0 framework.
Original LICENSE and upstream copyright notices remain unchanged.

## Purpose

Carry passed foreground 1 MiB downloads and app-folder storage checks on iOS
26.0, but two independent system background URLSession instances reported all
1 MiB transferred then failed with NSURLErrorDomain -3000 before a completed
temporary file reached Carry. The iPhone had over 570 GB free.

Tiercel Lab uses its own app bundle, persisted metadata, files, and independent
background session to determine whether the same failure happens in Tiercel.
It does not replace, read, change, or uninstall Carry.

## Test app

- Bundle: com.alexsoftware.tiercellab (one additional SideStore app ID).
- One public 1,048,576 byte HTTPS test from speed.cloudflare.com.
- User taps Start. No automatic transfer or paid site interaction.
- Status, bytes, redacted NSError codes, saved file length and SHA-256 display.
- Tiercel's recovered task status is available after reopening the app.
- Files saved to On My iPhone > Tiercel Lab > TiercelLabTests > File.
- Test Reset clears ONLY this app's synthetic file and record, after
  confirmation.
- The SHA-256 is a local saved-file fingerprint, not an externally known
  source checksum: Cloudflare can generate different bytes per request.

## Physical iPhone gate

1. Install the unsigned Tiercel Lab IPA using SideStore. Retain and sign
   the embedded Tiercel.framework. This does not replace existing Carry.
2. Start the 1 MiB test. Wait for a terminal status; reopen Tiercel Lab if
   needed to refresh restored task history.
3. Send the Status, Received, Saved file size, and Error code/screenshot.
4. If it succeeds while Carry fails, compare session configuration, app
   signing, cache protection and callbacks before integrating Tiercel.
5. If Tiercel also fails with -3000, replacing Carry's engine alone cannot
   fix that system-level problem. Prioritize independent, durable HTTP Range
   chunk storage and iOS background execution constraints.
6. Do not retry the 565 MiB video or 89 GiB BZZHR archive for this check.

## Simulator test

LabSimulatorTest.sh creates an isolated iOS 26 Simulator and removes it
after completion. Only on Simulator the Tiercel framework uses the normal
in-process URLSession, because macOS cloud/local Simulator tests cannot
prove the out-of-process iPhone background daemon. Physical iOS continues
to use URLSessionConfiguration.background(withIdentifier:).

A DEBUG Simulator launch switch explicitly starts the 1 MiB test and saves
redacted JSON and a screenshot, validating 1,048,576 bytes received and
saved plus a 64-character SHA-256. This is NOT a background-daemon proof.

## Reproducible Mac build

Run: bash LabBuildIPA.sh

This builds the physical iOS ARM64 app on Xcode, checks the unique bundle
ID, validates the embedded framework and archive, and produces an unsigned
IPA plus SHA256SUMS in LabBuild/release. SideStore must sign it.

The app is a development diagnostic, not App Store-ready. Do not merge the
experimental lab onto upstream master until physical device proof passes.

Project practices: the owner's Alextechgamer/agent-skills planning, iOS UI
audit, reviewing-agent-work and verification-before-completion skills.
