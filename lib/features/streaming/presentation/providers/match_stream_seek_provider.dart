import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seek request from Highlights tab (or elsewhere) to the in-app stream player.
class MatchStreamSeekRequest {
  const MatchStreamSeekRequest({
    required this.offsetMs,
    required this.nonce,
    this.sessionId,
    this.label,
  });

  final int offsetMs;
  final String? sessionId;
  final String? label;
  /// Changes on every request so repeated seeks to the same offset still apply.
  final int nonce;
}

final matchStreamSeekProvider =
    StateProvider.family<MatchStreamSeekRequest?, String>((ref, matchId) => null);

void requestMatchStreamSeek(
  WidgetRef ref, {
  required String matchId,
  required int offsetMs,
  String? sessionId,
  String? label,
}) {
  ref.read(matchStreamSeekProvider(matchId).notifier).state = MatchStreamSeekRequest(
    offsetMs: offsetMs,
    sessionId: sessionId == null || sessionId.trim().isEmpty ? null : sessionId.trim(),
    label: label,
    nonce: DateTime.now().microsecondsSinceEpoch,
  );
}
