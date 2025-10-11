
# HarmonyOS Next Client

This directory contains a stage-based HarmonyOS Next 6.0 client that reimplements the BlueBubbles UX with native ArkUI components. The ArkTS application speaks to the existing BlueBubbles macOS server using the same REST endpoints as the Flutter client, preserving conversation list, chat details, and message composer behavior.

## Feature highlights

- **Native ArkUI experience** – The conversation list, message view, and composer mirror the iOS-inspired layout of the Flutter app using HarmonyOS visual primitives.
- **Reusable network stack** – Requests are executed against `/api/v1` on the configured BlueBubbles server with the same query payloads (ping, chat query, message fetch, send text, etc.), so no backend changes are required.
- **Persistent settings** – Server URL, GUID auth key, and optional custom headers are stored with `@ohos.data.preferences`, allowing the HAP to reconnect automatically on relaunch.

## Prerequisites

1. Install DevEco Studio 4.0+ with the HarmonyOS Next (6.0) SDK and simulator images.
2. Ensure a BlueBubbles server is running on macOS with remote access enabled and note its HTTPS endpoint plus GUID auth key.
3. Update `app.json5` / `module.json5` metadata (bundle name, signing configuration, icons) for your distribution build if necessary.

## Building & running

1. Open DevEco Studio and select **File → Open**, pointing to the `harmony` directory.
2. After the Gradle sync, create or select a signing profile under **Project Structure → Signing Configs** (debug signing works for local simulator runs).
3. Right-click the `entry` module and choose **Run 'entry'** to launch in the DevEco Next simulator, or **Build HAP** to export a package located under `entry/build/default/outputs/default`.

## In-app setup flow

1. On first launch, the setup wizard prompts for the server URL, GUID auth key, and optional custom headers (e.g., Ngrok bypass headers).
2. The wizard performs a `/api/v1/ping` health check before persisting the configuration.
3. After a successful connection the conversation list loads and mirrors the Flutter design—select a chat to open the detailed view, send messages, and return via the back control.

## Notes

- All HTTP calls continue to include the `guid` query parameter and reuse BlueBubbles REST payloads, ensuring feature parity with the Flutter client.
- Additional endpoints (attachments, reactions, scheduling, etc.) can be added following the patterns in `entry/src/main/ets/network/HttpService.ts`.
- Update `app_icon.png` and other media resources in `entry/src/main/resources` prior to production release.
