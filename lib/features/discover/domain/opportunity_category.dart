import 'package:flutter/material.dart';

/// Cricket opportunity marketplace categories.
enum OpportunityCategory {
  findPlayer,
  findTeam,
  findUmpire,
  findScorer,
  findCoach,
  findGround,
  findTournament,
  findSponsor,
  findCommentator,
  findStreamingCrew,
  findPhotographer,
  findVideographer,
}

extension OpportunityCategoryX on OpportunityCategory {
  String get id => name;

  String get chipLabel => switch (this) {
        OpportunityCategory.findPlayer => 'Find Player',
        OpportunityCategory.findTeam => 'Find Team',
        OpportunityCategory.findUmpire => 'Find Umpire',
        OpportunityCategory.findScorer => 'Find Scorer',
        OpportunityCategory.findCoach => 'Find Coach',
        OpportunityCategory.findGround => 'Find Ground',
        OpportunityCategory.findTournament => 'Find Tournament',
        OpportunityCategory.findSponsor => 'Find Sponsor',
        OpportunityCategory.findCommentator => 'Find Commentator',
        OpportunityCategory.findStreamingCrew => 'Find Streaming Crew',
        OpportunityCategory.findPhotographer => 'Find Photographer',
        OpportunityCategory.findVideographer => 'Find Videographer',
      };

  /// Compact badge text for cards (e.g. FIND PLAYER).
  String get badgeLabel => chipLabel.toUpperCase();

  IconData get icon => switch (this) {
        OpportunityCategory.findPlayer => Icons.person_search_outlined,
        OpportunityCategory.findTeam => Icons.groups_outlined,
        OpportunityCategory.findUmpire => Icons.sports,
        OpportunityCategory.findScorer => Icons.scoreboard_outlined,
        OpportunityCategory.findCoach => Icons.school_outlined,
        OpportunityCategory.findGround => Icons.stadium_outlined,
        OpportunityCategory.findTournament => Icons.emoji_events_outlined,
        OpportunityCategory.findSponsor => Icons.handshake_outlined,
        OpportunityCategory.findCommentator => Icons.mic_outlined,
        OpportunityCategory.findStreamingCrew => Icons.videocam_outlined,
        OpportunityCategory.findPhotographer => Icons.photo_camera_outlined,
        OpportunityCategory.findVideographer => Icons.movie_creation_outlined,
      };

  Color get badgeColor => switch (this) {
        OpportunityCategory.findPlayer => const Color(0xFF1E88E5),
        OpportunityCategory.findTeam => const Color(0xFF43A047),
        OpportunityCategory.findUmpire => const Color(0xFFFB8C00),
        OpportunityCategory.findScorer => const Color(0xFF8E24AA),
        OpportunityCategory.findCoach => const Color(0xFF00897B),
        OpportunityCategory.findGround => const Color(0xFF5D4037),
        OpportunityCategory.findTournament => const Color(0xFFF9A825),
        OpportunityCategory.findSponsor => const Color(0xFF3949AB),
        OpportunityCategory.findCommentator => const Color(0xFF00ACC1),
        OpportunityCategory.findStreamingCrew => const Color(0xFFE53935),
        OpportunityCategory.findPhotographer => const Color(0xFF6D4C41),
        OpportunityCategory.findVideographer => const Color(0xFFAD1457),
      };

