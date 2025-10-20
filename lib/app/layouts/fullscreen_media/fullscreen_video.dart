import 'dart:async';

import 'package:bluebubbles/app/layouts/fullscreen_media/dialogs/metadata_dialog.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';

// (needed for custom back button)
//ignore: implementation_imports
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart' as media_kit_video_controls;
import 'package:universal_html/html.dart' as html;

class FullscreenVideo extends StatefulWidget {
  FullscreenVideo({
    super.key,
    required this.file,
    required this.attachment,
    required this.showInteractions,
    this.videoController,
    this.mute,
  });

  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;

  final VideoController? videoController;
  final RxBool? mute;

  @override
  OptimizedState createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends OptimizedState<FullscreenVideo> with AutomaticKeepAliveClientMixin {
  static bool get _isWindowsDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Timer? hideOverlayTimer;

  late VideoController videoController;

  bool hasListener = false;
  bool hasDisposed = false;
  final RxBool muted = ss.settings.startVideosMutedFullscreen.value.obs;
  final RxBool showPlayPauseOverlay = true.obs;
  final RxDouble aspectRatio = 1.0.obs;

  @override
  void initState() {
    super.initState();

    if (widget.mute != null) {
      muted.value = widget.mute!.value;
    }

    if (_isWindowsDesktop) {
      // Skip initializing media_kit on Windows to avoid libGL dependencies.
      return;
    }

    initControllers();
  }

  void initControllers() async {
    if (_isWindowsDesktop) {
      return;
    }

    if (widget.videoController != null) {
      videoController = widget.videoController!;
    } else {
      videoController = VideoController(Player());

      late final Media media;
      if (widget.file.path == null) {
        final blob = html.Blob([widget.file.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        media = Media(url);
      } else {
        media = Media(widget.file.path!);
      }
      
      await videoController.player.setPlaylistMode(PlaylistMode.none);
      await videoController.player.open(media, play: false);
      await videoController.player.setVolume(muted.value ? 0 : 100);
    }
    
    createListener(videoController);
    showPlayPauseOverlay.value = true;
    setState(() {});
  }

  void createListener(VideoController controller) {
    if (hasListener) return;

    controller.rect.addListener(() {
      aspectRatio.value = controller.aspectRatio;
    });

    controller.player.stream.completed.listen((completed) async {
      // If the status is ended, restart
      if (completed && !hasDisposed) {
        await controller.player.pause();
        await controller.player.seek(Duration.zero);
        await controller.player.pause();
        showPlayPauseOverlay.value = true;
        showPlayPauseOverlay.refresh();
      }
    });

    hasListener = true;
  }

  @override
  void dispose() {
    hasDisposed = true;
    hideOverlayTimer?.cancel();

    // Only dispose the player if one was not passed in (via a controller)
    if (widget.videoController == null && !_isWindowsDesktop) {
      videoController.player.dispose();
    }

    super.dispose();
  }

  void refreshAttachment() {
    if (_isWindowsDesktop) {
      return;
    }
    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    as.redownloadAttachment(widget.attachment, onComplete: (file) async {
      if (hasDisposed) return;
      hasListener = false;
      late final Media media;
      if (widget.file.path == null) {
        final blob = html.Blob([widget.file.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        media = Media(url);
      } else {
        media = Media(widget.file.path!);
      }
      await videoController.player.open(media, play: false);
      await videoController.player.setVolume(muted.value ? 0 : 100);
      createListener(videoController);
      showPlayPauseOverlay.value = !videoController.player.state.playing;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final RxBool _hover = false.obs;
    if (_isWindowsDesktop) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_disabled,
                  size: 72,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Video playback is not supported on Windows builds of BlueBubbles.',
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.titleMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Download the file to view it with an external application.',
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Obx(
      () => Scaffold(
        backgroundColor: Colors.black,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        bottomNavigationBar: !iOS || !widget.showInteractions
            ? null
            : Theme(
                data: context.theme.copyWith(
                  navigationBarTheme: context.theme.navigationBarTheme.copyWith(
                    indicatorColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: 0,
                  backgroundColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  elevation: 0,
                  height: 60,
                  destinations: [
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                          color: samsung ? Colors.white : context.theme.colorScheme.primary,
                        ),
                        label: 'Download'),
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.info : Icons.info,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Metadata'),
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.refresh : Icons.refresh,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Refresh'),
                    NavigationDestination(
                        icon: Icon(
                          muted.value
                              ? iOS
                                  ? CupertinoIcons.volume_mute
                                  : Icons.volume_mute
                              : iOS
                                  ? CupertinoIcons.volume_up
                                  : Icons.volume_up,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Mute'),
                  ],
                  onDestinationSelected: (value) async {
                    if (value == 0) {
                      await as.saveToDisk(widget.file);
                    } else if (value == 1) {
                      showMetadataDialog(widget.attachment, context);
                    } else if (value == 2) {
                      refreshAttachment();
                    } else if (value == 3) {
                      muted.toggle();
                      await videoController.player.setVolume(muted.value ? 0.0 : 100.0);
                      setState(() {});
                    }
                  },
                ),
              ),
        body: MouseRegion(
          onEnter: (event) => showPlayPauseOverlay.value = true,
          onExit: (event) => showPlayPauseOverlay.value = !videoController.player.state.playing,
          child: Obx(() {
            return SafeArea(
              child: Center(
                child: Theme(
                  data: context.theme.copyWith(
                      platform: iOS ? TargetPlatform.iOS : TargetPlatform.android,
                      dialogBackgroundColor: context.theme.colorScheme.properSurface,
                      iconTheme: context.theme.iconTheme.copyWith(color: context.theme.textTheme.bodyMedium?.color)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Video(controller: videoController, controls: (state) => Padding(
                        padding: EdgeInsets.all(!kIsWeb && !kIsDesktop ? 0 : 20).copyWith(bottom: !kIsWeb && !kIsDesktop ? 10 : 0),
                        child: media_kit_video_controls.AdaptiveVideoControls(state),
                      ), filterQuality: FilterQuality.medium),
                      if (kIsWeb || kIsDesktop)
                        Obx(() {
                        return MouseRegion(
                          onEnter: (event) => _hover.value = true,
                          onExit: (event) => _hover.value = false,
                          child: AbsorbPointer(
                            absorbing: !showPlayPauseOverlay.value && !_hover.value,
                            child: AnimatedOpacity(
                              opacity: _hover.value
                                  ? 1
                                  : showPlayPauseOverlay.value
                                      ? 0.5
                                      : 0,
                              duration: const Duration(milliseconds: 100),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(40),
                                  onTap: () async {
                                    if (videoController.player.state.playing) {
                                      await videoController.player.pause();
                                      showPlayPauseOverlay.value = true;
                                    } else {
                                      await videoController.player.play();
                                      showPlayPauseOverlay.value = false;
                                    }
                                  },
                                  child: Container(
                                    height: 75,
                                    width: 75,
                                    decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: ss.settings.skin.value == Skins.iOS && !videoController.player.state.playing ? 17 : 10,
                                        top: ss.settings.skin.value == Skins.iOS ? 13 : 10,
                                        right: 10,
                                        bottom: 10,
                                      ),
                                      child: Obx(
                                        () => videoController.player.state.playing
                                            ? Icon(
                                                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.pause : Icons.pause,
                                                color: context.iconColor,
                                                size: 45,
                                              )
                                            : Icon(
                                                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
                                                color: context.iconColor,
                                                size: 45,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (!iOS && (kIsWeb || kIsDesktop))
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Obx(() {
                            return MouseRegion(
                              onEnter: (event) => _hover.value = true,
                              onExit: (event) => _hover.value = false,
                              child: AbsorbPointer(
                                absorbing: !showPlayPauseOverlay.value && !_hover.value,
                                child: AnimatedOpacity(
                                  opacity: _hover.value
                                      ? 1
                                      : showPlayPauseOverlay.value
                                      ? 1
                                      : 0,
                                  duration: const Duration(milliseconds: 100),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(40),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.arrow_back,
                                          color: Colors.white,
                                          size: 25,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
