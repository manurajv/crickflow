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
    this.budgetPerDayByRole = const {},
    this.budgetPerMatchByRole = const {},
    this.budgetCurrencyCode = '',
    this.officialContactMethods = const {OfficialContactMethod.inAppMessage},
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
  /// Per-role day bands when [sameBudgetForAll] is false.
  final Map<TournamentOfficialRole, OfficialBudgetBand> budgetPerDayByRole;
  /// Per-role match bands when [sameBudgetForAll] is false.
  final Map<TournamentOfficialRole, OfficialBudgetBand> budgetPerMatchByRole;
  /// ISO currency code derived from tournament country (e.g. LKR, INR).
  final String budgetCurrencyCode;
  /// One or more ways officials may contact the organizer (never includes [hide]).
  final Set<OfficialContactMethod> officialContactMethods;
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

  OfficialBudgetBand? dayBudgetFor(TournamentOfficialRole role) {
    if (sameBudgetForAll) return budgetPerDay;
    return budgetPerDayByRole[role];
  }

  OfficialBudgetBand? matchBudgetFor(TournamentOfficialRole role) {
    if (sameBudgetForAll) return budgetPerMatch;
    return budgetPerMatchByRole[role];
  }

  /// First selected method — for legacy single-value consumers.
  OfficialContactMethod get officialContactMethod {
    final methods = officialContactMethods
        .where((m) => m != OfficialContactMethod.hide);
    if (methods.isEmpty) return OfficialContactMethod.inAppMessage;
    return methods.first;
  }

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
      budgetPerDayByRole: _budgetMapFrom(map['budgetPerDayByRole']),
      budgetPerMatchByRole: _budgetMapFrom(map['budgetPerMatchByRole']),
      budgetCurrencyCode: map['budgetCurrencyCode'] as String? ?? '',
      officialContactMethods: _contactMethodsFrom(map),
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
    if (name == null || name.isEmpty) return null;
    for (final e in OfficialBudgetBand.values) {
      if (e.name == name) return e;
    }
    return null;
  }

  static Map<TournamentOfficialRole, OfficialBudgetBand> _budgetMapFrom(
    dynamic raw,
  ) {
    if (raw is! Map) return const {};
    final out = <TournamentOfficialRole, OfficialBudgetBand>{};
    for (final entry in raw.entries) {
      TournamentOfficialRole? role;
      for (final r in TournamentOfficialRole.values) {
        if (r.name == entry.key.toString()) {
          role = r;
          break;
        }
      }
      final band = _budgetFromName(entry.value?.toString());
      if (role != null && band != null) {
        out[role] = band;
      }
    }
    return out;
  }

  static OfficialContactMethod? _contactMethodFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final e in OfficialContactMethod.values) {
      if (e.name == name) return e;
    }
    return null;
  }

  static Set<OfficialContactMethod> _contactMethodsFrom(
    Map<String, dynamic> map,
  ) {
    final rawList = map['officialContactMethods'];
    if (rawList is List && rawList.isNotEmpty) {
      final parsed = rawList
          .map((e) => _contactMethodFromName(e?.toString()))
          .whereType<OfficialContactMethod>()
          .where((m) => m != OfficialContactMethod.hide)
          .toSet();
      if (parsed.isNotEmpty) return parsed;
    }
    final legacy = _contactMethodFromName(
      map['officialContactMethod'] as String?,
    );
    if (legacy != null && legacy != OfficialContactMethod.hide) {
      return {legacy};
    }
    return const {OfficialContactMethod.inAppMessage};
  }

  static Map<String, String> _budgetMapTo(
    Map<TournamentOfficialRole, OfficialBudgetBand> map,
  ) =>
      {
        for (final e in map.entries) e.key.name: e.value.name,
      };

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
        if (budgetPerDayByRole.isNotEmpty)
          'budgetPerDayByRole': _budgetMapTo(budgetPerDayByRole),
        if (budgetPerMatchByRole.isNotEmpty)
          'budgetPerMatchByRole': _budgetMapTo(budgetPerMatchByRole),
        if (budgetCurrencyCode.isNotEmpty)
          'budgetCurrencyCode': budgetCurrencyCode,
        'officialContactMethods': officialContactMethods
            .where((m) => m != OfficialContactMethod.hide)
            .map((e) => e.name)
            .toList(),
        // Legacy single field for older clients / rules.
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
    Map<TournamentOfficialRole, OfficialBudgetBand>? budgetPerDayByRole,
    Map<TournamentOfficialRole, OfficialBudgetBand>? budgetPerMatchByRole,
    String? budgetCurrencyCode,
    Set<OfficialContactMethod>? officialContactMethods,
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
    bool clearBudgetPerDay = false,
    bool clearBudgetPerMatch = false,
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
      budgetPerDay:
          clearBudgetPerDay ? null : (budgetPerDay ?? this.budgetPerDay),
      budgetPerMatch:
          clearBudgetPerMatch ? null : (budgetPerMatch ?? this.budgetPerMatch),
      budgetPerDayByRole: budgetPerDayByRole ?? this.budgetPerDayByRole,
      budgetPerMatchByRole: budgetPerMatchByRole ?? this.budgetPerMatchByRole,
      budgetCurrencyCode: budgetCurrencyCode ?? this.budgetCurrencyCode,
      officialContactMethods: () {
        if (officialContactMethods != null) {
          return officialContactMethods
              .where((m) => m != OfficialContactMethod.hide)
              .toSet();
        }
        if (officialContactMethod != null &&
            officialContactMethod != OfficialContactMethod.hide) {
          return {officialContactMethod};
        }
        return this.officialContactMethods;
      }(),
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
  List<Object?> get props => [
        category,
        matchFormat,
        needMoreTeams,
        needOfficials,
        sameBudgetForAll,
        budgetPerDay,
        budgetPerMatch,
        budgetPerDayByRole,
        budgetPerMatchByRole,
        budgetCurrencyCode,
        officialContactMethods,
      ];
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

