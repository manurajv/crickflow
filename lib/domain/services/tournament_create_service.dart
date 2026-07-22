import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/community_post_model.dart';
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
    String? authorPhotoUrl,
    String? authorPlayerId,
    bool authorVerified = false,
    bool postOfficialsRequest = true,
    bool postTeamsRequest = true,
  }) async {
    var bannerUrl = draft.bannerUrl;
    var logoUrl = draft.logoUrl;
    var thumbnailUrl = draft.thumbnailUrl;

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
    if (draft.thumbnailLocalFile != null) {
      thumbnailUrl = await _storage.uploadTournamentThumbnail(
        draft.tournamentId,
        draft.thumbnailLocalFile!,
      );
    }
    thumbnailUrl ??= bannerUrl;

    final tournament = draft.toTournamentModel(
      uid: uid,
      bannerUrl: bannerUrl,
      logoUrl: logoUrl,
      thumbnailUrl: thumbnailUrl,
      thumbnailAspect: draft.thumbnailAspect,
    );

    final id = await _tournaments.createTournament(
      tournament: tournament,
      ownerDisplayName: ownerDisplayName,
    );

    final meta = draft.mergedSetup();
    final location = draft.location.copyWith(city: draft.city);
    final snapshot = _buildSnapshot(
      tournamentId: id,
      draft: draft,
      meta: meta,
      ownerDisplayName: ownerDisplayName,
      thumbnailUrl: thumbnailUrl,
      organizerUserId: uid,
    );

    if (postOfficialsRequest && draft.needOfficials) {
      await _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        authorPhotoUrl: authorPhotoUrl,
        authorPlayerId: authorPlayerId,
        authorVerified: authorVerified,
        title: 'Officials needed',
        body: _officialsPostBody(meta),
        category: CommunityPostCategory.tournamentNeed,
        postKind: CommunityPostKind.tournament,
        location: location,
        tournamentId: id,
        tournamentSnapshot: snapshot,
      );
    }

    if (postTeamsRequest && draft.needMoreTeams) {
      await _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        authorPhotoUrl: authorPhotoUrl,
        authorPlayerId: authorPlayerId,
        authorVerified: authorVerified,
        title: 'Teams wanted',
        body: _teamsPostBody(draft, meta),
        category: CommunityPostCategory.tournamentNeed,
        postKind: CommunityPostKind.tournament,
        location: location,
        tournamentId: id,
        tournamentSnapshot: snapshot,
      );
    }

    return id;
  }

  CommunityTournamentSnapshot _buildSnapshot({
    required String tournamentId,
    required TournamentCreateDraft draft,
    required TournamentSetupMeta meta,
    required String ownerDisplayName,
    String? thumbnailUrl,
    required String organizerUserId,
  }) {
    final visibility = _contactVisibility(meta.officialContactMethod);
    final phone = meta.organizerPhone.isNotEmpty
        ? meta.organizerPhone
        : draft.organizerPhone;
    final email = meta.organizerEmail.isNotEmpty
        ? meta.organizerEmail
        : draft.organizerEmail;

    final grounds = <String>[
      ...draft.grounds.map((g) => g.trim()).where((g) => g.isNotEmpty),
    ];
    final primary = meta.primaryGround.trim();
    if (primary.isNotEmpty &&
        !grounds.any((g) => g.toLowerCase() == primary.toLowerCase())) {
      grounds.insert(0, primary);
    }
    final groundsLabel = grounds.join(' · ');
    final cityLabel = draft.location.copyWith(city: draft.city).displayLabel;

    return CommunityTournamentSnapshot(
      tournamentId: tournamentId,
      name: draft.name.trim(),
      organizer: meta.organizerName.isNotEmpty
          ? meta.organizerName
          : (draft.organizerName.isNotEmpty
              ? draft.organizerName
              : ownerDisplayName),
      thumbnailUrl: thumbnailUrl,
      thumbnailAspect: draft.thumbnailAspect,
      locationLabel: cityLabel,
      groundsLabel: groundsLabel,
      grounds: grounds,
      startDate: draft.startDate,
      endDate: draft.endDate,
      entryFee: draft.entryFeeText.isNotEmpty ? draft.entryFeeText : null,
      budgetPerDayLabel: meta.budgetPerDay != null
          ? officialBudgetLabel(meta.budgetPerDay!)
          : '',
      budgetPerMatchLabel: meta.budgetPerMatch != null
          ? officialBudgetLabel(meta.budgetPerMatch!)
          : '',
      ballType: draft.ballTypeOther ? 'Other' : draft.ballType.name,
      matchFormat: tournamentMatchFormatLabel(meta.matchFormat),
      formatLabel: _tournamentTypeLabel(draft.format),
      teamCount: meta.totalTeams ?? meta.teamsRequired,
      registrationStatus: draft.needMoreTeams ? 'Open' : '',
      contactVisibility: visibility,
      contactPhone: visibility == CommunityContactVisibility.phone ? phone : '',
      contactWhatsApp:
          visibility == CommunityContactVisibility.whatsapp ? phone : '',
      contactEmail: visibility == CommunityContactVisibility.email ? email : '',
      organizerUserId: organizerUserId,
    );
  }

  CommunityContactVisibility _contactVisibility(OfficialContactMethod m) {
    return switch (m) {
      OfficialContactMethod.phoneCall => CommunityContactVisibility.phone,
      OfficialContactMethod.whatsApp => CommunityContactVisibility.whatsapp,
      OfficialContactMethod.email => CommunityContactVisibility.email,
      OfficialContactMethod.hide => CommunityContactVisibility.hide,
      OfficialContactMethod.inAppMessage =>
        CommunityContactVisibility.crickflowDm,
    };
  }

  String _tournamentTypeLabel(TournamentFormat format) => switch (format) {
        TournamentFormat.league => 'League',
        TournamentFormat.knockout => 'Knockout',
        TournamentFormat.leagueKnockout => 'League Knockout',
        TournamentFormat.custom => 'Custom',
      };

  /// One short line — details live on the tournament card.
  String _officialsPostBody(TournamentSetupMeta meta) {
    final roles = meta.requiredOfficialRoles.map((r) => r.name).join(', ');
    if (roles.isNotEmpty) return 'Looking for: $roles';
    return '';
  }

  String _teamsPostBody(
    TournamentCreateDraft draft,
    TournamentSetupMeta meta,
  ) {
    final needed = meta.teamsRequired;
    if (needed != null && needed > 0) {
      return 'Need $needed more team${needed == 1 ? '' : 's'}';
    }
    if (meta.additionalDetails.trim().isNotEmpty) {
      final t = meta.additionalDetails.trim();
      return t.length > 120 ? '${t.substring(0, 117)}…' : t;
    }
    return '';
  }
}

final tournamentCreateServiceProvider = Provider((ref) {
  return TournamentCreateService(
    tournamentRepository: ref.watch(tournamentRepositoryProvider),
    communityRepository: ref.watch(communityRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});
