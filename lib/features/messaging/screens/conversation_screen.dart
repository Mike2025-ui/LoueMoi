import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/message.dart';
import '../providers/message_providers.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/message_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId, this.participantName});

  final String conversationId;
  final String? participantName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _voiceRecorder = VoiceRecorderService();

  XFile? _stagedImage;
  XFile? _stagedVideo;
  VoiceRecording? _stagedVoice;
  bool _isRecording = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  /// Non bloquant : la conversation reste consultable même si le marquage
  /// comme lu échoue (réseau instable...), voir _registerView côté
  /// PropertyDetailScreen pour le même principe.
  Future<void> _markRead() async {
    try {
      await markConversationRead(ref, widget.conversationId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  bool get _hasStagedAttachment =>
      _stagedImage != null || _stagedVideo != null || _stagedVoice != null;

  void _clearStagedAttachment() {
    setState(() {
      _stagedImage = null;
      _stagedVideo = null;
      _stagedVoice = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      setState(() {
        _stagedImage = file;
        _stagedVideo = null;
        _stagedVoice = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir la galerie.")));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (file == null) return;
      setState(() {
        _stagedVideo = file;
        _stagedImage = null;
        _stagedVoice = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Impossible de sélectionner la vidéo.")));
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recording = await _voiceRecorder.stop();
      setState(() {
        _isRecording = false;
        if (recording != null && recording.durationSeconds > 0) {
          _stagedVoice = recording;
          _stagedImage = null;
          _stagedVideo = null;
        }
      });
      return;
    }
    final started = await _voiceRecorder.start();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autorisez le microphone pour enregistrer un vocal.')),
        );
      }
      return;
    }
    setState(() => _isRecording = true);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && !_hasStagedAttachment) return;

    setState(() => _sending = true);
    try {
      String? attachmentPath;
      var attachmentType = MessageAttachmentType.text;
      int? duration;

      if (_stagedImage != null) {
        attachmentPath = _stagedImage!.path;
        attachmentType = MessageAttachmentType.image;
      } else if (_stagedVideo != null) {
        attachmentPath = _stagedVideo!.path;
        attachmentType = MessageAttachmentType.video;
      } else if (_stagedVoice != null) {
        attachmentPath = _stagedVoice!.path;
        attachmentType = MessageAttachmentType.audio;
        duration = _stagedVoice!.durationSeconds;
      }

      await sendMessage(
        ref,
        conversationId: widget.conversationId,
        content: text,
        attachmentPath: attachmentPath,
        attachmentType: attachmentType,
        duration: duration,
      );
      _controller.clear();
      _clearStagedAttachment();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.participantName ?? 'Agent')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              skipLoadingOnReload: true,
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Démarrez la conversation', style: AppTextStyles.caption),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isMine: message.senderId == currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text('Impossible de charger la conversation.',
                    style: AppTextStyles.caption),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasStagedAttachment) _StagedAttachmentPreview(
                    image: _stagedImage,
                    video: _stagedVideo,
                    voice: _stagedVoice,
                    onCancel: _clearStagedAttachment,
                  ),
                  if (_isRecording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 14, color: AppColors.danger),
                          SizedBox(width: 6),
                          Text('Enregistrement en cours…', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // Les 3 IconButton de médias réclamaient chacun leur
                      // cible tactile Material par défaut (48x48), soit
                      // 144px avant même d'atteindre le champ de texte — sur
                      // un écran étroit, cela ne laissait presque plus de
                      // place à la zone de saisie (le placeholder "Votre
                      // message..." s'affichait tronqué en "Votr...",
                      // donnant l'impression d'une seconde barre visuelle
                      // sur téléphone réel). Cible resserrée à 36x36, avec
                      // un padding réduit : les 3 boutons restent
                      // pleinement cliquables mais rendent la place au champ.
                      IconButton(
                        onPressed: _hasStagedAttachment || _isRecording ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: _hasStagedAttachment || _isRecording ? null : _pickVideo,
                        icon: const Icon(Icons.videocam_outlined, color: AppColors.textSecondary),
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: _hasStagedAttachment && !_isRecording ? null : _toggleRecording,
                        icon: Icon(
                          _isRecording ? Icons.stop_circle : Icons.mic_none,
                          color: _isRecording ? AppColors.danger : AppColors.textSecondary,
                        ),
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            enabled: !_isRecording,
                            decoration: const InputDecoration(
                              hintText: 'Message...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      InkWell(
                        onTap: _sending || _isRecording ? null : _send,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: _sending ? 0.5 : 1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: AppColors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StagedAttachmentPreview extends StatelessWidget {
  const _StagedAttachmentPreview({
    required this.image,
    required this.video,
    required this.voice,
    required this.onCancel,
  });

  final XFile? image;
  final XFile? video;
  final VoiceRecording? voice;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (image != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(File(image!.path), width: 64, height: 64, fit: BoxFit.cover),
      );
    } else if (video != null) {
      content = Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(Icons.videocam_outlined, color: AppColors.primary),
      );
    } else {
      content = AudioMessagePlayer(
        source: voice!.path,
        isLocalFile: true,
        durationSeconds: voice!.durationSeconds,
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          content,
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Prêt à envoyer', style: AppTextStyles.caption)),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
