# RiseYT

YouTube enhancement tweak for iOS. Compatible with jailbroken devices (rootless & rootful).

## Features

Everything ships in a single `RiseYT.dylib`. Every feature has a switch in **YouTube → Settings → RiseYT** and the switches take effect immediately (Liquid Glass needs a restart).

- **Ad Blocking** — video ads, promoted feed items and ad elements
- **Background Playback** and **Picture-in-Picture** eligibility
- **Premium flags** and **High Resolutions** (client-side flags; server-side limits still apply)
- **Downloads** — download button on the player (and in settings); picks from the streams YouTube's player already has: H.264 video merged with AAC audio into MP4, single-file MP4, or audio-only M4A. Pause / resume / retry / delete, optional save to Photos
- **Liquid Glass UI** — frosted glass tab bar
- **HQ Thumbnails** — upgrades low-res thumbnails to `hqdefault`
- **Hide Autoplay Endscreen**

## Requirements

- iOS 14.0+
- Jailbroken device (rootless recommended)
- [Theos](https://theos.dev) build environment
- Target: `com.google.ios.youtube`

## Build

```bash
export THEOS=/opt/theos
make package
```

Output `.deb` will be in `packages/`.

## Install

```bash
make install THEOS_DEVICE_IP=<device_ip>
```

Or sideload the `.deb` via your preferred package manager (Sileo, Zebra).

## Project Structure

```
RiseYT/
├── Tweak.x              # Main Logos/Theos source
├── Makefile
├── control
├── RiseYT.plist         # SpringBoard bundle filter
└── headers/
    └── RiseYTHeaders.h  # YouTube private class declarations
```

## Preferences

Stored under `com.riseyt.prefs` in NSUserDefaults. All default to `YES`.

| Key | Switch |
|-----|--------|
| `riseyt_adblock_enabled` | Block Ads |
| `riseyt_bgplay_enabled` | Background Playback |
| `riseyt_pip_enabled` | Picture in Picture |
| `riseyt_premium_enabled` | Premium Flags |
| `riseyt_hq_enabled` | High Resolutions |
| `riseyt_download_button` | Download Button |
| `riseyt_save_photos` | Save Downloads to Photos |
| `riseyt_hq_thumbnails` | HQ Thumbnails |
| `riseyt_hide_endscreen` | Hide Autoplay Endscreen |
| `riseyt_liquid_glass` | Liquid Glass UI |

## Limitations

- Live streams, premieres and videos whose streams YouTube doesn't expose to the player can't be downloaded. 4K is usually VP9/AV1, which AVFoundation can't merge, so downloads top out at the highest H.264 quality (normally 1080p).
- Stream links expire after a few hours; retry a failed download after reopening the video.
- Hooks target private YouTube classes and are not verified against every YouTube version.

## License

MIT
