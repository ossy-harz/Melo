# Melo 🎵

<div align="center">

![Melo Logo](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png)

### High-Resolution Local & Streaming Audio Player for Android
*Immersive Playback · Real-Time Word-Synced Lyrics · Native Media3 Controls · Dual-Deck Auto-Mix · Bit-Perfect Audio*

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84.svg?style=flat&logo=android&logoColor=white)](https://github.com/ossy-harz/Melo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Latest Release](https://img.shields.io/github/v/release/ossy-harz/Melo?color=FA243C&label=Latest%20APK)](https://github.com/ossy-harz/Melo/releases)
[![Audio Engine](https://img.shields.io/badge/Audio-Bit--Perfect%20USB%20DAC%20%26%20FLAC-orange.svg)](#hi-res-audio--dual-deck-auto-mix)

</div>

---

## 🌟 Overview

**Melo** is a modern, local-first music player crafted for Android listeners who want studio-grade sound, dynamic album-art theming, and distraction-free listening. Combining on-device media indexing, high-bitrate streaming, dual-deck Auto-Mix crossfades, word-by-word synced lyrics, and deep Android Media3 lock-screen & Samsung Media Pill integration, Melo brings local and streaming libraries together in one fast, fluid interface.

---

## ✨ Key Features

### 🌌 Immersive Player Mode & Ambient UI
- **Immersive Full-Screen Mode**: One-tap edge-to-edge playback that gracefully hides the status bar, navigation chrome, and secondary toolbars so album artwork or live lyrics take center stage.
- **Dynamic Album-Art Tinting**: Adaptive atmospheric backgrounds and glows sampled dynamically from each track's cover art.
- **Tappable Queue & Playlist Header**: Tap the playing station or playlist title directly at the top of Now Playing to jump straight into its full tracklist.
- **Fast Multi-Tier Artwork Cache**: Instant LruCache native Android thumbnails, memory/disk cover caching, and parallel catalog enrichment for scrolling without lag.

### 💬 Real-Time Word-by-Word Synced Lyrics
- **Word & Line Synced LRC**: Karaoke-style word-by-word and line-by-line highlighting with smooth auto-centering to the active playback timestamp.
- **Live 3-Line Lyrics Peek**: Inline word-synced preview right above the playback scrubber that expands into the full lyrics sheet on tap.
- **Sync Offset Controls & Automatic Lookup**: Fine-tune timing per song (`-0.5s` / `+0.5s`) and automatically retrieve synced lyrics from LRCLIB or local `.lrc` files.

### 🔔 Native Media3 Notifications & System Controls
- **Android 13+ Lock Screen & Samsung Media Pill**: Full MediaSession integration with dynamic album-art color tinting and compact 3-button controls (`Previous`, `Play / Pause`, `Next`).
- **Custom Notification Actions**: Dedicated **Heart (Like / Unlike)** and **Repeat (`Off` / `All` / `One`)** notification actions that sync instantaneously with your library and player state.
- **Background Playback**: Powered by ExoPlayer and Android foreground MediaService for uninterrupted background listening.

### ❤️ Liked Songs & Playlist Management
- **Instant Heart Save-to-Library**: Tap the Heart button on any local or streaming track to save it into your library and Liked Songs immediately.
- **Sleek Playlist Manager Popup**: Long-press the Heart button or tap **Playlists** to toggle Liked Songs, create a new playlist, or add/remove tracks across playlists with live checkmarks.
- **Curated & Background Downloads**: Save curated stations or download tracks and playlists cleanly in the background with mini-player continuity.

### ⏱️ Customizable Sleep Timer
- **Presets & Custom Duration Slider**: Choose `15m`, `30m`, `45m`, `1h`, `End of current track`, or drag a custom slider from `5` to `120` minutes.
- **Live Countdown & Gentle Fade-Out**: Real-time countdown badge in the Now Playing header and gradual volume fade-out before pausing (automatically restoring your volume level afterward).

### 🎧 Hi-Res Audio & Dual-Deck Auto-Mix
- **Bit-Perfect USB DAC & Output Routing**: Android 14+ exclusive USB DAC bit-perfect mixer routing (`MIXER_BEHAVIOR_BIT_PERFECT`) alongside a quick system media output switcher.
- **5-Band Parametric EQ & Headroom Protection**: Frequency-interpolated EQ presets with automatic peak headroom attenuation and user-volume scaling.
- **Constant-Sum Dual-Deck Crossfades**: Smooth Auto-Mix transitions and rapid track skipping with quiet intro/outro waveform cues and zero overlap volume spikes.

### 📻 Dynamic Home & In-App GitHub Updater
- **Live Time-of-Day Home Feed**: Greeting (`Good morning`, `Good afternoon`, `Good evening`, `Late night vibes`), rotating Stations for You, and preloaded curated picks.
- **Direct GitHub Release Channel**: Automatic version-aware update checks against [`github.com/ossy-harz/Melo/releases`](https://github.com/ossy-harz/Melo/releases) with cached APK install support.

---

## 🧩 Experience & Architecture Highlights

| Area | Highlight |
| :--- | :--- |
| **Playback Engine** | Dual-deck `just_audio` + ExoPlayer pipeline with constant-sum transitions & bit-perfect USB DAC routing |
| **Lyrics Pipeline** | Local sidecar `.lrc`, SAF URI reader, SQLite/prefs cache, and LRCLIB word/line-synced parser |
| **Media3 Integration** | 5-control `PlaybackState` with custom vector icons for Heart (`Like`) and `Repeat` modes |
| **Library & Storage** | Drift / SQLite persistent library, MediaStore scanner, SAF folder indexing, and background downloads |

---

## 📋 Release Changelog

### Version 1.4.4 (Latest)
- **Active Loudness Leveling & Output Routing**: Enabled track-aware loudness attenuation in `MeloAudioHandler` (`getAudioCapabilities` + `_effectiveTargetGain`) and added an **Audio Output & Bit-Perfect USB DAC** switcher card inside **Sound & playback**.
- **Real Cache & Storage Eviction**: Replaced legacy placeholder text in **Offline & data** with live controls to clear artwork/stream caches, cached lyrics, and temporary update APKs.
- **Live Negotiated Codec Badges & Swipeable Mini-Player**: Fixed stale stream quality caching once streaming metadata resolves, and added horizontal swipe-to-skip & vertical swipe-up gestures on `MiniPlayer`.
- **AutoMix Settings Polish**: Selecting a mix profile now resets custom transition duration overrides cleanly and provides a `'Reset to profile default'` button.

### Version 1.4.3
- **Immersive Player Mode**: Added full-screen edge-to-edge mode in Now Playing that collapses navigation chrome and quality badges for distraction-free playback.
- **Word-Synced 3-Line Lyrics Peek**: Upgraded the inline Now Playing lyrics preview to highlight every word in sync with playback.
- **Native Media3 Custom Actions**: Added vector Heart (Like/Unlike) and Repeat (`Off` / `All` / `One`) controls to the Android notification and Samsung Media Pill with automatic artwork syncing.
- **Heart-to-Library & Modern Playlist Popup**: Converted favorites to Heart icons, enabled instant library registration when liking streaming tracks, and added a sleek live playlist manager sheet.
- **Customizable Sleep Timer**: Added custom `5–120` minute slider, live countdown ticker badge in the player header, and smooth fade-out before pause.
- **Next-Track & Auto-Mix Fixes**: Eliminated stale track metadata/duplicate-skip races on rapid Next taps and removed volume spikes during crossfades and preloaded skips.

### Version 1.4.2
- **Fast Multi-Tier Artwork Loading**: Added native 16 MB `LruCache`, Android Q+ `loadThumbnail` fast path, HTTP artwork disk/memory caching, and parallel queue preloading.

### Version 1.4.1
- **Dynamic Home & Smooth Lyrics Scroll**: Live time-of-day greetings, dynamic rotating stations, background curated playlist preloading, instant mid-song scroll on lyrics open, and accurate Melo version matching.

### Version 1.4.0
- **Bit-Perfect USB DAC & Modular Addons**: Android 14+ USB DAC output switcher, persistent addon source priority ordering with diagnostics, long-form/podcast support, and stream-to-playlist saving.

---

## 🛠️ Build & Installation

### Download Ready-to-Install APK
Visit the **[GitHub Releases](https://github.com/ossy-harz/Melo/releases)** page to download the latest APK release for your device (`Melo-v*-universal.apk` or `Melo-v*-arm64-v8a.apk`).

### Building from Source

**Prerequisites:**
- Flutter SDK (Dart SDK `^3.13.5`)
- Android SDK (API 34+) & JDK 17

```bash
# Clone the repository
git clone https://github.com/ossy-harz/Melo.git
cd Melo

# Get dependencies
flutter pub get

# Run analysis & test suite
flutter analyze
flutter test

# Build release APK
flutter build apk --release
```

---

## 📄 Copyright
© 2026 ossy-harz. All rights reserved.
