import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';
import '../location_model.dart';

/// Extra tournament setup captured during the create wizard.
class TournamentSetupMeta extends Equatable {
  const TournamentSetupMeta({
    this.organizerName = '',
    this.organizerPhone = '',
    this.organizerEmail = '',
    this.category = TournamentCategory.open,
    this.cricketMatchType = CricketMatchType.limitedOvers,
    this.matchFormat = TournamentMatchFormat.limitedOvers,
    this.ballTypeOther = false,
    this.primaryGround = '',
    this.needMoreTeams = false,
    this.needOfficials = false,
    this.requiredOfficialRoles = const {},
    this.officialDays,
    this.matchesPerDay,
    this.sameBudgetForAll = true,
    this.budgetPerDay,
    this.budgetPerMatch,
    this.officialContactMethod = OfficialContactMethod.inAppMessage,
    this.teamLocation = const LocationModel(),
    this.totalTeams,
    this.teamsRequired,
    this.winningPrizeType = WinningPrizeType.both,
    this.matchesOn = TournamentMatchSchedule.allDays,
    this.matchTiming = TournamentDayNight.day,
    this.additionalDetails = '',
    this.informPreviousPlayers = false,
    this.postedLookingForTeams = false,
    this.postedLookingForOfficials = false,
  });

  final String organizerName;
  final String organizerPhone;
  final String organizerEmail;
  final TournamentCategory category;
  final CricketMatchType cricketMatchType;
  final TournamentMatchFormat matchFormat;
  final bool ballTypeOther;
  final String primaryGround;
  final bool needMoreTeams;
  final bool needOfficials;
  final Set<TournamentOfficialRole> requiredOfficialRoles;
  final String? officialDays;
  final String? matchesPerDay;
  final bool sameBudgetForAll;
  final OfficialBudgetBand? budgetPerDay;
  final OfficialBudgetBand? budgetPerMatch;
  final OfficialContactMethod officialContactMethod;
  final LocationModel teamLocation;
  final int? totalTeams;
  final int? teamsRequired;
  final WinningPrizeType winningPrizeType;
  final TournamentMatchSchedule matchesOn;
  final TournamentDayNight matchTiming;
  final String additionalDetails;
  final bool informPreviousPlayers;
  final bool postedLookingForTeams;
  final bool postedLookingForOfficials;

