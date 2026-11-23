# App Store listing kit

Everything App Store Connect asks for, drafted and ready to paste in. Character limits are Apple's; counts are shown where a limit applies.

> **Before submitting:** the name, the bundle ID and the use of "compás" depend on the Compás author's answer. Items marked **⚠︎ author** must be confirmed first. Until then, everything below uses the working name "compás Remote".

---

## 1. App information

| Field | Value | Notes |
|---|---|---|
| **Name** (max 30) | `compás Remote` (13) | ⚠︎ author. If the name isn't allowed, use something like `Remote for Compás` (17), or a name of your own. |
| **Subtitle** (max 30) | `Control your HiBy R1 on Wi-Fi` (29) | |
| **Bundle ID** | `com.<you>.compasremote` | ⚠︎ author. Permanent once registered. The watch app's ID follows it automatically (`.watchkitapp`). |
| **SKU** | `compas-remote-ios` | Internal only; never shown. |
| **Primary category** | Music | |
| **Secondary category** | Utilities | |
| **Content rights** | "Does not contain, show, or access third-party content" | The app only shows music the user already owns, read from their own player. |
| **Age rating** | 4+ | Answer "None" to every content question; see §6. |
| **Price** | Free | |
| **Availability** | All territories | |

## 2. Store page text

### Promotional text (max 170, can be changed without a new review)

```
A remote for Compás on the HiBy R1. Browse your library, manage the queue, send music to the SD card — now on iPhone, iPad and Apple Watch.
```
(139)

### Description (max 4,000)

```
compás Remote turns your iPhone, iPad or Apple Watch into a remote control for the HiBy R1 running the Compás firmware.

Leave the player in your pocket, on your desk or plugged into your hi-fi, and control it from across the room.

NOW PLAYING
• See what's playing, with album art, format and sample rate
• Play, pause, skip, seek, shuffle and repeat
• Set the volume and rate songs
• Reorder or clear the Up Next queue

YOUR LIBRARY
• Browse albums, artists, album artists, songs and genres
• Search your whole collection
• Browse, rename and reorder your playlists
• Album covers are kept on your device for fast browsing

FILE TRANSFER
• Copy music from your iPhone or iPad to the player's SD card over Wi-Fi
• Create, rename and remove folders on the card
• Put files in the Files app under On My iPhone › compás › Music, or drag them in from a Mac with Finder

APPLE WATCH
• See the current song at a glance
• Play, pause and skip from your wrist
• Turn the Digital Crown to change volume

MADE FOR YOUR SETUP
• Finds your player on Wi-Fi automatically, or connect by address
• PIN pairing keeps other people's phones off your player
• Light, dark or automatic appearance, with colours taken from the album art
• Works in 14 languages

REQUIREMENTS
• A HiBy R1 running the Compás firmware, with Remote Control turned on in its settings
• Your iPhone or iPad on the same Wi-Fi network as the player
• Apple Watch control needs the iPhone app nearby

Bluetooth remote control isn't available on iPhone or iPad. The player's Bluetooth remote uses a kind of Bluetooth that iOS only allows for certified accessories, so this app connects over Wi-Fi.

compás Remote is a community-made app and is not affiliated with HiBy.
```

⚠︎ author: add a line here if the Compás project endorses the app, and adjust the last line to match.

### Keywords (max 100, comma-separated, no spaces after commas)

```
hiby,r1,dap,remote,hifi,music player,firmware,flac,audiophile,wifi,playlist,library,transfer
```
(92) Don't repeat words already in the name or subtitle; Apple indexes those separately.

### What's New (first release)

```
First release for iPhone, iPad and Apple Watch.
```

## 3. URLs

| Field | Value |
|---|---|
| **Support URL** (required) | `https://github.com/kambiz/compas-app/issues` |
| **Marketing URL** (optional) | `https://github.com/kambiz/compas-app` |
| **Privacy Policy URL** (required) | A page with the text in §5, for example `docs/app-store/privacy.md` published with GitHub Pages, or a page on compasplayer.org ⚠︎ author |

## 4. App Privacy ("nutrition label")

**Answer: Data Not Collected.**

App Store Connect → App Privacy → "Do you or your third-party partners collect data from this app?" → **No**.

Why that's accurate. Checked against the code on 2026-11-23; recheck before each release.

- There's no analytics, advertising, tracking or crash-reporting service in the app.
- **Player connection:** the player's address and PIN are stored only on the device, in the iOS Keychain and app storage. They're sent only to the user's own player on their local network.
- **Library cache:** the library catalogue and album covers are cached on the device.
- **Firmware update check:** the only internet requests are anonymous checks of public firmware release pages on `github.com` / `api.github.com`. They carry no identifiers, and the developer receives no data from them.
- **Apple Watch:** watch traffic goes only to the user's own iPhone, over WatchConnectivity.

**Privacy manifest:** Expo generates `PrivacyInfo.xcprivacy`, which declares the "required reason" APIs the libraries use, such as UserDefaults and file timestamps. Before the first upload, confirm App Store Connect reports no missing-reason warnings.

