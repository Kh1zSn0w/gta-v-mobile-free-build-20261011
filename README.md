# GTA V Mobile personal build source

Fork by Zenyical, based on [kevinerikjs/gta5-ios-port](https://github.com/kevinerikjs/gta5-ios-port).

This repository contains the native iOS wrapper, launcher artwork, and build scripts. It contains no game data, generated engine binary, or IPA releases. Native outputs are delivered to the owner's private repository. The build uses standard GitHub-hosted macOS runners, not paid larger runners.

Version 1.5 adds queued swipe camera input, Metal cache improvements, stereo buffering and interruption recovery, an app icon, and a Play mode picker without Cancel. Texture settings, the app identifier, and existing data paths remain unchanged.

The production launcher and touch overlay passed eight simulator UI tests at source commit `07cafec9b9906134c4df893fe8dd51959962471e` before this source-only build repo was created. Native runtime behavior must still be tested on the device.
