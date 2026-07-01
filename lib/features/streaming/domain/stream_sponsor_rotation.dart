import 'dart:async';

import '../../../data/models/tournament/tournament_sponsor_model.dart';

/// Rotates tournament sponsor names for the broadcast overlay banner.
class StreamSponsorRotation {
  StreamSponsorRotation({
    required List<TournamentSponsorModel> sponsors,
    required void Function(String name, String? logoUrl) onChanged,
    this.interval = const Duration(seconds: 15),
  })  : _sponsors = List<TournamentSponsorModel>.from(sponsors)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        _onChanged = onChanged,
        _index = 0 {
    if (_sponsors.isNotEmpty) {
      _emit();
    }
    if (_sponsors.length > 1) {
      _timer = Timer.periodic(interval, (_) {
        _index = (_index + 1) % _sponsors.length;
        _emit();
      });
    }
  }

  final List<TournamentSponsorModel> _sponsors;
  final void Function(String name, String? logoUrl) _onChanged;
  final Duration interval;
  Timer? _timer;
  int _index;

  void _emit() {
    final sponsor = _sponsors[_index];
    _onChanged(sponsor.name, sponsor.logoUrl);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
