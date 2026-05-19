import 'dart:math';

const _joinCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateFantasyJoinCode({int length = 6}) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _joinCodeChars[random.nextInt(_joinCodeChars.length)],
  ).join();
}
