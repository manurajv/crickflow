import '../../../core/constants/player_profile_constants.dart';
import 'opportunity_category.dart';

/// How a dynamic form field is rendered / stored.
enum OpportunityFieldType {
  text,
  multiline,
  number,
  singleSelect,
  multiSelect,
  yesNo,
  date,
  /// Single day or start–end range (`key` + `${key}End`).
  dateOrRange,
  /// Optional/required http(s) URL.
  url,
}

/// Declarative field definition — drives create form + validation.
class OpportunityFieldDef {
  const OpportunityFieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = false,
    this.hint,
    this.maxLines = 1,
    this.showOnCard = false,
  });

  final String key;
  final String label;
  final OpportunityFieldType type;
  final List<String> options;
  final bool required;
  final String? hint;
  final int maxLines;

  /// When true, non-empty values are prioritized earlier among card badges.
  /// All filled fields appear on the card; dates use the calendar row.
  final bool showOnCard;
}

/// Shared / common fields present on every post (title, description, etc.
/// are handled outside the dynamic map).
class OpportunityFieldSchema {
  OpportunityFieldSchema._();

  static List<OpportunityFieldDef> fieldsFor(OpportunityCategory category) {
    return switch (category) {
      OpportunityCategory.findPlayer => _findPlayer,
      OpportunityCategory.findTeam => _findTeam,
      OpportunityCategory.findUmpire => _findUmpire,
      OpportunityCategory.findScorer => _findScorer,
      OpportunityCategory.findCoach => _findCoach,
      OpportunityCategory.findGround => _findGround,
      OpportunityCategory.findTournament => _findTournament,
      OpportunityCategory.findSponsor => _findSponsor,
      OpportunityCategory.findCommentator => _findCommentator,
      OpportunityCategory.findStreamingCrew => _findStreamingCrew,
      OpportunityCategory.findPhotographer => _findPhotographer,
      OpportunityCategory.findVideographer => _findVideographer,
    };
  }

  /// Team / organizer seeking players.
  static const _findPlayer = [
    OpportunityFieldDef(
      key: 'playerType',
      label: 'Role needed',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'],
    ),
    OpportunityFieldDef(
      key: 'requiredPlayers',
      label: 'How many players',
      type: OpportunityFieldType.number,
      required: true,
      hint: 'e.g. 2',
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball'],
    ),
    OpportunityFieldDef(
      key: 'ageRange',
      label: 'Age range',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience needed',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'battingHand',
      label: 'Batting style',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Right-hand', 'Left-hand'],
    ),
    OpportunityFieldDef(
      key: 'bowlingStyle',
      label: 'Bowling style (if bowler)',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: PlayerBowlingStyleLabels.opportunityOptions,
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'Match date',
      type: OpportunityFieldType.date,
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament / series (optional)',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'We pay', 'Player pays'],
    ),
    OpportunityFieldDef(
      key: 'paymentAmount',
      label: 'Amount',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 2000 / match (optional)',
      showOnCard: true,
    ),
  ];

