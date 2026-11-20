import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_support_thread_models.dart';
import '../data/user_support_thread_repository.dart';

final userSupportThreadRepositoryProvider =
    Provider<UserSupportThreadRepository>(
  (ref) => UserSupportThreadRepository(),
);

final userSupportInboxProvider =
    StreamProvider<List<UserSupportThread>>((ref) {
  return ref.watch(userSupportThreadRepositoryProvider).watchInbox();
});

final userSupportMessagesProvider =
    StreamProvider.family<List<UserSupportMessage>, String>((ref, threadId) {
  if (threadId.isEmpty) return const Stream.empty();
  return ref.watch(userSupportThreadRepositoryProvider).watchMessages(threadId);
});
