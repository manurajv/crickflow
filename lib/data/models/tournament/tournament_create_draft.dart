import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../location_model.dart';
import 'tournament_rules_model.dart';
import 'tournament_setup_meta.dart';
import '../tournament_model.dart';

enum TournamentCreateFlowStep { basic, officials, teams }

class TournamentCreateDraft extends Equatable {
  const TournamentCreateDraft({
    required this.tournamentId,
    this.name = '',
    this.city = '',
    this.ground = '',
    this.location = const LocationModel(country: AppConstants.defaultCountry),
    this.organizerName = '',
    this.organizerPhone = '',
    this.organizerEmail = '',
    this.startDate,
    this.endDate,
    this.category = TournamentCategory.open,
    this.ballType = CricketBallType.tennis,
    this.ballTypeOther = false,
    this.pitchType = PitchType.cement,
    this.matchFormat = TournamentMatchFormat.limitedOvers,
    this.format = TournamentFormat.league,
    this.needMoreTeams = false,
    this.needOfficials = false,
    this.setup = const TournamentSetupMeta(),
    this.entryFeeText = '',
    this.totalTeamsText = '',
    this.teamsRequiredText = '',
    this.bannerLocalFile,
    this.logoLocalFile,
    this.bannerUrl,
    this.logoUrl,
  });

  final String tournamentId;
  final String name;
  final String city;
  final String ground;
  final LocationModel location;
  final String organizerName;
  final String organizerPhone;
  final String organizerEmail;
  final DateTime? startDate;
  final DateTime? endDate;
  final TournamentCategory category;
  final CricketBallType ballType;
  final bool ballTypeOther;
  final PitchType pitchType;
  final TournamentMatchFormat matchFormat;
  final TournamentFormat format;
  final bool needMoreTeams;
  final bool needOfficials;
  final TournamentSetupMeta setup;
  final String entryFeeText;
  final String totalTeamsText;
  final String teamsRequiredText;
  final File? bannerLocalFile;
  final File? logoLocalFile;
  final String? bannerUrl;
  final String? logoUrl;

  List<TournamentCreateFlowStep> get activeSteps {
    final steps = [TournamentCreateFlowStep.basic];
    if (needOfficials) steps.add(TournamentCreateFlowStep.officials);
    if (needMoreTeams) steps.add(TournamentCreateFlowStep.teams);
    return steps;
  }

  List<String> get stepLabels => activeSteps
      .map(
        (s) => switch (s) {
          TournamentCreateFlowStep.basic => 'Details',
          TournamentCreateFlowStep.officials => 'Officials',
          TournamentCreateFlowStep.teams => 'Teams',
        },
      )
      .toList();

  bool get canProceedFromBasic =>
      name.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      ground.trim().isNotEmpty &&
      organizerName.trim().isNotEmpty &&
      organizerPhone.trim().isNotEmpty &&
      startDate != null &&
      endDate != null;

  TournamentCreateDraft copyWith({
    String? name,
    String? city,
    String? ground,
    LocationModel? location,
    String? organizerName,
    String? organizerPhone,
    String? organizerEmail,
    DateTime? startDate,
    DateTime? endDate,
    TournamentCategory? category,
    CricketBallType? ballType,
    bool? ballTypeOther,
    PitchType? pitchType,
    TournamentMatchFormat? matchFormat,
    TournamentFormat? format,
    bool? needMoreTeams,
    bool? needOfficials,
    TournamentSetupMeta? setup,
    String? entryFeeText,
    String? totalTeamsText,
    String? teamsRequiredText,
    File? bannerLocalFile,
    File? logoLocalFile,
    String? bannerUrl,
    String? logoUrl,
    bool clearBannerLocal = false,
    bool clearLogoLocal = false,
  }) {
    return TournamentCreateDraft(
      tournamentId: tournamentId,
      name: name ?? this.name,
      city: city ?? this.city,
      ground: ground ?? this.ground,
      location: location ?? this.location,
      organizerName: organizerName ?? this.organizerName,
      organizerPhone: organizerPhone ?? this.organizerPhone,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      ballType: ballType ?? this.ballType,
      ballTypeOther: ballTypeOther ?? this.ballTypeOther,
      pitchType: pitchType ?? this.pitchType,
      matchFormat: matchFormat ?? this.matchFormat,
      format: format ?? this.format,
      needMoreTeams: needMoreTeams ?? this.needMoreTeams,
      needOfficials: needOfficials ?? this.needOfficials,
      setup: setup ?? this.setup,
      entryFeeText: entryFeeText ?? this.entryFeeText,
      totalTeamsText: totalTeamsText ?? this.totalTeamsText,
      teamsRequiredText: teamsRequiredText ?? this.teamsRequiredText,
      bannerLocalFile:
          clearBannerLocal ? null : bannerLocalFile ?? this.bannerLocalFile,
      logoLocalFile: clearLogoLocal ? null : logoLocalFile ?? this.logoLocalFile,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }

  TournamentSetupMeta mergedSetup() {
    return setup.copyWith(
      organizerName: organizerName,
      organizerPhone: organizerPhone,
      organizerEmail: organizerEmail,
      category: category,
      matchFormat: matchFormat,
      ballTypeOther: ballTypeOther,
      primaryGround: ground,
      needMoreTeams: needMoreTeams,
      needOfficials: needOfficials,
      teamLocation: location.copyWith(city: city),
      totalTeams: int.tryParse(totalTeamsText),
      teamsRequired: int.tryParse(teamsRequiredText),
    );
  }

  TournamentModel toTournamentModel({
    required String uid,
    String? bannerUrl,
    String? logoUrl,
  }) {
    final meta = mergedSetup();
    final entryFee = double.tryParse(entryFeeText.replaceAll(',', ''));
    final rules = TournamentRulesModel(
      ballType: ballTypeOther ? CricketBallType.indoor : ballType,
      pitchType: pitchType,
    ).toMatchRules();

    return TournamentModel(
      id: tournamentId,
      name: name.trim(),
      format: format,
      status: TournamentStatus.draft,
      location: location.copyWith(city: city.trim()),
      grounds: ground.trim().isEmpty ? const [] : [ground.trim()],
      startDate: startDate,
      endDate: endDate,
      createdBy: uid,
      organizerId: uid,
      description: meta.additionalDetails.trim(),
      entryFee: entryFee,
      winningPrize: _winningPrizeLabel(meta.winningPrizeType),
      ballType: ballTypeOther ? CricketBallType.indoor : ballType,
      pitchType: pitchType,
      defaultRules: TournamentRulesModel(
        ballType: ballTypeOther ? CricketBallType.indoor : ballType,
        pitchType: pitchType,
        totalOvers: rules.totalOvers,
        ballsPerOver: rules.ballsPerOver,
      ),
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      setupMeta: meta,
    );
  }

  static String _winningPrizeLabel(WinningPrizeType type) => switch (type) {
        WinningPrizeType.cash => 'Cash',
        WinningPrizeType.trophies => 'Trophies',
        WinningPrizeType.both => 'Cash & Trophies',
      };

  factory TournamentCreateDraft.fresh() {
    return TournamentCreateDraft(tournamentId: const Uuid().v4());
  }

  @override
  List<Object?> get props => [tournamentId, name, city, needOfficials, needMoreTeams];
}
