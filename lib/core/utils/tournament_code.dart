import 'dart:math';

const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Generates a human-readable tournament code (e.g. ABC2026).
String generateTournamentCode({int prefixLength = 3, int? year}) {
  final random = Random.secure();
  final prefix = List.generate(
    prefixLength,
    (_) => _codeChars[random.nextInt(_codeChars.length)],
  ).join();
  final y = year ?? DateTime.now().year;
  return '$prefix$y';
}

String tournamentInvitePath(String tournamentId) => '/tournaments/$tournamentId';

String tournamentCodeJoinPath(String code) =>
    '/tournaments/join?code=${code.toUpperCase()}';
