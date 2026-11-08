# Melo 🎵

<div align="center">

![Melo Logo](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png)

### Pure Local & Streaming Audio Experience
*Lossless Hi-Res Audio · Dynamic Ambient Theming · Seamless DJ Auto-Mix · Synchronized Lyrics*

[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84.svg?style=flat&logo=android&logoColor=white)](https://github.com/ossy-harz/Tone/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/ossy-harz/Tone?color=green&label=Latest%20APK)](https://github.com/ossy-harz/Tone/releases)
[![Audio Engine](https://img.shields.io/badge/Audio-24--bit%20192kHz%20FLAC-orange.svg)](#hi-res-audio--lossless-engine)

</div>

---

## 🌟 Overview

**Melo** is a modern, high-fidelity music player crafted for listeners who value pristine audio quality, elegant album-art-first aesthetics, and a clean, distraction-free user experience. Designed with design principles inspired by Apple Music and Spotify, Melo combines local device scanning, lossless FLAC streaming, automatic synchronized lyrics, and seamless dual-deck transitions into one unified, fluid experience.

---

## ✨ Key Features

### 🎧 Hi-Res Audio & Lossless Engine
- **Bit-Perfect Playback**: Full support for 24-bit 192kHz FLAC, ALAC, WAV, and high-bitrate MP3/AAC.
- **Parametric 5-Band Equalizer**: Custom frequency adjustments, logarithmic frequency interpolation, and RMS loudness leveling.
- **Waveform Seek Bar**: Real-time decoded audio-amplitude waveform representation with accurate seek feedback.

### 🎨 Modern Ambient UI
- **Dynamic Color Tinting**: Backgrounds and ambient lighting organically adapt to current album artwork.
- **Hero Playlist Detail Screens**: Large artwork cover cards, rich artist summaries, curated badges, and floating action bars with quick play, shuffle, and share.
- **Floating Mini-Player Dock**: Frosted-glass bottom navigation dock with responsive playback scrubber and instant gesture expansion.
- **Pull-to-Scan Accessibility**: Swipe down anywhere in the Library to instantly refresh and index device audio without intrusive button walls.

### 🔄 Dual-Deck Smart Auto-Mix
- **Continuous DJ Crossfade**: Seamless background preloading and equal-power volume ramping between songs.
- **BPM & Energy Matching**: Smart transitions that align with tempo tags for continuous listening sessions.
- **Manual "Mix Next" Control**: Skip ahead anytime with an immediate smooth ramp into the upcoming track.

### 🎤 Synchronized Lyrics
- **Automatic Real-Time Sync**: Synchronized line-by-line scrolling that tracks audio position with millisecond accuracy.
- **Karaoke Syllable & Word Highlighting**: Enhanced word-timed LRC support for an immersive sing-along experience.
- **Zero-Click LRCLIB Integration**: Automatically retrieves lyrics in the background without requiring manual clicks.

### 📻 Dynamic Smart Stations
- **Personalized Radios**: Real-time station generation using local library preferences, genre tags, and playback habits.
- **Living Artwork Overlays**: Station cards feature real track covers with dynamic gradient overlays.

### 🚀 Seamless In-App Updates
- **Direct GitHub Release Channel**: Instant update notifications connected to [GitHub Releases](https://github.com/ossy-harz/Tone/releases).
- **Download Cache Awareness**: Recognizes pre-downloaded APKs and prompts immediate installation without wasteful re-downloads.

---

## 📱 Screenshots & Design

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Home & Dynamic Stations</b></td>
      <td align="center"><b>Hero Playlist View</b></td>
      <td align="center"><b>Now Playing & Ambient Glow</b></td>
    </tr>
    <tr>
      <td><img src="https://raw.githubusercontent.com/ossy-harz/Tone/main/docs/screenshots/home.png" width="240" alt="Home Screen"/></td>
      <td><img src="https://raw.githubusercontent.com/ossy-harz/Tone/main/docs/screenshots/playlist.png" width="240" alt="Playlist Screen"/></td>
      <td><img src="https://raw.githubusercontent.com/ossy-harz/Tone/main/docs/screenshots/now_playing.png" width="240" alt="Now Playing Screen"/></td>
    </tr>
  </table>
</div>

---

## 📋 Release Changelog

### Version 1.0.1 (Latest)
- **Spotify & Apple-Inspired Playlist Detail View**: Added hero 216x216 cover card, artist summary subtitle, curator pill badge, and Spotify-style green circular play button.
- **Clean Pull-to-Scan Library**: Replaced cluttered button walls with a modern Apple Music header and pull-to-refresh library scanning.
- **Cached APK Update Awareness**: App updater now detects already downloaded APKs when returning from system permission prompts and triggers installation directly.
- **Automatic Lyrics Lookup**: Song playback now automatically fetches synced lyrics from LRCLIB when local sidecar files are absent.
- **Dynamic Stations with Real Artwork**: Smart station cards now display live dynamic track artwork and atmospheric gradient backgrounds.
- **Rebranding to Melo**: Updated UI names, internal identifiers, and brand presence across all screens.

### Version 1.0.0
- Initial production release.
- Dual-Deck AutoMix engine with equal-power gain curves.
- Synchronized line and word-level LRC lyrics renderer.
- On-device media store scanner and persistent SAF folder indexing.
- 5-band parametric EQ and decoded audio waveform visualization.

---

## 🛠️ Build & Installation

### Download Ready-to-Install APK
Head to the **[GitHub Releases](https://github.com/ossy-harz/Tone/releases)** page to download the latest `melo-v1.0.1.apk`.

### Building from Source

**Prerequisites:**
- Flutter 3.29.x or higher
- Android SDK (API 34+)

```bash
# Clone the repository
git clone https://github.com/ossy-harz/Tone.git
cd Tone

# Get dependencies
flutter pub get

# Run analysis & test suite
flutter analyze
flutter test

# Build release APK
flutter build apk --release
```

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
