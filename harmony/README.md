# HarmonyOS Next Client

This directory now contains a fully structured stage-based HarmonyOS Next 6.0 project that you can import directly into DevEco Studio. The ArkTS code reimplements the BlueBubbles UX with native ArkUI components while reusing the same REST endpoints as the Flutter client, so the macOS BlueBubbles server continues to work without changes.

## Project layout

```
harmony/
├── AppScope/app.json5          # Application level manifest
├── build-profile.json5         # Signing placeholders & SDK versions
├── hvigorconfig.json5          # Build tool configuration
├── hvigorfile.ts               # Top level hvigor entry point
├── oh-package.json5            # Project level dependencies
└── entry/
    ├── build-profile.json5     # Module build profile (stage mode)
    ├── hvigorfile.ts           # Module hvigor entry point
    ├── oh-package.json5        # Module dependencies
    └── src/
        └── main/
            ├── ets/            # ArkTS sources (abilities, pages, components, models)
            ├── module.json5    # Module manifest consumed by DevEco Studio
            └── resources/      # App strings, media, and theme colors
```

The `module.json5` file was relocated under `entry/src/main` to match the directory layout expected by DevEco Studio. The stage module declares `EntryAbility` as the main element and configures home screen skills so the simulator can launch it just like any native HarmonyOS app.

## Importing into DevEco Studio

1. Open DevEco Studio 4.0 or later and choose **File → Open**.
2. Select the `harmony` directory from this repository. DevEco Studio will read the `hvigorfile.ts`, `oh-package.json5`, and `build-profile.json5` metadata and register the `entry` module automatically.
3. When prompted for signing information, supply a debug certificate (or leave the placeholders until you configure one under **Project Structure → Signing Configs**).
4. Sync the project. Once the build scripts finish indexing, you can right-click the `entry` module and choose **Run 'entry'** to start the simulator or **Build HAP** to export an installable package.

## In-app setup flow

1. On first launch, the setup wizard prompts for the server URL, GUID auth key, and optional custom headers (e.g., Ngrok bypass headers).
2. The wizard performs a `/api/v1/ping` health check before persisting the configuration in HarmonyOS preferences.
3. After a successful connection the conversation list loads and mirrors the Flutter design—select a chat to open the detailed view, send messages, and return via the back control.

## Notes

- All HTTP calls continue to include the `guid` query parameter and reuse BlueBubbles REST payloads, ensuring feature parity with the Flutter client.
- Additional endpoints (attachments, reactions, scheduling, etc.) can be added following the patterns in `entry/src/main/ets/network/HttpService.ts`.
- Update `app_icon.svg`, signing materials, and other media resources in `entry/src/main/resources` prior to production release.
