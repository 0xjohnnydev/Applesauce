# touchHLE iOS Port (Unofficial)

This is an experimental iOS port based on the touchHLE 0.2.3 development line at upstream commit `6bce4119`. It runs supported 32-bit guest apps on modern iPhones through touchHLE's existing high-level emulation and Dynarmic CPU backend.

This fork is not an official touchHLE release, is not endorsed by the upstream project, and does not include games or Apple software.

## At A Glance

| Item | Current status |
| --- | --- |
| Port version | 0.1.0 |
| touchHLE base | 0.2.3 development line (`6bce4119`) |
| Minimum target | iOS 17.4 |
| Tested environment | iPhone 16 Pro running iOS 27 beta 4 |
| CPU backend | Dynarmic |
| JIT | Required whenever the port starts as a new process |
| Games | Not included; decrypted 32-bit IPAs are required |

The native port currently provides:

- An Apple-style SwiftUI game library.
- IPA importing with the guest app's title and icon.
- Persistent settings and per-game save folders.
- Guest-aware portrait and landscape launch handling.
- A red in-game exit control that returns to the library.
- A StikDebug JIT shortcut.
- An optional FPS counter under **Settings → Advanced → Developer Tools**.

## Screenshots

<table>
  <tr>
    <td><img src="Screenshots/library-games.png" alt="touchHLE library with imported game cards" width="260"></td>
    <td><img src="Screenshots/library-empty.png" alt="Empty touchHLE game library" width="260"></td>
  </tr>
  <tr>
    <td><img src="Screenshots/settings.png" alt="Native touchHLE settings screen" width="260"></td>
    <td><img src="Screenshots/about.png" alt="touchHLE about screen" width="260"></td>
  </tr>
</table>

Imported titles shown in screenshots are not all compatibility claims.

## Device And Game Testing

The port has been personally tested on an **iPhone 16 Pro running iOS 27 beta 4**. Its deployment target is iOS 17.4, and it is intended to work on other modern iPhones and supported iOS versions, but those combinations have not all been verified yet.

Confirmed on that device:

- Touch & Go.
- Tony Hawk's Pro Skater 2 (THPS2).
- Wolfenstein RPG.