  factory TournamentSetupMeta.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TournamentSetupMeta();
    return TournamentSetupMeta(
      organizerName: map['organizerName'] as String? ?? '',
      organizerPhone: map['organizerPhone'] as String? ?? '',
      organizerEmail: map['organizerEmail'] as String? ?? '',
      category: TournamentCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TournamentCategory.open,
      ),
      matchFormat: TournamentMatchFormat.values.firstWhere(
        (e) => e.name == map['matchFormat'],
        orElse: () => TournamentMatchFormat.limitedOvers,
      ),
      cricketMatchType: _cricketMatchTypeFromMap(map),
      ballTypeOther: map['ballTypeOther'] as bool? ?? false,
      primaryGround: map['primaryGround'] as String? ?? '',
      needMoreTeams: map['needMoreTeams'] as bool? ?? false,
      needOfficials: map['needOfficials'] as bool? ?? false,
      requiredOfficialRoles: (map['requiredOfficialRoles'] as List? ?? [])
          .map(
            (e) => TournamentOfficialRole.values.firstWhere(
              (r) => r.name == e,
              orElse: () => TournamentOfficialRole.scorer,
            ),
          )
          .toSet(),
      officialDays: map['officialDays'] as String?,
      matchesPerDay: map['matchesPerDay'] as String?,
      sameBudgetForAll: map['sameBudgetForAll'] as bool? ?? true,
      budgetPerDay: _budgetFromName(map['budgetPerDay'] as String?),
      budgetPerMatch: _budgetFromName(map['budgetPerMatch'] as String?),
      officialContactMethod: OfficialContactMethod.values.firstWhere(
        (e) => e.name == map['officialContactMethod'],
        orElse: () => OfficialContactMethod.inAppMessage,
      ),
      teamLocation: LocationModel.fromMap(
        map['teamLocation'] as Map<String, dynamic>?,
      ),
      totalTeams: map['totalTeams'] as int?,
      teamsRequired: map['teamsRequired'] as int?,
      winningPrizeType: WinningPrizeType.values.firstWhere(
        (e) => e.name == map['winningPrizeType'],
        orElse: () => WinningPrizeType.both,
      ),
      matchesOn: TournamentMatchSchedule.values.firstWhere(
        (e) => e.name == map['matchesOn'],
        orElse: () => TournamentMatchSchedule.allDays,
      ),
      matchTiming: TournamentDayNight.values.firstWhere(
        (e) => e.name == map['matchTiming'],
        orElse: () => TournamentDayNight.day,
      ),
      additionalDetails: map['additionalDetails'] as String? ?? '',
      informPreviousPlayers: map['informPreviousPlayers'] as bool? ?? false,
      postedLookingForTeams: map['postedLookingForTeams'] as bool? ?? false,
      postedLookingForOfficials:
          map['postedLookingForOfficials'] as bool? ?? false,
    );
  }

  static OfficialBudgetBand? _budgetFromName(String? name) {
    if (name == null) return null;
    return OfficialBudgetBand.values.firstWhere(
      (e) => e.name == name,
      orElse: () => OfficialBudgetBand.dayNotDecided,
    );
  }

  static CricketMatchType _cricketMatchTypeFromMap(Map<String, dynamic> map) {
    final stored = map['cricketMatchType'] as String?;
    if (stored != null) {
      return CricketMatchType.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => CricketMatchType.limitedOvers,
      );
    }
    final legacy = map['matchFormat'] as String?;
    return switch (legacy) {
      'testMatch' => CricketMatchType.testMatch,
      'boxTurf' || 'pairCricket' => CricketMatchType.indoor,
      _ => CricketMatchType.limitedOvers,
    };
  }

  Map<String, dynamic> toMap() => {
        'organizerName': organizerName,
        'organizerPhone': organizerPhone,
        'organizerEmail': organizerEmail,
        'category': category.name,
        'cricketMatchType': cricketMatchType.name,
        'matchFormat': matchFormat.name,
        'ballTypeOther': ballTypeOther,
        'primaryGround': primaryGround,
        'needMoreTeams': needMoreTeams,
        'needOfficials': needOfficials,
        'requiredOfficialRoles':
            requiredOfficialRoles.map((e) => e.name).toList(),
        if (officialDays != null) 'officialDays': officialDays,
        if (matchesPerDay != null) 'matchesPerDay': matchesPerDay,
        'sameBudgetForAll': sameBudgetForAll,
        if (budgetPerDay != null) 'budgetPerDay': budgetPerDay!.name,
        if (budgetPerMatch != null) 'budgetPerMatch': budgetPerMatch!.name,
        'officialContactMethod': officialContactMethod.name,
        'teamLocation': teamLocation.toMap(),
        if (totalTeams != null) 'totalTeams': totalTeams,
        if (teamsRequired != null) 'teamsRequired': teamsRequired,
        'winningPrizeType': winningPrizeType.name,
        'matchesOn': matchesOn.name,
        'matchTiming': matchTiming.name,
        'additionalDetails': additionalDetails,
        'informPreviousPlayers': informPreviousPlayers,
        'postedLookingForTeams': postedLookingForTeams,
        'postedLookingForOfficials': postedLookingForOfficials,
      };

  TournamentSetupMeta copyWith({
    String? organizerName,
    String? organizerPhone,
    String? organizerEmail,
    TournamentCategory? category,
    CricketMatchType? cricketMatchType,
    TournamentMatchFormat? matchFormat,
    bool? ballTypeOther,
    String? primaryGround,
    bool? needMoreTeams,
    bool? needOfficials,
    Set<TournamentOfficialRole>? requiredOfficialRoles,
    String? officialDays,
    String? matchesPerDay,
    bool? sameBudgetForAll,
    OfficialBudgetBand? budgetPerDay,
    OfficialBudgetBand? budgetPerMatch,
    OfficialContactMethod? officialContactMethod,
    LocationModel? teamLocation,
    int? totalTeams,
    int? teamsRequired,
    WinningPrizeType? winningPrizeType,
    TournamentMatchSchedule? matchesOn,
    TournamentDayNight? matchTiming,
    String? additionalDetails,
    bool? informPreviousPlayers,
    bool? postedLookingForTeams,
    bool? postedLookingForOfficials,
  }) {
    return TournamentSetupMeta(
      organizerName: organizerName ?? this.organizerName,
      organizerPhone: organizerPhone ?? this.organizerPhone,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      category: category ?? this.category,
      cricketMatchType: cricketMatchType ?? this.cricketMatchType,
      matchFormat: matchFormat ?? this.matchFormat,
      ballTypeOther: ballTypeOther ?? this.ballTypeOther,
      primaryGround: primaryGround ?? this.primaryGround,
      needMoreTeams: needMoreTeams ?? this.needMoreTeams,
      needOfficials: needOfficials ?? this.needOfficials,
      requiredOfficialRoles:
          requiredOfficialRoles ?? this.requiredOfficialRoles,
      officialDays: officialDays ?? this.officialDays,
      matchesPerDay: matchesPerDay ?? this.matchesPerDay,
      sameBudgetForAll: sameBudgetForAll ?? this.sameBudgetForAll,
      budgetPerDay: budgetPerDay ?? this.budgetPerDay,
      budgetPerMatch: budgetPerMatch ?? this.budgetPerMatch,
      officialContactMethod:
          officialContactMethod ?? this.officialContactMethod,
      teamLocation: teamLocation ?? this.teamLocation,
      totalTeams: totalTeams ?? this.totalTeams,
      teamsRequired: teamsRequired ?? this.teamsRequired,
      winningPrizeType: winningPrizeType ?? this.winningPrizeType,
      matchesOn: matchesOn ?? this.matchesOn,
      matchTiming: matchTiming ?? this.matchTiming,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      informPreviousPlayers:
          informPreviousPlayers ?? this.informPreviousPlayers,
      postedLookingForTeams:
          postedLookingForTeams ?? this.postedLookingForTeams,
      postedLookingForOfficials:
          postedLookingForOfficials ?? this.postedLookingForOfficials,
    );
  }

  @override
  List<Object?> get props => [category, matchFormat, needMoreTeams, needOfficials];
}

