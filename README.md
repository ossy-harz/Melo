# Melo 🎵

<div align="center">

![Melo Logo](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png)

### High-Resolution Local & Streaming Audio Player for Android
*Living Ambient Aurora · Camelot Harmonic DJ Flow · Interactive Synced Lyrics · Audiophile BitChord Signal Chain*

[![Platform](https://img.shields.io/badge/Platform-Android%208.0%2B-3DDC84.svg?style=flat&logo=android&logoColor=white)](https://github.com/ossy-harz/Melo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Latest Release](https://img.shields.io/github/v/release/ossy-harz/Melo?color=FA243C&label=Latest%20APK%20(v1.7.5))](https://github.com/ossy-harz/Melo/releases/latest)
[![Audio Engine](https://img.shields.io/badge/Audio-BitChord%20Float32%20%26%20FLAC-orange.svg)](#-audiophile-signal-chain--hi-res-audio)
[![Release Key](https://img.shields.io/badge/Signed-Official%20Keystore-brightgreen.svg)](https://github.com/ossy-harz/Melo/releases)

</div>

---

## 🌟 Overview

**Melo** is a high-fidelity, local-first music player crafted for listeners who want studio-grade audio, dynamic visual luxury, and intelligent playback flow. 

Combining on-device lossless media indexing, multi-provider cloud streams, **Camelot Wheel harmonic DJ transitions**, **interactive Apple Music-style synced lyrics**, and a **transparent audiophile signal chain**, Melo bridges local libraries and modern streaming into a unified, distraction-free Android experience.

---

## ✨ Key Features

### 🌌 Living Ambient Aurora & Visual Luxury
- **Dynamic Breathing Aurora (`_ArtworkBackdrop`)**: Adaptive radial gradient meshes dynamically sample each album cover's palette, smoothly orbiting color centers and breathing with the music rhythm during playback.
- **Immersive Full-Screen Mode**: One-tap distraction-free listening that gracefully collapses system bars and navigation chrome, putting artwork and live lyrics front and center.
- **Fast Multi-Tier Artwork Caching**: Native Android `LruCache` memory thumbnails, high-resolution disk caching, and parallel queue preloading for fluid 120Hz scrolling.

### 🎚️ Intelligent DJ Flow & Camelot Wheel AutoMix
- **One-Tap "Harmonize DJ Flow"**: Reorders upcoming queue tracks using Camelot Wheel harmonic mixing rules (exact match, relative major/minor, adjacent cadence $\pm 1$ step, or $+2$ energy boost) while minimizing tempo jumps.
- **Harmonic Compatibility Badges**: Real-time transition badges (`EXACT LOCK`, `RELATIVE`, `CADENCE`, `+2 LIFT`) on queue items to preview transition fluidity.
- **Dual-Deck Engine**: Overlapping playback decks with style-specific equal-power crossfades, intro/outro waveform cueing, and zero volume spikes.

### 💬 Interactive Karaoke Synced Lyrics with Haptic Seek
- **Real-Time Word & Line Sync**: Karaoke-style word-by-word and line-by-line highlighting with smooth auto-centering to active vocal timestamps.
- **Tactile Tap-to-Seek**: Tap any lyric line in either the inline preview or full-screen lyrics sheet to instantly seek to that exact moment with light haptic confirmation.
- **Automatic Multi-Source Discovery**: Reads local `.lrc` sidecars, embedded synchronized tags, or retrieves synced lyrics from LRCLIB.

### 🔊 Audiophile Signal Chain & Hi-Res Audio
- **Transparent Signal Path Sheet**: Track Details exposes the complete pipeline: `SOURCE` (e.g. FLAC 96kHz/24-bit, AAC 320kbps) $\rightarrow$ `ENGINE` (Melo BitChord Float32 bit-perfect pipeline) $\rightarrow$ `DEVICE` (active hardware output).
- **Active Output Route Badges**: Real-time hardware status badges for USB DAC, Bluetooth LDAC/aptX, Wired Headphones, and Built-in Speakers.
- **Bit-Perfect USB DAC Routing**: Android 14+ direct USB DAC bit-perfect bypass (`MIXER_BEHAVIOR_BIT_PERFECT`) without Android OS resampling.
- **5-Band Parametric EQ & Peak Headroom**: Logarithmic frequency response with automatic peak headroom limiting to prevent digital clipping.

### 📊 Melo Insights, Moods & Smart Playlists
- **Listening Analytics & Stats**: Local listening metrics, top genres, favorite artists, and total playtime calculated privately on-device.
- **Mood Sessions**: Dynamic dial to steer queue vibes (Energetic, Focused, Chill, Late Night) with tempo and key affinity.
- **Forgotten Gems Rediscovery**: Intelligent surfacing of library tracks you loved but haven't listened to in months.
- **Multi-Provider Editorial Feeds**: Live curated charts and shelves from Apple Music, YouTube Music, Spotify, and Deezer.

### 🔔 Native Android 13+ Media3 & Lock Screen
- **ExoPlayer & Foreground MediaService**: Uninterrupted background playback with full audio focus management, transient call pausing, and noisy audio route detachment.
- **Samsung Media Pill & Lock Screen**: MediaSession integration with dynamic artwork tinting and dedicated **Heart (Like)** and **Repeat** actions.

---

## 🧩 Architectural Foundations

| Layer | Implementation Highlights |
| :--- | :--- |
| **Audio Pipeline** | Dual-deck ExoPlayer (`just_audio`), BitChord Float32 DSP, bit-perfect USB DAC routing, dynamic crossfade volume management |
| **Harmonic Engine** | Camelot Wheel normalization (`1A`–`12B`), deterministic key inference, tempo proximity ranking, greedy queue harmonizer |
| **Lyrics Subsystem** | Sidecar `.lrc` reader, SAF URI parser, SQLite cached store, LRCLIB API client, interactive tap-to-seek gesture detector |
| **Visuals & Motion** | `_ArtworkBackdrop` orbital radial shaders, `MeloGlass` acrylic blur, custom vinyl groove painter, 120Hz-tuned animations |
| **Security & Privacy** | Android Keystore-backed AES/GCM credential storage, zero trackers, permanent release keystore signing |

---

## 📋 Release Changelog Highlights

### Version 1.7.5 (Latest)
- **Official Release Signing**: Restored permanent Melo release keystore (`melokey`) ensuring seamless APK installation and update continuity without signature conflicts.
- **Living Ambient Aurora**: Dynamic breathing radial gradient mesh in Now Playing background that gently orbits and animates during playback.
- **Harmonize DJ Flow**: Camelot Wheel queue reordering with transition badges (`EXACT LOCK`, `RELATIVE`, `CADENCE`, `+2 LIFT`).
- **Interactive Synced Lyrics**: Apple Music-style haptic tap-to-seek on any lyric line.
- **Audiophile Signal Chain Card**: Real-time audio route badging (USB DAC, Bluetooth LDAC, etc.) and complete stage transparency in Track Details.

### Version 1.7.0 – 1.7.4
- **Security Hardening**: Migrated sensitive credentials (Spotify, Subsonic) to hardware-backed Android Keystore storage.
- **Melo Insights Hub**: Added listening statistics, Forgotten Gems, Mood dials, and smart playlist generation.
- **Multi-Provider Feeds**: Live curated highlights and playlists from Apple Music, YouTube Music, and Spotify.
- **Sleep Timer Lifecycle Fixes**: Eliminated fade-out race conditions on user playback resumption.

---

## 🛠️ Build & Installation

### Option 1: Direct Download (Ready-to-Install APK)
Grab the latest release directly from **[GitHub Releases](https://github.com/ossy-harz/Melo/releases/latest)**:
- **`Melo-v1.7.5-arm64-v8a.apk`** (~25 MB) — Optimized slim build for modern 64-bit Android devices *(recommended)*.
- **`Melo-v1.7.5-universal.apk`** (~72 MB) — Universal package compatible with all 32-bit and 64-bit Android devices.

### Option 2: Building from Source

**Requirements:**
- Flutter SDK (Dart SDK `^3.13.5`)
- Android SDK (API 34+) & JDK 17

```bash
# 1. Clone repository
git clone https://github.com/ossy-harz/Melo.git
cd Melo

# 2. Fetch dependencies
flutter pub get

# 3. Verify static analysis and test suite
flutter analyze
flutter test

# 4. Compile signed release APK
flutter build apk --release
```
The compiled binary will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License & Attribution
Designed & developed with ❤️ by **ossy-harz**.
All metadata, album artwork, and streaming APIs respect their respective source platform licenses.
