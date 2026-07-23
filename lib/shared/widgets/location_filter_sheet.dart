import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../data/models/location_filter_selection.dart';
import '../../data/models/location_model.dart';
import '../../features/player_onboarding/presentation/widgets/onboarding_location_section.dart';
import '../providers/providers.dart';

/// Multi-location filter sheet (GPS / search) used by Community, Teams, etc.
Future<List<LocationFilterSelection>?> showLocationFilterSheet(
  BuildContext context, {
  required List<LocationFilterSelection> initial,
  String subtitle =
      'Search or use GPS, then add locations. Items matching any selection '
      'are shown. Clear city/province fields to broaden a filter.',
}) {
  return showModalBottomSheet<List<LocationFilterSelection>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => LocationFilterSheet(
      initial: initial,
      subtitle: subtitle,
    ),
  );
}

class LocationFilterSheet extends ConsumerStatefulWidget {
  const LocationFilterSheet({
    super.key,
    required this.initial,
    this.subtitle =
        'Search or use GPS, then add locations. Items matching any selection '
        'are shown. Clear city/province fields to broaden a filter.',
  });

  final List<LocationFilterSelection> initial;
  final String subtitle;

  @override
  ConsumerState<LocationFilterSheet> createState() =>
      _LocationFilterSheetState();
}

class _LocationFilterSheetState extends ConsumerState<LocationFilterSheet> {
  late List<LocationFilterSelection> _selected;
  LocationModel _draft = const LocationModel();
  int _pickerKey = 0;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.initial);
  }

  void _addCurrent() {
    final entry = LocationFilterSelection(
      country: _draft.country.trim(),
      stateProvince: _draft.stateProvince.trim(),
      district: _draft.district.trim(),
      city: _draft.city.trim(),
    );
    if (entry.isEmpty) return;
    if (_selected.contains(entry)) return;
    setState(() {
      _selected = [..._selected, entry];
      _draft = const LocationModel();
      _pickerKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        bottom + AppDimens.spaceMd,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter by location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            OnboardingLocationSection(
              key: ValueKey(_pickerKey),
              initialLocation: _draft,
              autoDetectOnInit: _draft.isEmpty,
              onLocationChanged: (loc) => setState(() => _draft = loc),
              locationService: ref.read(googleMapsLocationServiceProvider),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            OutlinedButton.icon(
              onPressed: _draft.isEmpty ? null : _addCurrent,
              icon: const Icon(Icons.add),
              label: const Text('Add to filter'),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.map((s) {
                  return InputChip(
                    label: Text(s.label),
                    onDeleted: () {
                      setState(() {
                        _selected = _selected.where((e) => e != s).toList();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selected = []);
                      Navigator.pop(context, <LocationFilterSelection>[]);
                    },
                    child: const Text('Clear filter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
