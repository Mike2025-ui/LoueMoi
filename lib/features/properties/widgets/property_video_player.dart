import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Lecteur vidéo de la vidéo d'annonce (Property.video) — utilisé à la fois
/// pour l'aperçu lors de la publication (fichier local) et l'affichage sur
/// la fiche du bien (URL réseau). Fonctionnalité distincte de la vidéo de
/// messagerie (VideoMessagePlayer) : composant séparé, jamais partagé, pour
/// ne jamais mélanger les deux modèles/permissions/endpoints.
class PropertyVideoPlayer extends StatefulWidget {
  const PropertyVideoPlayer({
    super.key,
    required this.source,
    this.isLocalFile = false,
  });

  final String source;
  final bool isLocalFile;

  @override
  State<PropertyVideoPlayer> createState() => _PropertyVideoPlayerState();
}

class _PropertyVideoPlayerState extends State<PropertyVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant PropertyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.isLocalFile != widget.isLocalFile) {
      _controller?.dispose();
      _controller = null;
      _initializing = true;
      _failed = false;
      _init();
    }
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
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_failed || _controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(Icons.videocam_off_outlined, color: AppColors.textHint, size: 32),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              VideoPlayer(_controller!),
              if (!_controller!.value.isPlaying)
                const Icon(Icons.play_circle_fill, size: 56, color: AppColors.white),
            ],
          ),
        ),
      ),
    );
  }
}
