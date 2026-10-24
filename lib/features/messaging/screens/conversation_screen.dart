import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
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
  final _scrollController = ScrollController();
  final _voiceRecorder = VoiceRecorderService();
  Timer? _pollTimer;

  XFile? _stagedImage;
  XFile? _stagedVideo;
  VoiceRecording? _stagedVoice;
  bool _isRecording = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _markRead();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.invalidate(messagesProvider(widget.conversationId));
        ref.invalidate(conversationsProvider);
        _markRead();
      }
    });
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
    _pollTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
      _scrollToBottom();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.image_outlined,
                  color: AppColors.primary,
                  label: 'Photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.videocam_outlined,
                  color: AppColors.accent,
                  label: 'Vidéo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      _scrollToBottom();
    });

    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final conversationsAsync = ref.watch(conversationsProvider);
    final conv = conversationsAsync.valueOrNull?.where((c) => c.id == widget.conversationId).firstOrNull;
    final isOnline = conv?.participantIsOnline ?? false;
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final hasText = _controller.text.trim().isNotEmpty;
    final canSend = hasText || _hasStagedAttachment;

    final displayName = widget.participantName ?? conv?.participantName ?? 'Contact';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: conv?.participantPhoto != null
                      ? NetworkImage(buildMediaUrl(conv!.participantPhoto!))
                      : null,
                  child: conv?.participantPhoto == null
                      ? const Icon(Icons.person, size: 22, color: AppColors.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF25D366) : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF25D366) : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? const Color(0xFF25D366) : AppColors.textSecondary,
                          fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  controller: _scrollController,
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
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasStagedAttachment)
                    _StagedAttachmentPreview(
                      image: _stagedImage,
                      video: _stagedVideo,
                      voice: _stagedVoice,
                      onCancel: _clearStagedAttachment,
                    ),
                  if (_isRecording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 14, color: AppColors.danger),
                          SizedBox(width: 6),
                          Text('Enregistrement en cours…', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _hasStagedAttachment || _isRecording ? null : _showAttachmentMenu,
                        icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                        iconSize: 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 42),
                        tooltip: 'Joindre un fichier',
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            enabled: !_isRecording,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Message...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textHint,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_isRecording)
                        InkWell(
                          onTap: _toggleRecording,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            width: 42,
                            height: 42,
                            margin: const EdgeInsets.only(bottom: 1),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.stop, color: AppColors.white, size: 22),
                          ),
                        )
                      else if (canSend)
                        InkWell(
                          onTap: _sending ? null : _send,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            width: 42,
                            height: 42,
                            margin: const EdgeInsets.only(bottom: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: _sending ? 0.5 : 1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send, color: AppColors.white, size: 20),
                          ),
                        )
                      else
                        InkWell(
                          onTap: _toggleRecording,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            width: 42,
                            height: 42,
                            margin: const EdgeInsets.only(bottom: 1),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic_none, color: AppColors.white, size: 22),
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
        child: kIsWeb
            ? Image.network(image!.path, width: 64, height: 64, fit: BoxFit.cover)
            : Image.file(File(image!.path), width: 64, height: 64, fit: BoxFit.cover),
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

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
