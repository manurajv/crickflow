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
        OpportunityCategory.findGround => 'Grounds',
        OpportunityCategory.findTournament => 'Find Tournament',
        OpportunityCategory.findSponsor => 'Find Sponsor',
        OpportunityCategory.findCommentator => 'Find Commentator',
        OpportunityCategory.findStreamingCrew => 'Find Streaming Crew',
        OpportunityCategory.findPhotographer => 'Find Photographer',
        OpportunityCategory.findVideographer => 'Find Videographer',
      };

  /// Compact badge text for cards (e.g. FIND PLAYER).
  String get badgeLabel => chipLabel.toUpperCase();

  /// Categories available when creating a new post.
  /// Tournaments are listed in Community, not Discover.
  static List<OpportunityCategory> get creatableCategories =>
      OpportunityCategory.values
          .where((c) => c != OpportunityCategory.findTournament)
          .toList(growable: false);

  /// Categories shown as feed filter chips.
  static List<OpportunityCategory> get feedCategories => creatableCategories;

  /// Whether this category can be created from Discover.
  bool get isCreatable => this != OpportunityCategory.findTournament;

  /// Locked create-post title — not user-editable.
  String get fixedTitle => switch (this) {
        OpportunityCategory.findPlayer => "I'm looking for a player",
        OpportunityCategory.findTeam => "I'm looking for a team",
        OpportunityCategory.findUmpire => "I'm looking for an umpire",
        OpportunityCategory.findScorer => "I'm looking for a scorer",
        OpportunityCategory.findCoach => "I'm looking for a coach",
        OpportunityCategory.findGround => 'Ground available',
        OpportunityCategory.findTournament => "I'm looking for a tournament",
        OpportunityCategory.findSponsor => "I'm looking for a sponsor",
        OpportunityCategory.findCommentator => "I'm looking for a commentator",
        OpportunityCategory.findStreamingCrew =>
          "I'm looking for a streaming crew",
        OpportunityCategory.findPhotographer =>
          "I'm looking for a photographer",
        OpportunityCategory.findVideographer =>
          "I'm looking for a videographer",
      };

  /// Who should post this category (shown as "Posting as").
  String get posterRole => switch (this) {
        OpportunityCategory.findPlayer => 'Team / captain / organizer',
        OpportunityCategory.findTeam => 'Player',
        OpportunityCategory.findUmpire => 'Organizer / match manager',
        OpportunityCategory.findScorer => 'Organizer / match manager',
        OpportunityCategory.findCoach => 'Player / team / academy',
        OpportunityCategory.findGround => 'Ground owner / manager',
        OpportunityCategory.findTournament => 'Player / team',
        OpportunityCategory.findSponsor => 'Organizer / tournament',
        OpportunityCategory.findCommentator => 'Organizer / streamer',
        OpportunityCategory.findStreamingCrew => 'Organizer / tournament',
        OpportunityCategory.findPhotographer => 'Organizer / team',
        OpportunityCategory.findVideographer => 'Organizer / team',
      };

  /// Subtitle on the category picker.
  String get createSubtitle => switch (this) {
        OpportunityCategory.findPlayer =>
          'Post when you need players for a match or squad',
        OpportunityCategory.findTeam =>
          'Post when you want to join a team — use this if you are the player',
        OpportunityCategory.findUmpire =>
          'Post when your match or tournament needs an umpire',
        OpportunityCategory.findScorer =>
          'Post when you need someone to score the match',
        OpportunityCategory.findCoach =>
          'Post when you need coaching for batting, bowling, or fitness',
        OpportunityCategory.findGround =>
          'List your ground so teams, players, and tournaments can book it',
        OpportunityCategory.findTournament =>
          'Use Community to post tournaments — not available here',
        OpportunityCategory.findSponsor =>
          'Post when your event needs sponsorship support',
        OpportunityCategory.findCommentator =>
          'Post when you need live or recorded commentary',
        OpportunityCategory.findStreamingCrew =>
          'Post when you need cameras and live production',
        OpportunityCategory.findPhotographer =>
          'Post when you need match-day photography',
        OpportunityCategory.findVideographer =>
          'Post when you need highlights or live video',
      };

  /// Hint for the free-text description field.
  String get descriptionHint => switch (this) {
        OpportunityCategory.findPlayer =>
          'Role needed, match day, and what you offer…',
        OpportunityCategory.findTeam =>
          'Your role, level, availability, and what you are looking for…',
        OpportunityCategory.findUmpire =>
          'Match format, date, and what you expect from the umpire…',
        OpportunityCategory.findScorer =>
          'Match format, scoring app preference, and schedule…',
        OpportunityCategory.findCoach =>
          'Goals, age group, and preferred session times…',
        OpportunityCategory.findGround =>
          'Facilities, rates, availability, and how to book…',
        OpportunityCategory.findTournament =>
          'Preferred dates, format, and what kind of event you want…',
        OpportunityCategory.findSponsor =>
          'Event size, audience, and what you can offer the brand…',
        OpportunityCategory.findCommentator =>
          'Match type, languages, and broadcast setup…',
        OpportunityCategory.findStreamingCrew =>
          'Coverage needed, platforms, and match schedule…',
        OpportunityCategory.findPhotographer =>
          'Match day, deliverables, and style you want…',
        OpportunityCategory.findVideographer =>
          'Highlights, live production needs, and timeline…',
      };

  /// Heading above category-specific detail fields.
  String get detailsSectionTitle => switch (this) {
        OpportunityCategory.findPlayer => 'Who you need',
        OpportunityCategory.findTeam => 'About you',
        OpportunityCategory.findUmpire => 'Match needs',
        OpportunityCategory.findScorer => 'Match needs',
        OpportunityCategory.findCoach => 'What you need',
        OpportunityCategory.findGround => 'About your ground',
        OpportunityCategory.findTournament => 'Tournament preferences',
        OpportunityCategory.findSponsor => 'Sponsorship needs',
        OpportunityCategory.findCommentator => 'What you need',
        OpportunityCategory.findStreamingCrew => 'What you need',
        OpportunityCategory.findPhotographer => 'What you need',
        OpportunityCategory.findVideographer => 'What you need',
      };

  /// Short picker title (without "I'm looking for").
  String get lookingForLabel => switch (this) {
        OpportunityCategory.findPlayer => 'Looking for a player',
        OpportunityCategory.findTeam => 'Looking for a team',
        OpportunityCategory.findUmpire => 'Looking for an umpire',
        OpportunityCategory.findScorer => 'Looking for a scorer',
        OpportunityCategory.findCoach => 'Looking for a coach',
        OpportunityCategory.findGround => 'Offer a ground',
        OpportunityCategory.findTournament => 'Looking for a tournament',
        OpportunityCategory.findSponsor => 'Looking for a sponsor',
        OpportunityCategory.findCommentator => 'Looking for a commentator',
        OpportunityCategory.findStreamingCrew => 'Looking for a streaming crew',
        OpportunityCategory.findPhotographer => 'Looking for a photographer',
        OpportunityCategory.findVideographer => 'Looking for a videographer',
      };

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
            OpportunityQuickFilter(
              id: 'rightHand',
              label: 'Right-hand',
              fieldKey: 'battingHand',
              matchValue: 'Right-hand',
            ),
            OpportunityQuickFilter(
              id: 'leftHand',
              label: 'Left-hand',
              fieldKey: 'battingHand',
              matchValue: 'Left-hand',
            ),
            OpportunityQuickFilter.wePay,
            OpportunityQuickFilter.playerPays,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findTeam => const [
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
            OpportunityQuickFilter(
              id: 'club',
              label: 'Club',
              fieldKey: 'teamType',
              matchValue: 'Club',
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
            OpportunityQuickFilter(
              id: 'casual',
              label: 'Casual',
              fieldKey: 'teamType',
              matchValue: 'Casual',
            ),
            OpportunityQuickFilter.iGetPaid,
            OpportunityQuickFilter.iPayToJoin,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findUmpire => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter.certified,
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter(
              id: 'openMatch',
              label: 'Open',
              fieldKey: 'matchCategory',
              matchValue: 'Open',
            ),
            OpportunityQuickFilter(
              id: 'clubMatch',
              label: 'Club',
              fieldKey: 'matchCategory',
              matchValue: 'Club',
            ),
            OpportunityQuickFilter(
              id: 'schoolMatch',
              label: 'School',
              fieldKey: 'matchCategory',
              matchValue: 'School',
            ),
            OpportunityQuickFilter(
              id: 'companyMatch',
              label: 'Company',
              fieldKey: 'matchCategory',
              matchValue: 'Company',
            ),
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        OpportunityCategory.findScorer => const [
            OpportunityQuickFilter.all,
            OpportunityQuickFilter(
              id: 'digital',
              label: 'Digital',
              fieldKey: 'digitalExperience',
              matchValue: 'Yes',
            ),
            OpportunityQuickFilter(
              id: 'crickflow',
              label: 'CrickFlow',
              fieldKey: 'platformsUsed',
              matchValue: 'CrickFlow',
            ),
            OpportunityQuickFilter.experienced,
            OpportunityQuickFilter(
              id: 'openMatch',
              label: 'Open',
              fieldKey: 'matchCategory',
              matchValue: 'Open',
            ),
            OpportunityQuickFilter(
              id: 'clubMatch',
              label: 'Club',
              fieldKey: 'matchCategory',
              matchValue: 'Club',
            ),
            OpportunityQuickFilter(
              id: 'schoolMatch',
              label: 'School',
              fieldKey: 'matchCategory',
              matchValue: 'School',
            ),
            OpportunityQuickFilter(
              id: 'companyMatch',
              label: 'Company',
              fieldKey: 'matchCategory',
              matchValue: 'Company',
            ),
            OpportunityQuickFilter.paid,
            OpportunityQuickFilter.free,
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
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
            OpportunityQuickFilter(
              id: 'allRound',
              label: 'All-round',
              fieldKey: 'coachingType',
              matchValue: 'All-round',
            ),
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
            OpportunityQuickFilter(
              id: 'turf',
              label: 'Turf',
              fieldKey: 'pitchType',
              matchValue: 'Turf',
            ),
            OpportunityQuickFilter(
              id: 'matting',
              label: 'Matting',
              fieldKey: 'pitchType',
              matchValue: 'Matting',
            ),
            OpportunityQuickFilter(
              id: 'astro',
              label: 'Astro',
              fieldKey: 'pitchType',
              matchValue: 'Astro',
            ),
            OpportunityQuickFilter.leather,
            OpportunityQuickFilter.tennis,
            OpportunityQuickFilter.nearby,
            OpportunityQuickFilter.newest,
          ],
        // Legacy only — not creatable; prefer Community tournaments.
        OpportunityCategory.findTournament => const [
            OpportunityQuickFilter.all,
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
            OpportunityQuickFilter(
              id: 'english',
              label: 'English',
              fieldKey: 'languages',
              matchValue: 'English',
            ),
            OpportunityQuickFilter(
              id: 'sinhala',
              label: 'Sinhala',
              fieldKey: 'languages',
              matchValue: 'Sinhala',
            ),
            OpportunityQuickFilter(
              id: 'tamil',
              label: 'Tamil',
              fieldKey: 'languages',
              matchValue: 'Tamil',
            ),
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
            OpportunityQuickFilter(
              id: 'commentary',
              label: 'Commentary',
              fieldKey: 'commentary',
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
            OpportunityQuickFilter(
              id: 'highlights',
              label: 'Highlights',
              fieldKey: 'highlightPackages',
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

  /// Staff / generic paid (umpire, scorer) + aliases for We pay / I get paid.
  static const paid = OpportunityQuickFilter(
    id: 'paid',
    label: 'Paid',
    fieldKey: 'payment',
    matchValue: 'Paid',
  );

  /// Find Player — organizer pays the player.
  static const wePay = OpportunityQuickFilter(
    id: 'paid',
    label: 'We pay',
    fieldKey: 'payment',
    matchValue: 'We pay',
  );

  /// Find Team — player expects to get paid.
  static const iGetPaid = OpportunityQuickFilter(
    id: 'paid',
    label: 'I get paid',
    fieldKey: 'payment',
    matchValue: 'I get paid',
  );

  /// Find Player — player pays to join.
  static const playerPays = OpportunityQuickFilter(
    id: 'payToPlay',
    label: 'Player pays',
    fieldKey: 'payment',
    matchValue: 'Player pays',
  );

  /// Find Team — player pays to join.
  static const iPayToJoin = OpportunityQuickFilter(
    id: 'payToPlay',
    label: 'I pay to join',
    fieldKey: 'payment',
    matchValue: 'I pay to join',
  );

  /// Global / legacy “pay to play” chip.
  static const payToPlay = OpportunityQuickFilter(
    id: 'payToPlay',
    label: 'Pay to join',
    fieldKey: 'payment',
    matchValue: 'Player pays',
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
    leather,
    tennis,
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
