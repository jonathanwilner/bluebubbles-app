import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:universal_html/html.dart' as html;

class VideoPlayer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;
  final bool isFromMe;

  VideoPlayer(
      {super.key, required this.file, required this.attachment, required this.controller, required this.isFromMe});

  final ConversationViewController? controller;

  @override
  OptimizedState createState() => _VideoPlayerState();
}

class PlayPauseButton extends StatelessWidget {
  PlayPauseButton({
    super.key,
    required this.showPlayPauseOverlay,
    required this.controller,
    this.customOnTap,
    this.hover,
  });

  final RxBool showPlayPauseOverlay;
  final VideoController? controller;
  final Function? customOnTap;
  final RxBool? hover;
  late final RxBool _hover = hover ?? false.obs;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => MouseRegion(
        onEnter: (event) => _hover.value = true,
        onExit: (event) => _hover.value = false,
        child: AbsorbPointer(
          absorbing: !showPlayPauseOverlay.value && !_hover.value,
          child: AnimatedOpacity(
            opacity: _hover.value
                ? 1
                : showPlayPauseOverlay.value && ReplyScope.maybeOf(context) == null
                    ? 0.5
                    : 0,
            duration: const Duration(milliseconds: 100),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () async {
                  if (controller?.player.state.playing ?? false) {
                    await controller!.player.pause();

                    Future.delayed(const Duration(milliseconds: 500), () {
                      showPlayPauseOverlay.value = true;
                    });
                  } else {
                    if (customOnTap != null) {
                      customOnTap?.call();
                    } else {
                      await controller?.player.play();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        showPlayPauseOverlay.value = false;
                      });
                    }
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
                      left:
                          ss.settings.skin.value == Skins.iOS && !(controller?.player.state.playing ?? false) ? 17 : 10,
                      top: ss.settings.skin.value == Skins.iOS ? 13 : 10,
                      right: 10,
                      bottom: 10,
                    ),
                    child: Obx(
                      () => controller?.player.state.playing ?? false
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
      ),
    );
  }
}

class MuteButton extends StatelessWidget {
  const MuteButton(
      {super.key,
      required this.showPlayPauseOverlay,
      required this.muted,
      required this.controller,
      required this.isFromMe});

  final RxBool showPlayPauseOverlay;
  final RxBool muted;
  final VideoController? controller;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        bottom: 8,
        right: (isFromMe) ? 15 : 8,
        child: Obx(() {
          return AnimatedOpacity(
              opacity: showPlayPauseOverlay.value && ReplyScope.maybeOf(context) == null ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: AbsorbPointer(
                absorbing: !showPlayPauseOverlay.value,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () async {
                      muted.value = !muted.value;
                      await controller?.player.setVolume(muted.value ? 0.0 : 100.0);
                    },
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        muted.value
                            ? ss.settings.skin.value == Skins.iOS
                                ? CupertinoIcons.volume_mute
                                : Icons.volume_mute
                            : ss.settings.skin.value == Skins.iOS
                                ? CupertinoIcons.volume_up
                                : Icons.volume_up,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ));
        }));
  }
}

class _VideoPlayerState extends OptimizedState<VideoPlayer> with AutomaticKeepAliveClientMixin {
  static bool get _isWindowsDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Attachment get attachment => widget.attachment;

  PlatformFile get file => widget.file;

  bool get isFromMe => widget.isFromMe;

  ConversationViewController? get cvController => widget.controller;

  bool hasListener = false;
  VideoController? videoController;

  final RxBool showPlayPauseOverlay = true.obs;
  final RxBool muted = ss.settings.startVideosMuted.value.obs;
  final RxDouble aspectRatio = 1.0.obs;
  Uint8List? thumbnail;

  @override
  void initState() {
    super.initState();

    VideoController? cachedController = cvController?.videoPlayers[attachment.guid];
    thumbnail = cvController?.imageData[attachment.guid];

    if (cachedController != null && !_isWindowsDesktop) {
      videoController = cachedController;
      aspectRatio.value = videoController!.aspectRatio;

      updateObx(() {
        createListener(videoController!);
      });
    }

    if (thumbnail == null && !kIsDesktop && !kIsWeb) {
      updateObx(() {
        getThumbnail();
      });
    }

    if (_isWindowsDesktop) {
      // Avoid initializing video playback on Windows builds where libGL is unavailable.
      return;
    }

    initializeController();
  }

