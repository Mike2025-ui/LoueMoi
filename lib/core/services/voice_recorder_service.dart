import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Fichier + durée d'un enregistrement vocal terminé.
class VoiceRecording {
  const VoiceRecording({required this.path, required this.durationSeconds});
  final String path;
  final int durationSeconds;
}

/// Enveloppe le package `record` (voir cahier des charges : appui micro →
/// enregistrement → arrêt → aperçu → envoi). Ne fait jamais planter l'app :
/// [start] retourne simplement `false` si la permission est refusée ou indisponible.
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;

  Future<bool> start() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      String path;
      if (kIsWeb) {
        path = '';
      } else {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(const RecordConfig(), path: path);
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retourne l'enregistrement terminé, ou `null` s'il n'y avait rien en
  /// cours (jamais démarré, ou déjà arrêté).
  Future<VoiceRecording?> stop() async {
    try {
      final path = await _recorder.stop();
      final startedAt = _startedAt;
      _startedAt = null;
      if (path == null || startedAt == null) return null;
      final durationSeconds = DateTime.now().difference(startedAt).inSeconds;
      return VoiceRecording(path: path, durationSeconds: durationSeconds);
    } catch (_) {
      _startedAt = null;
      return null;
    }
  }

  Future<void> cancel() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    _startedAt = null;
  }

  Future<void> dispose() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    await _recorder.dispose();
  }
}
