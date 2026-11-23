# Compás Remote — iOS / iPadOS / watchOS port

An unofficial work-in-progress port of the [Compás Remote companion app](https://github.com/Starnished66/compas-app) to Apple platforms. Compás is custom firmware for the HiBy R1 ([compasplayer.org](https://compasplayer.org/)); this app is a remote control for it.

The upstream app is built with Expo / React Native, so the shared TypeScript UI and logic run on iOS largely unchanged. This fork adds iOS (Swift) implementations of the native modules in `modules/`.

## Status

| Area | iOS status |
|---|---|
| Wi-Fi connection (Bonjour discovery, PIN, playback, library) | Working; tested against a real R1 |
| File transfers (Transfer tab) | Working: browses the app's Music folder (Files › On My iPhone › compás › Music) and the player's SD card; upload tested on a real R1 |
| Bluetooth connection | **Not supported on iOS** — the player uses Bluetooth Classic RFCOMM, which iOS only allows for MFi-certified accessories |
| Lock-screen controls | Later |
| In-app self-updates | Not applicable — App Store builds update through the App Store |
| iPad layout | Planned (Phase 3) |
| Apple Watch | Planned (Phase 4, separate SwiftUI target) |

## Roadmap

0. Tooling, fork, README ✓
1. Stub native modules so the app launches in the iOS Simulator ✓
2. Swift Wi-Fi discovery; test on a real R1 ✓
3. Polish: iPad orientation, icons, privacy strings, iOS wording, native file transfers ← *next*
4. Apple Watch companion
5. TestFlight and App Store

## Building (macOS)

Requirements: Xcode, [Homebrew](https://brew.sh), Node.js and CocoaPods.

```bash
brew install node cocoapods
npm install
npx expo run:ios
```

## Branches and upstream

- `main` tracks upstream (`Starnished66/compas-app`).
- `ios-port` holds the iOS work. The aim is to offer it back upstream as a pull request.

To pull in upstream changes:

```bash
git fetch upstream && git merge upstream/main
```

## License and credit

All original app code is by the Compás authors. See [LICENSE](LICENSE) and the upstream repository. This port isn't affiliated with or endorsed by the Compás project or HiBy unless they say otherwise.
