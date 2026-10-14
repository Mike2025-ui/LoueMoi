import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Aperçu/lecture vidéo minimal pour la messagerie — thumbnail avec overlay
/// play, lecture inline au tap.
class VideoMessagePlayer extends StatefulWidget {
  const VideoMessagePlayer({
    super.key,
    required this.source,
    this.isLocalFile = false,
  });

  final String source;
  final bool isLocalFile;

  @override
  State<VideoMessagePlayer> createState() => _VideoMessagePlayerState();
}

class _VideoMessagePlayerState extends State<VideoMessagePlayer> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = widget.isLocalFile
          ? VideoPlayerController.file(File(widget.source))
          : VideoPlayerController.networkUrl(Uri.parse(widget.source));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const SizedBox(
        width: 180,
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_failed || _controller == null) {
      return Container(
        width: 180,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.videocam_off_outlined, color: AppColors.textHint),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                if (!_controller!.value.isPlaying)
                  const Icon(Icons.play_circle_fill, size: 48, color: AppColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
