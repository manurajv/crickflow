import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/data/models/community_post_model.dart';
import 'package:crickflow/domain/community/tournament_looking_post_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostModel _lookingPost({
  DateTime? start,
  DateTime? end,
  String title = 'Teams wanted',
}) {
  return CommunityPostModel(
    id: 'p1',
    authorId: 'u1',
    authorName: 'Org',
    title: title,
    body: 'Need teams',
    category: CommunityPostCategory.tournamentNeed,
    postKind: CommunityPostKind.tournament,
    tournamentId: 't1',
    tournamentSnapshot: CommunityTournamentSnapshot(
      tournamentId: 't1',
      name: 'Cup',
      startDate: start,
      endDate: end,
    ),
  );
}

void main() {
  final today = DateTime(2026, 7, 11);

  group('isTournamentLookingPostExpired', () {
    test('hides when end date is before today', () {
      final post = _lookingPost(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 10),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isTrue);
    });

    test('hides when start date is today', () {
      final post = _lookingPost(
        start: DateTime(2026, 7, 11),
        end: DateTime(2026, 7, 20),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isTrue);
    });

    test('hides when start date is before today', () {
      final post = _lookingPost(
        start: DateTime(2026, 7, 10),
        end: DateTime(2026, 7, 20),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isTrue);
    });

    test('shows when start is after today', () {
      final post = _lookingPost(
        start: DateTime(2026, 7, 12),
        end: DateTime(2026, 7, 20),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isFalse);
      expect(
        shouldShowTournamentLookingCommunityPost(post, now: today),
        isTrue,
      );
    });

    test('shows when no dates on snapshot', () {
      final post = _lookingPost();
      expect(isTournamentLookingPostExpired(post, now: today), isFalse);
    });

    test('ignores non-looking posts', () {
      final post = CommunityPostModel(
        id: 'p2',
        authorId: 'u1',
        authorName: 'Org',
        title: 'Great match',
        body: 'Hi',
        category: CommunityPostCategory.general,
        tournamentSnapshot: CommunityTournamentSnapshot(
          startDate: DateTime(2026, 7, 1),
          endDate: DateTime(2026, 7, 10),
        ),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isFalse);
    });

    test('officials needed title matches looking posts', () {
      final post = _lookingPost(
        title: 'Officials needed',
        start: DateTime(2026, 7, 11),
      );
      expect(isTournamentLookingPostExpired(post, now: today), isTrue);
    });
  });
}