## 5. Privacy policy (text to publish)

```
compás Remote — Privacy Policy

compás Remote does not collect, store or share any personal data with the developer or with third parties.

• Your player's address and PIN are stored only on your device and are sent only to your own player on your local network.
• Your music library information and album covers are copied from your player and kept only on your device, so the app can show them quickly.
• Files you choose to transfer go directly between your device and your player over your local network.
• The app checks the public Compás release pages on GitHub to tell you about new firmware. These requests contain no personal information.
• The Apple Watch app communicates only with your iPhone.

There are no analytics, advertising or tracking in the app.

Questions: https://github.com/kambiz/compas-app/issues
```

## 6. Age rating questionnaire

Answer **None / No** to every item. That covers violence, sexual content, profanity, drugs, gambling, horror, medical, unrestricted web access, user-generated content and messaging. **Result: 4+.**

The app has no web browser, no chat and no in-app purchases.

## 7. App Review information

Reviewers won't have a HiBy R1, and Apple rejects apps it can't try (guideline 2.1). **Upload a demo video**, attached in Review Notes or linked from them.

### Demo video, about 2–3 minutes, recorded on a real iPhone

1. Open the app. Show the Local Network permission prompt and tap Allow.
2. Show the R1 found automatically under "On this network". Enter the PIN; show the player screen where the PIN appears.
3. On Now Playing: play/pause, skip, volume. Show the R1 responding on camera.
4. On the Library tab: open an album and play a song.
5. On the Transfer tab: upload a file to the SD card.
6. On Apple Watch: play/pause, skip, Crown volume.

### Review Notes (paste)

```
compás Remote is a remote control for the HiBy R1 digital audio player running the open-source Compás firmware (https://compasplayer.org). It requires that hardware on the same Wi-Fi network, so we have attached a demo video showing every feature with a real player.

Why the app uses the local network: it finds the player with Bonjour (_compas-remote._tcp) and controls it over HTTP on the local network. Nothing is sent to the internet except anonymous checks of public firmware release pages on GitHub.

Why plain HTTP: the player is a local device that serves an HTTP API on the LAN; App Transport Security is relaxed only for local networking (NSAllowsLocalNetworking), not for internet hosts.

PIN: the player shows a PIN in its own settings that must be entered in the app. It is a local pairing code, not an account; the app has no sign-in.

Apple Watch: the watch app sends commands to the iPhone app over WatchConnectivity; the iPhone forwards them to the player.

Bluetooth: not used on iOS.
```

**Sign-in required:** No.
**Contact:** your name, email and phone. These are only shown to Apple.

## 8. Export compliance

**Answer: No, the app does not use non-exempt encryption.** It uses only Apple's built-in HTTPS, for the GitHub release check; player traffic is plain HTTP on the local network.

This is preset with `ITSAppUsesNonExemptEncryption = NO` in the Info.plist (set by `plugins/withCompasIOS.js`), so App Store Connect won't ask on every build.

## 9. Screenshots

At least one screenshot set is required per device family the app supports. Take them in the Simulator with the app connected to a real R1. Pick an album with clean cover art and use the **Teal** or **Album art** accent.

| Device family | Simulator to use | Size (portrait) | Screens to capture |
|---|---|---|---|
| iPhone 6.9″ (required) | iPhone 18 Pro Max | 1320 × 2868 | Now Playing · Library grid · Album · Transfer · Connect a player · Dark mode Now Playing |
| iPad 13″ (required because iPad is supported) | iPad Pro 13-inch (M5) | 2064 × 2752 | Now Playing · Library · Transfer · Settings |
| Apple Watch | Apple Watch Series 12 (46mm) or Ultra | 416 × 496 (or the device's native size) | Now Playing |

Capture command for each simulator, run after arranging the screen:

```bash
xcrun simctl io <device-udid> screenshot ~/Desktop/appstore-<name>.png
```

Tips:
- Hide the development-only "Open debugger to view warnings" banner by using a **Release** build: `npx expo run:ios --configuration Release`.
- Use the status-bar override so the time reads 9:41 with full battery: `xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100`.

## 10. Submission checklist

- [ ] ⚠︎ author: name, use of "compás", bundle ID, and where to host the privacy policy
- [ ] Apple Developer Program membership ($99/year) active
- [ ] Final bundle ID set in `app.json` (`expo.ios.bundleIdentifier`). The watch ID follows it.
- [ ] Version `0.5.0` / build number set; bump the build number for every upload
- [ ] App ID and App Store Connect record created with that bundle ID
- [ ] Privacy policy page published (§5)
- [ ] Release build archived in Xcode (Product → Archive) and uploaded
- [ ] TestFlight: install on your own iPhone and Apple Watch; test the watch buttons and Crown volume, and relaying while the phone is locked
- [ ] Screenshots (§9), description, keywords, URLs entered
- [ ] App Privacy: Data Not Collected (§4)
- [ ] Age rating: 4+ (§6)
- [ ] Review Notes and demo video (§7)
- [ ] Submit for review
