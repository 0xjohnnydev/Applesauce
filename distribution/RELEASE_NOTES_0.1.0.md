# touchHLE iOS Port 0.1.0

This is the first public prerelease of an experimental, unofficial iOS port based on the touchHLE 0.2.3 development line at upstream commit `6bce4119`.

## Highlights

- Native SwiftUI game library designed for modern iOS.
- IPA importing with guest app names and icons.
- Persistent settings and per-game save folders.
- Portrait and landscape launch handling for older fixed-orientation games.
- In-game return-to-library control.
- StikDebug JIT shortcut using its bundled universal script.
- Optional FPS display under Developer Tools.
- iOS OpenGL ES presentation fixes for blank and stretched game output.

## Tested

The current build has been tested on an iPhone 16 Pro running iOS 27 beta 4 with:

- Touch & Go.
- Tony Hawk's Pro Skater 2.
- Wolfenstein RPG.

The deployment target is iOS 17.4, but other device and iOS combinations still need wider testing. The [touchHLE compatibility database](https://appdb.touchhle.org/) is the best starting point for choosing an exact app version; its star ratings are not a guarantee that every title has already been tested through this iOS port.

The Sims Medieval is a future compatibility target and is not currently claimed working.

## Requirements

- A modern iPhone running iOS 17.4 or newer.
- Installation through AltStore Classic, Xcode, or another compatible sideloading tool.
- JIT enabled for each new touchHLE process through StikDebug and LocalDevVPN, or AltJIT.
- A legally obtained, decrypted 32-bit IPA. Games are not included.

## Install With AltStore Classic

1. Install [AltStore Classic](https://altstore.io/) and complete its normal AltServer setup.
2. Download `touchHLE-iOS-unsigned.ipa` from the **Assets** section below.
3. In AltStore, open **My Apps**, tap **+**, and select the downloaded IPA.
4. Let AltStore sign and install it using your own Apple account.
5. Enable JIT before starting a game.

Free Apple accounts normally require the app to be refreshed every seven days. A paid Apple Developer account provides longer-lived development signing, but it does not remove the JIT requirement.

## Install With Xcode

You can instead build and install the port from source with a free Personal Team or paid Apple Developer account. Choose your own signing team and bundle identifier; never publish your signed app, provisioning profile, certificate, team ID, or `xcuserdata`.

Follow the [complete Xcode build and installation instructions](https://github.com/johnny901901901/touchHLE/blob/ios-host/platform/ios/README.md#option-b-build-and-install-with-xcode).

## Enable JIT

Installing the app is not enough by itself. The Dynarmic CPU backend requires JIT, which must be enabled again whenever touchHLE starts as a new app process.

- Use the in-app bolt shortcut with [StikDebug](https://github.com/StephenDev0/StikDebug), LocalDevVPN, and your private device pairing file; or
- Use [AltJIT](https://faq.altstore.io/altstore-classic/altjit) through AltStore Classic.

Never share your pairing file. See the [complete JIT setup and troubleshooting guide](https://github.com/johnny901901901/touchHLE/blob/ios-host/platform/ios/README.md#enable-jit).

## Import A Game

1. Open touchHLE and tap **Import Game**.
2. Select a legally obtained decrypted 32-bit `.ipa` from Files.
3. Check the [touchHLE compatibility database](https://appdb.touchhle.org/) for the exact app version.
4. Enable JIT, then tap the imported game card.

Games are not included. The [full iOS port guide](https://github.com/johnny901901901/touchHLE/blob/ios-host/platform/ios/README.md) also covers saves, logs, troubleshooting, and source builds.

## Download Safety

The release IPA is unsigned and credential-free. Each user signs it locally with their own Apple account.

- File: `touchHLE-iOS-unsigned.ipa`
- Size: `16065421` bytes
- SHA-256: `a00bba8d434ab52f6a393a03215a75862009ab83edb86887d1d05a90dea4bb1f`

Do not install a copy that has been reuploaded with a different hash unless you trust and can verify the person who rebuilt it.

## Important

This fork is not an official touchHLE release and is not endorsed by the upstream project. It does not include Apple software or games. Please credit the touchHLE contributors whose emulator core makes this port possible.

Thanks also to [u/WorriedEquipment2241](https://www.reddit.com/r/jailbreak/comments/1rzmp6m/i_ported_touchhle_to_ios_play_32bit_games_ios_11/) for the earlier public demonstration of a separate touchHLE experiment on jailbroken iOS, which helped inspire this work.