  /// Secondary filter chips shown under the category selector.
  List<OpportunityQuickFilter> get quickFilters => switch (this) {
        OpportunityCategory.findPlayer => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'batsman',
              label: 'Batsman',
              fieldKey: 'playerType',
              matchValue: 'Batsman',
            ),
            OpportunityQuickFilter(
              id: 'bowler',
              label: 'Bowler',
              fieldKey: 'playerType',
              matchValue: 'Bowler',
            ),
            OpportunityQuickFilter(
              id: 'allRounder',
              label: 'All-rounder',
              fieldKey: 'playerType',
              matchValue: 'All-rounder',
            ),
            OpportunityQuickFilter(
              id: 'keeper',
              label: 'Keeper',
              fieldKey: 'playerType',
              matchValue: 'Wicket Keeper',
            ),
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findTeam => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'club',
              label: 'Club',
              fieldKey: 'teamType',
              matchValue: 'Club',
            ),
            OpportunityQuickFilter(
              id: 'corporate',
              label: 'Corporate',
              fieldKey: 'teamType',
              matchValue: 'Corporate',
            ),
            OpportunityQuickFilter(
              id: 'school',
              label: 'School',
              fieldKey: 'teamType',
              matchValue: 'School',
            ),
            OpportunityQuickFilter(
              id: 'academy',
              label: 'Academy',
              fieldKey: 'teamType',
              matchValue: 'Academy',
            ),
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findUmpire => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.certified,
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findScorer => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findCoach => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'batting',
              label: 'Batting',
              fieldKey: 'coachingType',
              matchValue: 'Batting',
            ),
            OpportunityQuickFilter(
              id: 'bowling',
              label: 'Bowling',
              fieldKey: 'coachingType',
              matchValue: 'Bowling',
            ),
            OpportunityQuickFilter(
              id: 'fitness',
              label: 'Fitness',
              fieldKey: 'coachingType',
              matchValue: 'Fitness',
            ),
            OpportunityQuickFilter(
              id: 'fielding',
              label: 'Fielding',
              fieldKey: 'coachingType',
              matchValue: 'Fielding',
            ),
            OpportunityQuickFilter.certified,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findGround => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'booking',
              label: 'Bookable',
              fieldKey: 'bookingAvailable',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findTournament => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findSponsor => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findCommentator => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findStreamingCrew => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'drone',
              label: 'Drone',
              fieldKey: 'drone',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter(
              id: 'graphics',
              label: 'Live Graphics',
              fieldKey: 'liveGraphics',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findPhotographer => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findVideographer => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'drone',
              label: 'Drone',
              fieldKey: 'drone',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter(
              id: 'live',
              label: 'Live Production',
              fieldKey: 'liveProduction',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
      };

  static OpportunityCategory? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final c in OpportunityCategory.values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

/// Built-in + category-specific quick filters for the feed.
class OpportunityQuickFilter {
  const OpportunityQuickFilter({
    required this.id,
    required this.label,
    this.fieldKey,
    this.matchValue,
    this.sortNewest = false,
    this.nearbyOnly = false,
  });

  final String id;
  final String label;
  final String? fieldKey;
  final String? matchValue;
  final bool sortNewest;
  final bool nearbyOnly;

  static const all = OpportunityQuickFilter(id: 'all', label: 'All');

  static const paid = OpportunityQuickFilter(
    id: 'paid',
    label: 'Paid',
    fieldKey: 'payment',
    matchValue: 'Paid',
  );

  static const free = OpportunityQuickFilter(
    id: 'free',
    label: 'Free',
    fieldKey: 'payment',
    matchValue: 'Free',
  );

  static const leather = OpportunityQuickFilter(
    id: 'leather',
    label: 'Leather',
    fieldKey: 'matchType',
    matchValue: 'Leather Ball',
  );

  static const tennis = OpportunityQuickFilter(
    id: 'tennis',
    label: 'Tennis',
    fieldKey: 'matchType',
    matchValue: 'Tennis Ball',
  );

  static const nearby = OpportunityQuickFilter(
    id: 'nearby',
    label: 'Nearby',
    nearbyOnly: true,
  );

  static const newest = OpportunityQuickFilter(
    id: 'newest',
    label: 'Newest',
    sortNewest: true,
  );

  static const certified = OpportunityQuickFilter(
    id: 'certified',
    label: 'Certified',
    fieldKey: 'certified',
    matchValue: 'Yes',
  );

  static const experienced = OpportunityQuickFilter(
    id: 'experienced',
    label: 'Experienced',
    fieldKey: 'experience',
    matchValue: 'Experienced',
  );

  /// Default filters when category is "All".
  static const globalDefaults = [
    all,
    paid,
    free,
    nearby,
    newest,
  ];
}

/// Post expiry options.
enum OpportunityExpiry {
  oneDay(1, '1 day'),
  threeDays(3, '3 days'),
  sevenDays(7, '7 days'),
  thirtyDays(30, '30 days');

  const OpportunityExpiry(this.days, this.label);
  final int days;
  final String label;
}

/// Contact channels a poster may enable.
enum OpportunityContactMethod {
  chat,
  phone,
  whatsapp,
}

extension OpportunityContactMethodX on OpportunityContactMethod {
  String get label => switch (this) {
        OpportunityContactMethod.chat => 'Chat',
        OpportunityContactMethod.phone => 'Phone',
        OpportunityContactMethod.whatsapp => 'WhatsApp',
      };

  IconData get icon => switch (this) {
        OpportunityContactMethod.chat => Icons.chat_bubble_outline,
        OpportunityContactMethod.phone => Icons.call_outlined,
        OpportunityContactMethod.whatsapp => Icons.message_outlined,
      };
}

/// Report reasons for marketplace posts.
enum OpportunityReportReason {
  spam('Spam'),
  fake('Fake'),
  offensive('Offensive'),
  duplicate('Duplicate'),
  other('Other');

  const OpportunityReportReason(this.label);
  final String label;
}
