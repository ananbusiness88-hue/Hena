import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/fcm_service.dart';

/// Opens the existing account deletion request workflow.
///
/// The page only explains how to send the request, the account is never
/// deleted by opening it.
Future<void> openStoreOwnerAccountDeletionPage(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('طلب حذف الحساب'),
      content: const Text(
        'سيتم فتح صفحة طلب حذف الحساب. لن يحذف الحساب بمجرد فتح الصفحة يجب إرسال الطلب من خلالها.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('متابعة'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final uri = Uri.parse(
    'https://ananbusiness88-hue.github.io/Hena/delete-account.html',
  );

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح صفحة طلب حذف الحساب'),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر فتح صفحة الحذف: $error')),
    );
  }
}

/// Signs the account out and clears the device push token.
Future<void> signOutCurrentAccount() async {
  await FcmService.instance.unregisterCurrentToken();
  await Supabase.instance.client.auth.signOut();
}
