# RiseYT

YouTube enhancement tweak for iOS. Compatible with jailbroken devices (rootless & rootful).

## Features

- **Ad Blocking** — removes all ads (instream, banner, overlay)
- **Premium Unlock** — background playback, Picture-in-Picture, 4K quality
- **Download Manager** — download videos up to 4K/HLS with progress tracking
- **Liquid Glass UI** — frosted glass tab bar and overlay elements
- **High-Res Thumbnails** — forces `maxresdefault` on all thumbnails
- **Settings Panel** — toggle features inside YouTube Settings

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

Stored under `com.riseyt.prefs` in NSUserDefaults.

| Key | Default | Description |
|-----|---------|-------------|
| `riseyt_premium_enabled` | YES | Premium features |
| `riseyt_adblock_enabled` | YES | Ad blocking |
| `riseyt_bgplay_enabled` | YES | Background playback |
| `riseyt_pip_enabled` | YES | Picture-in-Picture |
| `riseyt_liquid_glass` | YES | Liquid Glass UI |
| `riseyt_save_photos` | YES | Save downloads to Photos |

## License

MIT