  /// Player seeking a team to join.
  static const _findTeam = [
    OpportunityFieldDef(
      key: 'playerType',
      label: 'My role',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'],
    ),
    OpportunityFieldDef(
      key: 'bowlingStyle',
      label: 'Bowling style',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: PlayerBowlingStyleLabels.opportunityOptions,
    ),
    OpportunityFieldDef(
      key: 'battingHand',
      label: 'Batting style',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Right-hand', 'Left-hand'],
    ),
    OpportunityFieldDef(
      key: 'ageCategory',
      label: 'Age category',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      required: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'My experience',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Preferred ball type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball', 'Either'],
    ),
    OpportunityFieldDef(
      key: 'teamType',
      label: 'Preferred team type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Club', 'Corporate', 'School', 'Academy', 'Casual', 'Any'],
    ),
    OpportunityFieldDef(
      key: 'playingLevel',
      label: 'Preferred level',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Competitive', 'Elite'],
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'I get paid', 'I pay to join'],
    ),
    OpportunityFieldDef(
      key: 'paymentAmount',
      label: 'Amount',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 2000 / match (optional)',
      showOnCard: true,
    ),
  ];

  static const _matchCategoryOptions = [
    'Open',
    'Club',
    'School',
    'Company',
    'Corporate',
    'Academy',
    'Friendly',
    'Tournament',
  ];

  /// Organizer seeking umpire(s).
  static const _findUmpire = [
    OpportunityFieldDef(
      key: 'numberRequired',
      label: 'Umpires needed',
      type: OpportunityFieldType.number,
      required: true,
      hint: 'e.g. 2',
    ),
    OpportunityFieldDef(
      key: 'matchCategory',
      label: 'Match type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: _matchCategoryOptions,
    ),
    OpportunityFieldDef(
      key: 'certified',
      label: 'Certification required',
      type: OpportunityFieldType.yesNo,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience preferred',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament / series (optional)',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball type',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball'],
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'Paid'],
    ),
    OpportunityFieldDef(
      key: 'paymentAmount',
      label: 'Amount',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 3000 / day (optional)',
      showOnCard: true,
    ),
  ];

  /// Organizer seeking scorer.
  static const _findScorer = [
    OpportunityFieldDef(
      key: 'matchCategory',
      label: 'Match type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: _matchCategoryOptions,
    ),
    OpportunityFieldDef(
      key: 'digitalExperience',
      label: 'Digital scoring required',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'platformsUsed',
      label: 'Preferred platforms',
      type: OpportunityFieldType.multiSelect,
      options: ['CrickFlow', 'Manual', 'Any'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience preferred',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball type',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball'],
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'Paid'],
    ),
    OpportunityFieldDef(
      key: 'paymentAmount',
      label: 'Amount',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 2500 / match (optional)',
      showOnCard: true,
    ),
  ];

  /// Seeking a coach.
  static const _findCoach = [
    OpportunityFieldDef(
      key: 'coachingType',
      label: 'Coaching focus',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Batting', 'Bowling', 'Fitness', 'Fielding', 'All-round'],
    ),
    OpportunityFieldDef(
      key: 'ageRange',
      label: 'Age group',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Coach experience preferred',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'certification',
      label: 'Certification preferred',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. Level 1, any, none',
    ),
    OpportunityFieldDef(
      key: 'fees',
      label: 'Budget / session rate',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 5000 / session',
      showOnCard: true,
    ),
  ];

  /// Ground owner listing a venue (not seeking one).
  static const _findGround = [
    OpportunityFieldDef(
      key: 'groundName',
      label: 'Ground name',
      type: OpportunityFieldType.text,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'pitchType',
      label: 'Pitch type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Turf', 'Matting', 'Concrete', 'Astro', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'bookingAvailable',
      label: 'Booking available',
      type: OpportunityFieldType.yesNo,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball types allowed',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball', 'Either'],
    ),
    OpportunityFieldDef(
      key: 'fees',
      label: 'Rates / hire fee',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 15000 / day',
    ),
    OpportunityFieldDef(
      key: 'facilities',
      label: 'Facilities (optional)',
      type: OpportunityFieldType.multiline,
      maxLines: 3,
      hint: 'Pavilion, nets, lighting, parking…',
    ),
  ];

  /// Legacy seeking schema — category is no longer creatable in Discover.
  static const _findTournament = [
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball', 'Either'],
    ),
    OpportunityFieldDef(
      key: 'format',
      label: 'Preferred format',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['League', 'Knockout', 'League + Knockout', 'Friendly Series', 'Any'],
    ),
    OpportunityFieldDef(
      key: 'overs',
      label: 'Preferred overs',
      type: OpportunityFieldType.singleSelect,
      options: ['5', '8', '10', '15', '20', '25', '30', '40', '50', 'Any'],
    ),
    OpportunityFieldDef(
      key: 'ageCategory',
      label: 'Age category',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'entryFee',
      label: 'Max entry fee (optional)',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 10000 / team',
    ),
    OpportunityFieldDef(
      key: 'registrationDeadline',
      label: 'Need to register by (optional)',
      type: OpportunityFieldType.date,
    ),
  ];

  /// Looking for a sponsor.
  static const _findSponsor = [
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Event / tournament',
      type: OpportunityFieldType.text,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'business',
      label: 'Industry preference (optional)',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. Sports, FMCG, Local business',
    ),
    OpportunityFieldDef(
      key: 'budget',
      label: 'Sponsorship amount needed',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 50,000',
    ),
    OpportunityFieldDef(
      key: 'expectations',
      label: 'What you need from the sponsor',
      type: OpportunityFieldType.multiline,
      maxLines: 3,
    ),
    OpportunityFieldDef(
      key: 'brandingRequirements',
      label: 'What you can offer the brand',
      type: OpportunityFieldType.multiline,
      maxLines: 3,
    ),
  ];

  /// Looking for a commentator.
  static const _findCommentator = [
    OpportunityFieldDef(
      key: 'languages',
      label: 'Languages needed',
      type: OpportunityFieldType.multiSelect,
      required: true,
      showOnCard: true,
      options: ['English', 'Sinhala', 'Tamil', 'Hindi', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience preferred',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'fees',
      label: 'Budget / rate',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 5000 / match',
    ),
  ];

  /// Looking for streaming crew.
  static const _findStreamingCrew = [
    OpportunityFieldDef(
      key: 'cameras',
      label: 'Cameras needed',
      type: OpportunityFieldType.text,
      hint: 'e.g. 3 cameras',
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'drone',
      label: 'Need drone',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'commentary',
      label: 'Need commentary',
      type: OpportunityFieldType.yesNo,
    ),
    OpportunityFieldDef(
      key: 'liveGraphics',
      label: 'Need live graphics',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'replay',
      label: 'Need replay',
      type: OpportunityFieldType.yesNo,
    ),
    OpportunityFieldDef(
      key: 'streamingPlatform',
      label: 'Streaming platform',
      type: OpportunityFieldType.multiSelect,
      options: ['YouTube', 'Facebook', 'Instagram', 'Twitch', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Budget',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 25000 / match',
    ),
  ];

  /// Looking for a photographer.
  static const _findPhotographer = [
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience preferred',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'equipment',
      label: 'Equipment notes (optional)',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'portfolio',
      label: 'Portfolio reference (optional)',
      type: OpportunityFieldType.url,
      hint: 'https://…',
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Budget',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 8000 / match',
    ),
  ];

  /// Looking for a videographer.
  static const _findVideographer = [
    OpportunityFieldDef(
      key: 'highlightPackages',
      label: 'Need highlight packages',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'liveProduction',
      label: 'Need live production',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'drone',
      label: 'Need drone',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience preferred',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'When needed',
      type: OpportunityFieldType.dateOrRange,
    ),
    OpportunityFieldDef(
      key: 'portfolio',
      label: 'Portfolio reference (optional)',
      type: OpportunityFieldType.url,
      hint: 'https://…',
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Budget',
      type: OpportunityFieldType.text,
      showOnCard: true,
      hint: 'e.g. LKR 15000 / match',
    ),
  ];
}
