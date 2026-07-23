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

  /// When true, non-empty values appear as chips on the feed card.
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

  static const _findPlayer = [
    OpportunityFieldDef(
      key: 'playerType',
      label: 'Player Type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Batsman', 'Bowler', 'All-rounder', 'Wicket Keeper'],
    ),
    OpportunityFieldDef(
      key: 'bowlingStyle',
      label: 'Bowling Style',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: [
        'Right Arm Fast',
        'Right Arm Medium',
        'Left Arm Fast',
        'Left Arm Spin',
        'Right Arm Off Spin',
        'Leg Spinner',
        'N/A',
      ],
    ),
    OpportunityFieldDef(
      key: 'battingHand',
      label: 'Batting Hand',
      type: OpportunityFieldType.singleSelect,
      options: ['Right', 'Left'],
    ),
    OpportunityFieldDef(
      key: 'ageRange',
      label: 'Age Range',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament Name',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'Match Date',
      type: OpportunityFieldType.date,
    ),
    OpportunityFieldDef(
      key: 'ground',
      label: 'Ground',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Match Type',
      type: OpportunityFieldType.singleSelect,
      required: true,
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
      key: 'requiredPlayers',
      label: 'Required Players',
      type: OpportunityFieldType.number,
      required: true,
      hint: 'e.g. 2',
    ),
  ];

  static const _findTeam = [
    OpportunityFieldDef(
      key: 'teamType',
      label: 'Team Type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Club', 'Corporate', 'School', 'Academy', 'Casual'],
    ),
    OpportunityFieldDef(
      key: 'needPlayersFor',
      label: 'Need Players For',
      type: OpportunityFieldType.text,
      hint: 'Tournament / series / practice',
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'playingLevel',
      label: 'Playing Level',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Competitive', 'Elite'],
    ),
    OpportunityFieldDef(
      key: 'ageCategory',
      label: 'Age Category',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['U13', 'U15', 'U17', 'U19', 'Open', 'Veterans'],
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'Paid'],
    ),
  ];

  static const _findUmpire = [
    OpportunityFieldDef(
      key: 'certified',
      label: 'Certified',
      type: OpportunityFieldType.yesNo,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'level',
      label: 'Level',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Club', 'District', 'Provincial', 'National'],
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'ground',
      label: 'Ground',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'Date',
      type: OpportunityFieldType.date,
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
      key: 'numberRequired',
      label: 'Number Required',
      type: OpportunityFieldType.number,
      required: true,
    ),
  ];

  static const _findScorer = [
    OpportunityFieldDef(
      key: 'digitalExperience',
      label: 'Digital Scorekeeping Experience',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'platformsUsed',
      label: 'Platforms Used',
      type: OpportunityFieldType.multiSelect,
      options: ['CrickFlow', 'CricHeroes', 'CricClubs', 'Manual', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'ground',
      label: 'Ground',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'matchDate',
      label: 'Date',
      type: OpportunityFieldType.date,
    ),
    OpportunityFieldDef(
      key: 'payment',
      label: 'Payment',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Free', 'Paid'],
    ),
  ];

  static const _findCoach = [
    OpportunityFieldDef(
      key: 'coachingType',
      label: 'Coaching Type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Batting', 'Bowling', 'Fitness', 'Fielding'],
    ),
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'certification',
      label: 'Certification',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'fees',
      label: 'Fees',
      type: OpportunityFieldType.text,
      hint: 'e.g. LKR 5000 / session',
      showOnCard: true,
    ),
  ];

  static const _findGround = [
    OpportunityFieldDef(
      key: 'groundName',
      label: 'Ground Name',
      type: OpportunityFieldType.text,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'pitchType',
      label: 'Pitch Type',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Turf', 'Matting', 'Concrete', 'Astro', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'bookingAvailable',
      label: 'Booking Available',
      type: OpportunityFieldType.yesNo,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'contact',
      label: 'Contact',
      type: OpportunityFieldType.text,
      hint: 'Phone or email for bookings',
    ),
  ];

  static const _findTournament = [
    OpportunityFieldDef(
      key: 'entryFee',
      label: 'Entry Fee',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'format',
      label: 'Format',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['League', 'Knockout', 'League + Knockout', 'Friendly Series'],
    ),
    OpportunityFieldDef(
      key: 'overs',
      label: 'Overs',
      type: OpportunityFieldType.singleSelect,
      options: ['5', '8', '10', '15', '20', '25', '30', '40', '50'],
    ),
    OpportunityFieldDef(
      key: 'matchType',
      label: 'Ball Type',
      type: OpportunityFieldType.singleSelect,
      required: true,
      showOnCard: true,
      options: ['Leather Ball', 'Tennis Ball'],
    ),
    OpportunityFieldDef(
      key: 'prizeMoney',
      label: 'Prize Money',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'organizer',
      label: 'Organizer',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'contact',
      label: 'Contact',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'registrationDeadline',
      label: 'Registration Deadline',
      type: OpportunityFieldType.date,
    ),
  ];

  static const _findSponsor = [
    OpportunityFieldDef(
      key: 'business',
      label: 'Business',
      type: OpportunityFieldType.text,
      required: true,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'budget',
      label: 'Budget',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'tournamentName',
      label: 'Tournament',
      type: OpportunityFieldType.text,
    ),
    OpportunityFieldDef(
      key: 'expectations',
      label: 'Expectations',
      type: OpportunityFieldType.multiline,
      maxLines: 3,
    ),
    OpportunityFieldDef(
      key: 'brandingRequirements',
      label: 'Branding Requirements',
      type: OpportunityFieldType.multiline,
      maxLines: 3,
    ),
  ];

  static const _findCommentator = [
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'languages',
      label: 'Languages',
      type: OpportunityFieldType.multiSelect,
      showOnCard: true,
      options: ['English', 'Sinhala', 'Tamil', 'Hindi', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'fees',
      label: 'Fees',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
  ];

  static const _findStreamingCrew = [
    OpportunityFieldDef(
      key: 'cameras',
      label: 'Cameras',
      type: OpportunityFieldType.text,
      hint: 'e.g. 3 cameras',
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'drone',
      label: 'Drone',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'commentary',
      label: 'Commentary',
      type: OpportunityFieldType.yesNo,
    ),
    OpportunityFieldDef(
      key: 'liveGraphics',
      label: 'Live Graphics',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'replay',
      label: 'Replay',
      type: OpportunityFieldType.yesNo,
    ),
    OpportunityFieldDef(
      key: 'streamingPlatform',
      label: 'Streaming Platform',
      type: OpportunityFieldType.multiSelect,
      options: ['YouTube', 'Facebook', 'Instagram', 'Twitch', 'Other'],
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Price',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
  ];

  static const _findPhotographer = [
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'portfolio',
      label: 'Portfolio URL',
      type: OpportunityFieldType.text,
      hint: 'https://…',
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Price',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'equipment',
      label: 'Equipment',
      type: OpportunityFieldType.text,
    ),
  ];

  static const _findVideographer = [
    OpportunityFieldDef(
      key: 'experience',
      label: 'Experience',
      type: OpportunityFieldType.singleSelect,
      showOnCard: true,
      options: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
    ),
    OpportunityFieldDef(
      key: 'highlightPackages',
      label: 'Highlight Packages',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'liveProduction',
      label: 'Live Production',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'drone',
      label: 'Drone',
      type: OpportunityFieldType.yesNo,
      showOnCard: true,
    ),
    OpportunityFieldDef(
      key: 'price',
      label: 'Price',
      type: OpportunityFieldType.text,
      showOnCard: true,
    ),
  ];
}
