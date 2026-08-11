import '../../core/constants/enums.dart';
import '../../data/models/community_post_model.dart';

/// Calendar day at local midnight for [value].
DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whether [post] is a draft-tournament looking post (teams / officials).
bool isTournamentLookingCommunityPost(CommunityPostModel post) {
  if (post.category == CommunityPostCategory.tournamentNeed) return true;
  if (post.postKind != CommunityPostKind.tournament) return false;
  final title = post.title.trim().toLowerCase();
  return title == 'teams wanted' || title == 'officials needed';
}

/// Looking posts expire when the tournament has started or already ended.
///
/// Rules (calendar days, local time):
/// - Hide if [endDate] is before today (ended yesterday or earlier).
/// - Hide if [startDate] is today or earlier (recruitment no longer useful).
///
/// Posts without usable dates stay visible.
bool isTournamentLookingPostExpired(
  CommunityPostModel post, {
  DateTime? now,
}) {
  if (!isTournamentLookingCommunityPost(post)) return false;

  final snap = post.tournamentSnapshot;
  if (snap == null) return false;

  final today = calendarDay(now ?? DateTime.now());

  final end = snap.endDate;
  if (end != null) {
    final endDay = calendarDay(end);
    if (endDay.isBefore(today)) return true;
  }

  final start = snap.startDate;
  if (start != null) {
    final startDay = calendarDay(start);
    if (!startDay.isAfter(today)) return true;
  }

  return false;
}

/// Feed / deep-link visibility for tournament looking posts.
bool shouldShowTournamentLookingCommunityPost(
  CommunityPostModel post, {
  DateTime? now,
}) =>
    !isTournamentLookingPostExpired(post, now: now);