The [touchHLE compatibility database](https://appdb.touchhle.org/) uses a star-rating system for specific app versions. Higher-rated entries are the best place to begin, but a high rating is not a guarantee that the same version has already been tested through this iOS port.

The Sims Medieval is a planned compatibility target, not a currently working title. This project began after the port developer gave his sister a new iPhone 17 Pro Max and discovered that the copy of The Sims Medieval she had legitimately purchased years ago could no longer be installed. Future compatibility work will focus on identifying and fixing the first missing touchHLE subsystem rather than changing the native library UI.

## Current Limitations

- JIT is required. This fork does not yet contain a no-JIT ARM interpreter.
- The touchHLE compatibility database describes touchHLE generally, not guaranteed iOS-host behavior.
- Device and iOS-version coverage is still limited.
- Some games need touchHLE compatibility work even when the port itself is functioning.
- This is an early test build, not an App Store release.

## Acknowledgements

This port exists because of the work of the [touchHLE contributors](https://github.com/touchHLE/touchHLE/graphs/contributors). The core emulator is their project; this fork adds an experimental native iOS port and iOS-specific integration fixes.

Thanks also to Reddit user [u/WorriedEquipment2241](https://www.reddit.com/user/WorriedEquipment2241/) for publicly demonstrating a separate touchHLE iOS experiment on a jailbroken device. That demonstration helped show that the idea was viable and highlighted an important reality: compatibility still differs game by game. This release is based on upstream touchHLE 0.2.3 and does not claim to contain that unreleased port's source code.

## Install The Unsigned IPA

The public IPA must remain unsigned. It contains no Apple ID, certificate, provisioning profile, development team, device identifier, games, or saves. Your chosen install method signs it locally with your own Apple account.

### Option A: AltStore Classic

This is the simplest public installation route.

1. Install [AltStore Classic](https://altstore.io/) and complete its normal AltServer setup.
2. Download `touchHLE-iOS-unsigned.ipa` from this fork's GitHub Releases.
3. In AltStore, open **My Apps**, tap **+**, and select the IPA from Files.
4. Let AltStore sign and install it with your Apple account.
5. Complete the [JIT setup](#enable-jit) before starting a game.

With a free Apple account, Apple limits Personal Team profiles to seven days and three installed apps per device. AltStore can refresh apps before they expire while it can reach AltServer. See [Apple's Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account) and [AltStore's refresh explanation](https://faq.altstore.io/altstore-classic/your-altstore).

A paid Apple Developer Program account provides longer-lived development signing and avoids the free Personal Team's weekly reprovisioning limit. It does **not** remove the JIT requirement.

### Option B: Build And Install With Xcode

This works with either a free Personal Team or a paid developer account.

1. Complete the [source prerequisites](#build-from-source).
2. Build the Debug Rust library:

   ```sh
   sh platform/ios/scripts/build-rust.sh aarch64-apple-ios Debug
   ```

3. Open `platform/ios/TouchHLEHost.xcodeproj`.
4. Select the **TouchHLEHost** target.
5. Under **Signing & Capabilities**, choose your own team.
6. Change the bundle identifier if Xcode says `org.touchhle.ios.unofficial` is unavailable.
7. Select your iPhone and press **Run**.
8. Follow any Developer Mode or trust prompts shown by Xcode and the iPhone.
9. Complete the [JIT setup](#enable-jit) before starting a game.

Never commit or upload Xcode's signed app, provisioning profile, certificate, team ID, or `xcuserdata`.

## Enable JIT

Dynarmic requires executable memory, so installing the app is not enough by itself. JIT must be enabled again whenever touchHLE starts as a new process. JIT normally remains available until the app is force-quit or removed from memory.

### StikDebug And LocalDevVPN

The in-app bolt button uses StikDebug's URL scheme and its bundled `universal.js` script.

1. Install the current [StikDebug release](https://github.com/StephenDev0/StikDebug).
2. Create a pairing file by following the [AltStore JIT pairing guide](https://faq.altstore.io/altstore-classic/enabling-jit).
3. Import that pairing file into StikDebug.
4. Install and connect [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044), or another loopback VPN supported by your StikDebug version.
5. Keep the iPhone awake, unlocked, connected to Wi-Fi, and connected to the loopback VPN.
6. Open touchHLE to the library and tap the **bolt** button.
7. Allow StikDebug to enable JIT for touchHLE, then return to the port and start the game.

The initial pairing setup needs a Mac or PC. After that, StikDebug is designed to enable JIT on-device. StikDebug currently supports iOS 17.4 and newer, with additional caveats for newer beta versions; check its own compatibility notes before troubleshooting this port.

Treat the pairing file as private device material. Never upload or attach it to an issue.

### AltJIT

AltStore users can instead follow the official [AltJIT instructions](https://faq.altstore.io/altstore-classic/altjit). In AltStore, long-press touchHLE under **My Apps** and choose **Enable JIT**. Current iOS versions may require extra Mac-side setup, and the device may need to remain connected until JIT has been enabled.

Installing through AltStore, SideStore, Sideloadly, or Xcode does not automatically provide JIT.

## Import Games

1. Open touchHLE and tap **Import Game**.
2. Select a decrypted 32-bit `.ipa` from Files.
3. The port imports the IPA, reads its app name and icon, and adds it to the library.
4. Check the [touchHLE compatibility database](https://appdb.touchhle.org/) for the exact app version before testing.
5. Enable JIT, then tap the game card.

Only use software you obtained legally. This project does not provide game downloads, decrypted executables, encryption keys, or instructions for bypassing copy protection.

Removing a title from the library removes the imported IPA but deliberately keeps its save folder.

## Saves And Backups

Guest files are stored inside the port's app container:

```text
Documents/touchHLE_sandbox/<guest-bundle-id>
```

Progress therefore survives returning to the library and normal app restarts. Deleting touchHLE from the device can delete the entire app container, including saves.

To back up saves:

1. Open the iOS Files app.
2. Browse to **On My iPhone → touchHLE**.
3. Copy the `touchHLE_sandbox` folder somewhere safe.

Do not publish saves with a release or attach them to bug reports without checking their contents.

## Troubleshooting

### The game stays on “Starting game…” or crashes immediately

- Re-enable JIT after every fresh touchHLE process.
- Confirm LocalDevVPN is connected and StikDebug has the correct pairing file.
- Confirm the imported IPA is decrypted, 32-bit, and the exact version listed in the compatibility database.
- Retry with touchHLE's default settings.

### StikDebug reports a tunnel or connection error

- Wake and unlock the iPhone.
- Confirm Wi-Fi and LocalDevVPN are connected.
- Reconnect LocalDevVPN, then retry.
- Replace the pairing file if the device was restored, updated, or re-paired.
- Check the current [StikDebug troubleshooting notes](https://github.com/StephenDev0/StikDebug).

### There is audio and touch input but the picture is blank or stretched

- Confirm you are using host 0.1.0 or newer; this release contains the iOS OpenGL ES presentation and landscape texture-coordinate fixes.
- Return to the library and start the game in its declared orientation.
- Record the exact game version, device, iOS version, and whether portrait titles render correctly.

### Touch stops responding after rotation

The port locks each game to its launch orientation because older games often assume a fixed screen layout. Return to the library, hold the phone in the desired supported orientation, and launch again.

### The app no longer opens

If it was signed with a free Apple account, refresh or reinstall it before the seven-day profile expires. Reinstalling the app can risk the app container, so back up saves first.

## Logs

Runtime output is written to:

```text
Documents/touchhle-host.log
```

The log is visible under **On My iPhone → touchHLE** because file sharing is enabled. Before sharing it, check it for game names, local paths, or other personal data.

A useful issue report includes:

- iPhone model and iOS version.
- Port version and install method.
- Whether JIT was confirmed enabled.
- Exact guest app title and version, but not the IPA itself.
- Reproduction steps.
- The relevant log excerpt.

Never attach games, saves, pairing files, certificates, provisioning profiles, signed IPAs, or device backups.

## Build From Source

### Prerequisites

- macOS with Xcode 26 or newer and its command-line tools.
- Stable Rust installed through [rustup](https://rustup.rs/).
- CMake and Ninja.
- Boost headers.

Homebrew can install the non-Xcode dependencies:

```sh
brew install cmake ninja boost
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
```

The scripts look for Boost under `vendor/boost` by default. To use Homebrew's headers:

```sh
export TOUCHHLE_BOOST_ROOT="$(brew --prefix boost)/include"
```

If Xcode is installed somewhere other than `/Applications/Xcode.app`:

```sh
export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
```

### Unsigned Release Build

```sh
sh platform/ios/scripts/build-host.sh iphoneos Release
sh platform/ios/scripts/package-ipa.sh
```

The outputs are:

```text
build/host-iphoneos/Build/Products/Release-iphoneos/touchHLE.app
dist/touchHLE-iOS-unsigned.ipa
dist/touchHLE-iOS-unsigned.ipa.sha256
```

The packaging script refuses to package a signed app.

### Simulator Build

```sh
sh platform/ios/scripts/build-host.sh iphonesimulator Debug
```

Dynarmic and JIT behavior differs between a simulator and a physical iPhone, so final gameplay testing must happen on a device.

## Upstream Relationship

This work is published as an unofficial GitHub fork so the original history, contributors, and licenses remain visible. It is not an official touchHLE iOS release.

## License And Credits

touchHLE source is licensed under MPL-2.0, while binary distribution is covered by GPL-3.0-or-later due to dependency licensing. Preserve the repository's existing license files and attribution.

Credit the touchHLE contributors, Dynarmic, SDL, StikDebug, LocalDevVPN, and the other dependencies listed by touchHLE. This fork is not affiliated with Apple.
