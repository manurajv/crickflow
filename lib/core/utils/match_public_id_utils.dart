import 'dart:math';

/// Generates a short public match ID shown in the app (not the Firestore doc id).
String generatePublicMatchId([Random? random]) {
  final rng = random ?? Random();
  final now = DateTime.now();
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  final suffix = rng.nextInt(100).toString().padLeft(2, '0');
  return '$yy$mm$dd$suffix';
}
