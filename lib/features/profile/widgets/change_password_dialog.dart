import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';

Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) async {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  var isSubmitting = false;
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (statefulContext, setDialogState) {
        Future<void> submit() async {
          final current = currentPasswordController.text;
          final newPass = newPasswordController.text;
          final confirm = confirmPasswordController.text;

          if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
            setDialogState(() => errorText = 'Tous les champs sont requis.');
            return;
          }
          if (newPass.length < 6) {
            setDialogState(() => errorText = 'Le mot de passe doit contenir au moins 6 caractères.');
            return;
          }
          if (newPass != confirm) {
            setDialogState(() => errorText = 'Les nouveaux mots de passe ne correspondent pas.');
            return;
          }

          setDialogState(() {
            isSubmitting = true;
            errorText = null;
          });

          try {
            await ref.read(authControllerProvider.notifier).changePassword(
                  currentPassword: current,
                  newPassword: newPass,
                );
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mot de passe modifié avec succès !'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            setDialogState(() {
              isSubmitting = false;
              errorText = e.toString().contains('incorrect')
                  ? 'Mot de passe actuel incorrect.'
                  : 'Une erreur est survenue lors de la modification.';
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('Modifier mon mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => isSubmitting ? null : submit(),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isSubmitting ? null : submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
