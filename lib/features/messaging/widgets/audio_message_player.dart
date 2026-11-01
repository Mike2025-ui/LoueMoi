import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Lecteur audio minimal pour les messages vocaux — lecture/pause + durée,
/// conforme au cahier des charges ("▶ lecture, ⏸ pause, voir la durée").
class AudioMessagePlayer extends StatefulWidget {
  const AudioMessagePlayer({
    super.key,
    required this.source,
    this.durationSeconds,
    this.isLocalFile = false,
    required this.iconColor,
    required this.textColor,
  });

  final String source;
  final int? durationSeconds;
  final bool isLocalFile;
  final Color iconColor;
  final Color textColor;

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final _player = AudioPlayer();
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AudioMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.isLocalFile != widget.isLocalFile) {
      _loadFailed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      if (widget.isLocalFile && !kIsWeb) {
        await _player.setFilePath(widget.source);
      } else {
        await _player.setUrl(widget.source);
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    final dur = (d != null && d.isNegative) ? Duration.zero : d;
    final totalSeconds = dur?.inSeconds ?? widget.durationSeconds ?? 0;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 20, color: widget.iconColor),
          const SizedBox(width: 8),
          Text('Vocal indisponible', style: TextStyle(color: widget.textColor, fontSize: 13)),
        ],
      );
    }

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  if (_player.processingState == ProcessingState.completed) {
                    await _player.seek(Duration.zero);
                  }
                  await _player.play();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 32,
                color: widget.iconColor,
              ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, positionSnapshot) {
                final remaining = (_player.duration ?? Duration(seconds: widget.durationSeconds ?? 0)) -
                    (positionSnapshot.data ?? Duration.zero);
                return Text(
                  _formatDuration(playing ? remaining : null),
                  style: TextStyle(color: widget.textColor, fontSize: 13),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