  Future<void> initializeController() async {
    if (_isWindowsDesktop) {
      return;
    }

    late final Media media;
    if (widget.file.path == null) {
      final blob = html.Blob([widget.file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      media = Media(url);
    } else {
      media = Media(widget.file.path!);
    }

    videoController ??= VideoController(Player());
    await videoController!.player.setPlaylistMode(PlaylistMode.none);
    await videoController!.player.open(media, play: false);
    await videoController!.player.setVolume(muted.value ? 0 : 100);
    createListener(videoController!);
    cvController?.videoPlayers[attachment.guid!] = videoController!;
    setState(() {});
  }

  void createListener(VideoController controller) {
    if (hasListener) return;

    controller.rect.addListener(() {
      aspectRatio.value = controller.aspectRatio;
    });

    controller.player.stream.completed.listen((completed) async {
      // If the status is ended, restart
      if (completed) {
        await controller.player.pause();
        await controller.player.seek(Duration.zero);
        await controller.player.pause();
        showPlayPauseOverlay.value = true;
        showPlayPauseOverlay.refresh();
      }
    });
    hasListener = true;
  }

  void getThumbnail() async {
    if (!kIsWeb && !kIsDesktop) {
      try {
        // If we already errored, throw an error to load the error logo
        if (attachment.metadata?['thumbnail_status'] == 'error') {
          throw Exception('No video preview');
        }
        // If we haven't errored at all, fetch the thumbnail
        thumbnail = await as.getVideoThumbnail(file.path!);
      } catch (ex) {
        // If an error occurs, set the thumnail to the cached no preview image.
        // Only save to DB if the status wasn't already `error` somehow
        thumbnail = fs.noVideoPreviewIcon;
        if (attachment.metadata?['thumbnail_status'] != 'error') {
          attachment.metadata ??= {};
          attachment.metadata!['thumbnail_status'] = 'error';
          if (attachment.id != null) {
            attachment.save(null);
          }
        }
      }

      if (thumbnail == null) return;
      cvController?.imageData[attachment.guid!] = thumbnail!;
      await precacheImage(MemoryImage(thumbnail!), context);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isWindowsDesktop) {
      return _buildWindowsPlaceholder(context);
    }
    if (videoController != null) {
      return MouseRegion(
        onEnter: (event) => showPlayPauseOverlay.value = true,
        onExit: (event) => showPlayPauseOverlay.value = !videoController!.player.state.playing,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: !kIsDesktop && !kIsWeb
              ? () async {
                  if (attachment.id == null) return;
                  if (videoController!.player.state.playing) {
                    await videoController!.player.pause();
                    showPlayPauseOverlay.value = true;
                  } else {
                    if (attachment.id == null) return;
                    await Navigator.of(Get.context!).push(
                      ThemeSwitcher.buildPageRoute(
                        builder: (context) => FullscreenMediaHolder(
                          currentChat: cm.activeChat,
                          attachment: attachment,
                          showInteractions: true,
                          videoController: videoController,
                          mute: muted,
                        ),
                      ),
                    );
                  }
                }
              : () async {
                  if (attachment.id == null) return;
                  await videoController!.player.pause();
                  await Navigator.of(Get.context!).push(
                    ThemeSwitcher.buildPageRoute(
                      builder: (context) => FullscreenMediaHolder(
                        currentChat: cm.activeChat,
                        attachment: attachment,
                        showInteractions: true,
                        mute: muted,
                        videoController: videoController,
                      ),
                    ),
                  );
                },
          onDoubleTap: () {
            // Stub to prevent doubleTap events on parent from happening
          },
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Obx(() => AspectRatio(
                    aspectRatio: aspectRatio.value,
                    child: Video(
                      controller: videoController!,
                      controls: null,
                    ),
                  )),
              PlayPauseButton(showPlayPauseOverlay: showPlayPauseOverlay, controller: videoController),
              MuteButton(
                  showPlayPauseOverlay: showPlayPauseOverlay,
                  muted: muted,
                  controller: videoController,
                  isFromMe: widget.isFromMe),
              if (kIsDesktop)
                FullscreenButton(
                  attachment: attachment,
                  isFromMe: widget.isFromMe,
                  muted: muted
                ),
            ],
          ),
        ),
      );
    }
    final RxBool hover = false.obs;
    return Obx(
      () => InkWell(
          hoverColor: hover.value ? Colors.transparent : null,
          focusColor: hover.value ? Colors.transparent : null,
          onTap: () async {
            if (attachment.id == null || (!kIsDesktop && !kIsWeb)) return;
            await Navigator.of(Get.context!).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => FullscreenMediaHolder(
                  currentChat: cm.activeChat,
                  attachment: attachment,
                  showInteractions: true,
                  mute: muted,
                  videoController: videoController,
                ),
              ),
            );
          },
          child: thumbnail == null
              ? Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PlayPauseButton(
                        showPlayPauseOverlay: showPlayPauseOverlay,
                        controller: videoController,
                        hover: hover,
                        customOnTap: () async {
                          await initializeController();
                          await videoController?.player.setVolume(muted.value ? 0.0 : 100.0);
                          await videoController?.player.play();
                          showPlayPauseOverlay.value = false;
                        },
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                            ),
                            const SizedBox(height: 2.5),
                            Text(
                              "${(mime(file.name)?.split("/").lastOrNull ?? mime(file.name) ?? "file").toUpperCase()} • ${file.size.toDouble().getFriendlySize()}",
                              style: context.theme.textTheme.labelMedium!
                                  .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  thumbnail!,
                  // prevents the image widget from "refreshing" when the provider changes
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.none,
                  cacheWidth: (min((attachment.width ?? 0), ns.width(context) * 0.5) * Get.pixelRatio / 2)
                      .round()
                      .abs()
                      .nonZero,
                  cacheHeight: (min((attachment.height ?? 0), ns.width(context) * 0.5 / attachment.aspectRatio) *
                          Get.pixelRatio /
                          2)
                      .round()
                      .abs()
                      .nonZero,
                  fit: BoxFit.cover,
                  frameBuilder: (context, widget, frame, wasSyncLoaded) {
                    return AnimatedCrossFade(
                        crossFadeState: frame == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        alignment: Alignment.center,
                        duration: const Duration(milliseconds: 150),
                        secondChild: Stack(
                          alignment: Alignment.center,
                          children: [
                            widget,
                            PlayPauseButton(
                              showPlayPauseOverlay: showPlayPauseOverlay,
                              controller: videoController,
                              customOnTap: () async {
                                await initializeController();
                                await videoController?.player.setVolume(muted.value ? 0.0 : 100.0);
                                await videoController?.player.play();
                                showPlayPauseOverlay.value = false;
                              },
                            ),
                            MuteButton(
                                showPlayPauseOverlay: showPlayPauseOverlay,
                                muted: muted,
                                controller: videoController,
                                isFromMe: isFromMe),
                          ],
                        ),
                        firstChild: SizedBox(
                          width:
                              min((attachment.width?.toDouble() ?? ns.width(context) * 0.5), ns.width(context) * 0.5),
                          height: min(
                              (attachment.height?.toDouble() ?? ns.width(context) * 0.5 / attachment.aspectRatio),
                              ns.width(context) * 0.5 / attachment.aspectRatio),
                        ));
                  },
                )),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildWindowsPlaceholder(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.play_disabled,
            size: 48,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Video playback is not available on Windows builds.',
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download the attachment to view it externally.',
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class FullscreenButton extends StatelessWidget {
  const FullscreenButton({super.key, required this.attachment, required this.isFromMe, this.videoController, this.muted});

  final Attachment attachment;
  final bool isFromMe;
  final VideoController? videoController;
  final RxBool? muted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: (!isFromMe) ? 15 : 8,
      child: Obx(
        () => Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () async {
              if (attachment.id == null) return;
              await Navigator.of(Get.context!).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (context) => FullscreenMediaHolder(
                    currentChat: cm.activeChat,
                    attachment: attachment,
                    showInteractions: true,
                    videoController: videoController,
                    mute: muted
                  ),
                ),
              );
            },
            child: Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.all(5),
              child: Icon(
                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.fullscreen : Icons.fullscreen,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