String tournamentCategoryLabel(TournamentCategory c) => switch (c) {
      TournamentCategory.open => 'OPEN',
      TournamentCategory.corporate => 'CORPORATE',
      TournamentCategory.community => 'COMMUNITY',
      TournamentCategory.school => 'SCHOOL',
      TournamentCategory.other => 'OTHER',
      TournamentCategory.series => 'SERIES',
      TournamentCategory.college => 'COLLEGE',
      TournamentCategory.university => 'UNIVERSITY',
    };

String tournamentMatchFormatLabel(TournamentMatchFormat f) => switch (f) {
      TournamentMatchFormat.limitedOvers => 'Limited Overs',
      TournamentMatchFormat.boxTurf => 'Box/Turf Cricket',
      TournamentMatchFormat.pairCricket => 'Pair Cricket',
      TournamentMatchFormat.testMatch => 'Test Match',
      TournamentMatchFormat.theHundred => 'The Hundred',
    };

String officialBudgetLabel(OfficialBudgetBand b) => switch (b) {
      OfficialBudgetBand.day500to1000 => '500 - 1000',
      OfficialBudgetBand.day1100to1500 => '1100 - 1500',
      OfficialBudgetBand.day1600to2000 => '1600 - 2000',
      OfficialBudgetBand.day2000plus => '2000+',
      OfficialBudgetBand.dayNotDecided => 'Not Decided',
      OfficialBudgetBand.match100to500 => '100 - 500',
      OfficialBudgetBand.match600to1000 => '600 - 1000',
      OfficialBudgetBand.match1100to1500 => '1100 - 1500',
      OfficialBudgetBand.match1500plus => '1500+',
      OfficialBudgetBand.matchNotDecided => 'Not Decided',
    };

String officialContactLabel(OfficialContactMethod m) => switch (m) {
      OfficialContactMethod.inAppMessage => 'CrickFlow DM',
      OfficialContactMethod.whatsApp => 'WhatsApp',
      OfficialContactMethod.phoneCall => 'Call',
    };
