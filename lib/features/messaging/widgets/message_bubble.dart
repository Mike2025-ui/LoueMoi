import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/message.dart';
import 'audio_message_player.dart';
import 'video_message_player.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  /// URLs réseau (`http`/`https`, retournées par le backend) vs chemins de
  /// fichiers locaux (mode mock, ou aperçu avant envoi) — jamais déduit par
  /// analyse heuristique d'un chemin absolu (qui commence aussi par "/" sur
  /// Android), seulement par ce préfixe explicite.
  bool get _isNetworkAttachment =>
      message.attachmentUrl!.startsWith('http://') || message.attachmentUrl!.startsWith('https://');

  Widget _buildAttachment(BuildContext context, Color iconColor, Color textColor) {
    final url = message.attachmentUrl!;
    switch (message.attachmentType) {
      case MessageAttachmentType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: _isNetworkAttachment
              ? CachedNetworkImage(
                  imageUrl: url,
                  width: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => const SizedBox(
                    width: 200,
                    height: 150,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, _, _) => const SizedBox(
                    width: 200,
                    height: 100,
                    child: Icon(Icons.broken_image_outlined, color: AppColors.textHint),
                  ),
                )
              : (kIsWeb
                  ? Image.network(url, width: 200, fit: BoxFit.cover)
                  : Image.file(File(url), width: 200, fit: BoxFit.cover)),
        );
      case MessageAttachmentType.video:
        return VideoMessagePlayer(source: url, isLocalFile: !_isNetworkAttachment);
      case MessageAttachmentType.audio:
        return AudioMessagePlayer(
          source: url,
          isLocalFile: !_isNetworkAttachment,
          durationSeconds: message.duration,
          iconColor: iconColor,
          textColor: textColor,
        );
      case MessageAttachmentType.text:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = isMine ? AppColors.white : AppColors.primary;
    final textColor = isMine ? AppColors.white : AppColors.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMine ? AppRadius.md : 4),
            bottomRight: Radius.circular(isMine ? 4 : AppRadius.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.hasAttachment) ...[
              _buildAttachment(context, iconColor, textColor),
              if (message.content.isNotEmpty) const SizedBox(height: 6),
            ],
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
