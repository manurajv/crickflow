import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/tournament/tournament_create_draft.dart';
import '../../data/models/tournament/tournament_setup_meta.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/services/storage_service.dart';
import '../../shared/providers/community_provider.dart';
import '../../shared/providers/providers.dart';

class TournamentCreateService {
  TournamentCreateService({
    required TournamentRepository tournamentRepository,
    required CommunityRepository communityRepository,
    required StorageService storageService,
  })  : _tournaments = tournamentRepository,
        _community = communityRepository,
        _storage = storageService;

  final TournamentRepository _tournaments;
  final CommunityRepository _community;
  final StorageService _storage;

  Future<String> submit({
    required TournamentCreateDraft draft,
    required String uid,
    required String ownerDisplayName,
    bool postOfficialsRequest = true,
    bool postTeamsRequest = true,
  }) async {
    var bannerUrl = draft.bannerUrl;
    var logoUrl = draft.logoUrl;

    if (draft.bannerLocalFile != null) {
      bannerUrl = await _storage.uploadTournamentBanner(
        draft.tournamentId,
        draft.bannerLocalFile!,
      );
    }
    if (draft.logoLocalFile != null) {
      logoUrl = await _storage.uploadTournamentLogo(
        draft.tournamentId,
        draft.logoLocalFile!,
      );
    }

    final tournament = draft.toTournamentModel(
      uid: uid,
      bannerUrl: bannerUrl,
      logoUrl: logoUrl,
    );

    final id = await _tournaments.createTournament(
      tournament: tournament,
      ownerDisplayName: ownerDisplayName,
    );

    final meta = draft.mergedSetup();
    final location = draft.location.copyWith(city: draft.city);

    if (postOfficialsRequest && draft.needOfficials) {
      await _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        title: 'Officials needed — ${draft.name.trim()}',
        body: _officialsPostBody(draft.name, meta),
        category: CommunityPostCategory.tournamentNeed,
        location: location,
      );
    }

    if (postTeamsRequest && draft.needMoreTeams) {
      await _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        title: 'Teams wanted — ${draft.name.trim()}',
        body: _teamsPostBody(draft.name, draft, meta),
        category: CommunityPostCategory.tournamentNeed,
        location: location,
      );
    }

    return id;
  }

  String _officialsPostBody(String name, TournamentSetupMeta meta) {
    final roles = meta.requiredOfficialRoles.map((r) => r.name).join(', ');
    return [
      'Tournament: $name',
      if (roles.isNotEmpty) 'Roles: $roles',
      if (meta.officialDays != null) 'Days: ${meta.officialDays}',
      if (meta.matchesPerDay != null) 'Matches/day: ${meta.matchesPerDay}',
      if (meta.budgetPerDay != null)
        'Budget/day: ${officialBudgetLabel(meta.budgetPerDay!)}',
      if (meta.budgetPerMatch != null)
        'Budget/match: ${officialBudgetLabel(meta.budgetPerMatch!)}',
      'Contact via: ${officialContactLabel(meta.officialContactMethod)}',
    ].join('\n');
  }

  String _teamsPostBody(
    String name,
    TournamentCreateDraft draft,
    TournamentSetupMeta meta,
  ) {
    return [
      'Tournament: $name',
      if (meta.totalTeams != null) 'Total teams: ${meta.totalTeams}',
      if (meta.teamsRequired != null) 'Teams needed: ${meta.teamsRequired}',
      if (draft.entryFeeText.isNotEmpty) 'Entry fee: ${draft.entryFeeText}',
      'Format: ${draft.format.name}',
      'Prize: ${_prizeLabel(meta.winningPrizeType)}',
      if (meta.additionalDetails.isNotEmpty) meta.additionalDetails,
    ].join('\n');
  }

  String _prizeLabel(WinningPrizeType type) => switch (type) {
        WinningPrizeType.cash => 'Cash',
        WinningPrizeType.trophies => 'Trophies',
        WinningPrizeType.both => 'Cash & Trophies',
      };
}

final tournamentCreateServiceProvider = Provider((ref) {
  return TournamentCreateService(
    tournamentRepository: ref.watch(tournamentRepositoryProvider),
    communityRepository: ref.watch(communityRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});
