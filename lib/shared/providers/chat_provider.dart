import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'providers.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final chatListProvider = StreamProvider<List<ChatModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchChatsForUser(uid);
});

final messageRequestsProvider = StreamProvider<List<ChatModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchMessageRequests(uid);
});

final chatUnreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(0);
  return ref.watch(chatRepositoryProvider).watchUnreadChatCount(uid);
});

final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value({});
  return ref.watch(chatRepositoryProvider).watchBlockedUserIds(uid);
});

final messageRequestCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(0);
  return ref.watch(chatRepositoryProvider).watchMessageRequestCount(uid);
});

final chatProvider = StreamProvider.family<ChatModel?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchChat(chatId);
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});
