import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/providers.dart';

/// Opens (or creates) a 1:1 chat with [other] and navigates to the conversation.
Future<void> openChatWithUser({
  required BuildContext context,
  required WidgetRef ref,
  required UserModel other,
}) async {
  requireAuthVoid(
    context: context,
    ref: ref,
    action: () async {
      final me = ref.read(currentUserProfileProvider).valueOrNull;
      if (me == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in to chat')),
          );
        }
        return;
      }
      if (me.id == other.id) return;
      try {
        final chatId =
            await ref.read(chatRepositoryProvider).openOrCreateChat(
                  me: me,
                  other: other,
                );
        if (context.mounted) {
          context.push('/community/chats/$chatId');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    },
  );
}
