import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/tournament/tournament_create_draft.dart';
import '../../data/models/tournament/tournament_setup_meta.dart';
import '../../core/constants/enums.dart';
import '../../data/models/location_model.dart';

class TournamentCreateDraftNotifier extends StateNotifier<TournamentCreateDraft> {
  TournamentCreateDraftNotifier() : super(TournamentCreateDraft.fresh());

  void reset() => state = TournamentCreateDraft.fresh();

  void seedFromProfile({
    required String displayName,
    String phone = '',
    String email = '',
    LocationModel? location,
  }) {
    state = state.copyWith(
      organizerName: displayName,
      organizerPhone: phone,
      organizerEmail: email,
      city: location?.city ?? state.city,
      location: location ?? state.location,
      setup: state.setup.copyWith(teamLocation: location ?? state.location),
    );
  }

  void updateDraft(TournamentCreateDraft draft) => state = draft;

  void patch(TournamentCreateDraft Function(TournamentCreateDraft) fn) {
    state = fn(state);
  }
}

final tournamentCreateDraftProvider =
    StateNotifierProvider<TournamentCreateDraftNotifier, TournamentCreateDraft>(
  (ref) => TournamentCreateDraftNotifier(),
);