String officialRoleShortLabel(TournamentOfficialRole role) => switch (role) {
      TournamentOfficialRole.umpire => 'Umpire',
      TournamentOfficialRole.scorer => 'Scorer',
      TournamentOfficialRole.streamer => 'Live Streamer',
      TournamentOfficialRole.commentator => 'Commentator',
      TournamentOfficialRole.photographer => 'Photographer',
      TournamentOfficialRole.videographer => 'Videographer',
    };

/// Human-readable budget lines for community / overview (with optional currency).
List<String> officialBudgetSummaryLines(
  TournamentSetupMeta meta, {
  String? currencyCode,
}) {
  final code = (currencyCode ?? meta.budgetCurrencyCode).trim();
  String withCurrency(String label) =>
      code.isEmpty ? label : '$label $code';

  if (meta.sameBudgetForAll) {
    final lines = <String>[];
    if (meta.budgetPerDay != null) {
      lines.add(
        'Budget/day: ${withCurrency(officialBudgetLabel(meta.budgetPerDay!))}',
      );
    }
    if (meta.budgetPerMatch != null) {
      lines.add(
        'Budget/match: ${withCurrency(officialBudgetLabel(meta.budgetPerMatch!))}',
      );
    }
    return lines;
  }

  final roles = meta.requiredOfficialRoles.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final lines = <String>[];
  for (final role in roles) {
    final day = meta.budgetPerDayByRole[role];
    final match = meta.budgetPerMatchByRole[role];
    if (day == null && match == null) continue;
    final parts = <String>[];
    if (day != null) {
      parts.add('${withCurrency(officialBudgetLabel(day))}/day');
    }
    if (match != null) {
      parts.add('${withCurrency(officialBudgetLabel(match))}/match');
    }
    lines.add('${officialRoleShortLabel(role)}: ${parts.join(' · ')}');
  }
  return lines;
}

String officialContactLabel(OfficialContactMethod m) => switch (m) {
      OfficialContactMethod.inAppMessage => 'CrickFlow DM',
      OfficialContactMethod.whatsApp => 'WhatsApp',
      OfficialContactMethod.phoneCall => 'Call',
      OfficialContactMethod.email => 'Email',
      OfficialContactMethod.hide => 'Hide contact',
    };

/// Contact chips offered in tournament create (excludes legacy hide).
const selectableOfficialContactMethods = <OfficialContactMethod>[
  OfficialContactMethod.inAppMessage,
  OfficialContactMethod.whatsApp,
  OfficialContactMethod.phoneCall,
  OfficialContactMethod.email,
];
