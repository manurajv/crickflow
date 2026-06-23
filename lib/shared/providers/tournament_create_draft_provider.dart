import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/tournament/tournament_create_draft.dart';
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
    final city = location?.city.isNotEmpty == true ? location!.city : state.city;
    state = state.copyWith(
      organizerName: displayName,
      organizerPhone: phone,
      organizerEmail: email,
      city: city,
      location: location != null
          ? location.copyWith(city: city.isNotEmpty ? city : location.city)
          : state.location,
      setup: state.setup.copyWith(
        organizerName: displayName,
        organizerPhone: phone,
        organizerEmail: email,
        teamLocation: location ?? state.location,
      ),
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
