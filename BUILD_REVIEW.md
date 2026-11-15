# RiseYT build and source review — 2026-11-16

## Verified build

- Workflow: https://github.com/userpc5661-png/tweakx/actions/runs/43771817608
- Status: **successful**; build and artifact-upload steps passed.
- Output: `RiseYT.dylib` in artifact `RiseYT-dylib`.
- Mach-O: **arm64 dynamically linked iOS library**; 122,968 bytes when extracted.
- SHA-256: `b240358fb1dfdc677d40dca443323c5b49137a8839d5cd89beaad1a2ea9e4c77`.
- Link dependency inspection confirmed **no CydiaSubstrate and no SpringBoard** entries with the internal Logos generator.
- No device installation or YouTube playback test was performed.

## Build corrections

The former CI workflow failed while installing Theos (GitHub API SDK lookup). The new workflow uses a tested Theos + SDK action and generates a downloadable artifact. Objective-C source/headers were aligned, missing model/controller methods implemented, deprecated UIKit calls repaired, and notification authorization given a nonnull callback. `%config(generator=internal)` avoids external hooking library linkage for direct IPA injection.

## Known functionality gaps / runtime risks

1. **Downloading YouTube videos is not implemented correctly.** The download handler passes `https://www.youtube.com/watch?v=<videoID>` directly to `NSURLSessionDownloadTask` and saves the response with `.mp4`. That is a watch page, not a direct playable MP4 stream; selecting a quality label does not resolve an audio/video stream.
2. **The settings switches do not control many hooks.** Many hooks return fixed `YES`/`NO` and do not consult `riseyt_pref()`. The UI can save toggles while the active hooks remain unchanged.
3. **Undocumented YouTube selectors are not verified.** The project uses a large collection of private YouTube classes. A successful build cannot guarantee those names and method signatures match an installed app version.
4. **Launch-time modifications.** The `%ctor` immediately requests notification authorization and sets the AVAudioSession category. This can affect startup and audio behavior.
5. **HLS downloads need real stream handling.** Using an ordinary download task on a manifest URL does not automatically assemble HLS media segments into a local movie.
6. **4K / Premium claims remain unverified.** Hard-coding resolution/boolean getters is not equivalent to server-side subscription or format authorization.

## Test plan

1. Start from a clean YouTube IPA with **only this RiseYT.dylib** and use the injector's proper sign/re-sign procedure.
2. Verify app launches. If it crashes, export the latest YouTube `.ips` analytics crash report.
3. Exercise the settings UI, playback, ads, PiP, and downloads **individually**; document YouTube/iOS versions.
4. Validate a downloaded file's actual media container before calling the downloader functional.
5. Recheck runtime behavior after every YouTube update.

**Status: Builds successfully; runtime behavior and feature completeness are not yet validated.**
