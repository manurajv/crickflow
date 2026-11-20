import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/help/data/support_thread_models.dart';
import '../../features/help/data/support_thread_repository.dart';
import 'providers.dart';

final supportThreadRepositoryProvider =
    Provider<SupportThreadRepository>((ref) => SupportThreadRepository());

final mySupportThreadProvider = StreamProvider<SupportThread?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(supportThreadRepositoryProvider).watchThread(uid);
});

final mySupportMessagesProvider = StreamProvider<List<SupportMessage>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(supportThreadRepositoryProvider).watchMessages(uid);
});

final staffSupportInboxProvider = StreamProvider<List<SupportThread>>((ref) {
  return ref.watch(supportThreadRepositoryProvider).watchStaffInbox();
});

final staffSupportUnreadTotalProvider = StreamProvider<int>((ref) {
  return ref.watch(supportThreadRepositoryProvider).watchStaffUnreadTotal();
});

final staffSupportMessagesProvider =
    StreamProvider.family<List<SupportMessage>, String>((ref, threadId) {
  if (threadId.isEmpty) return const Stream.empty();
  return ref.watch(supportThreadRepositoryProvider).watchMessages(threadId);
});
