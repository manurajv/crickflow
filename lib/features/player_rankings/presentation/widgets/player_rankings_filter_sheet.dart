import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';
import '../../../../domain/services/player_rankings/player_rankings_models.dart';

Future<PlayerRankingsFilter?> showPlayerRankingsFilterSheet(
  BuildContext context, {
  required PlayerRankingsFilter initial,
  required Future<LocationModel?> Function() onUseCurrentLocation,
  required GoogleMapsLocationService locationService,
}) {
  return showModalBottomSheet<PlayerRankingsFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PlayerRankingsFilterSheet(
      initial: initial,
      onUseCurrentLocation: onUseCurrentLocation,
      locationService: locationService,
    ),
  );
}

class _PlayerRankingsFilterSheet extends StatefulWidget {
  const _PlayerRankingsFilterSheet({
    required this.initial,
    required this.onUseCurrentLocation,
    required this.locationService,
  });

  final PlayerRankingsFilter initial;
  final Future<LocationModel?> Function() onUseCurrentLocation;
  final GoogleMapsLocationService locationService;

  @override
  State<_PlayerRankingsFilterSheet> createState() =>
      _PlayerRankingsFilterSheetState();
}

class _PlayerRankingsFilterSheetState extends State<_PlayerRankingsFilterSheet> {
  late int? _year;
  late PlayerRankingsOversFilter _overs;
  late TextEditingController _search;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  var _locating = false;
  var _resolvingPlace = false;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _overs = widget.initial.overs;
    final initialLabel = widget.initial.location.displayLabel.trim();
    _search = TextEditingController(text: initialLabel);
    _country = TextEditingController(text: widget.initial.location.country);
    _state = TextEditingController(text: widget.initial.location.stateProvince);
    _city = TextEditingController(text: widget.initial.location.city);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _country.dispose();
    _state.dispose();
    _city.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String label, {
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final cf = context.cf;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cf.surfaceElevated,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cf.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cf.border),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    setState(() {
      _search.clear();
      _suggestions = [];
      _statusMessage = null;
    });
  }

  Future<void> _useCurrentLocation() async {
    _debounce?.cancel();
    setState(() {
      _locating = true;
      _statusMessage = null;
      _suggestions = [];
    });
    try {
      final loc = await widget.onUseCurrentLocation();
      if (!mounted) return;
      if (loc == null) {
        setState(() {
          _statusMessage =
              'Could not detect location. Enable GPS and try again.';
        });
        return;
      }
      setState(() {
        _country.text = loc.country;
        _state.text = loc.stateProvince;
        _city.text = loc.city;
        _search.text = loc.displayLabel.isNotEmpty
            ? loc.displayLabel
            : [
                loc.city,
                loc.stateProvince,
                loc.country,
              ].where((e) => e.trim().isNotEmpty).join(', ');
        _suggestions = [];
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onCitySearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await widget.locationService.searchCities(query);
        if (!mounted) return;
        if (_search.text.trim() != query) return;
        setState(() {
          _suggestions = results;
          _statusMessage = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _statusMessage = '$e';
        });
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    setState(() {
      _resolvingPlace = true;
      _suggestions = [];
      _search.text = suggestion.description;
      _statusMessage = null;
    });
    try {
      final resolved = await widget.locationService.resolvePlace(
        suggestion.placeId,
        fallbackDescription: suggestion.description,
      );
      if (!mounted) return;
      final loc = resolved.location;
      final address = loc.displayLabel.isNotEmpty
          ? loc.displayLabel
          : suggestion.description;
      setState(() {
        _country.text = loc.country;
        _state.text = loc.stateProvince;
        _city.text = loc.city.isNotEmpty
            ? loc.city
            : (loc.district.isNotEmpty ? loc.district : loc.placeName);
        _search.text = address;
        _suggestions = [];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not load place: $e');
      }
    } finally {
      if (mounted) setState(() => _resolvingPlace = false);
    }
  }

  void _apply() {
    final location = LocationModel(
      country: _country.text.trim(),
      stateProvince: _state.text.trim(),
      city: _city.text.trim(),
    );
    Navigator.pop(
      context,
      widget.initial.copyWith(
        year: _year,
        clearYear: _year == null,
        overs: _overs,
        location: location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final years = playerRankingsYearOptions();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          0,
          AppDimens.spaceLg,
          AppDimens.spaceLg + bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<int?>(
                key: ValueKey(_year),
                initialValue: _year,
                decoration: _fieldDecoration('Year'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Time'),
                  ),
                  for (final y in years)
                    DropdownMenuItem<int?>(
                      value: y,
                      child: Text('$y'),
                    ),
                ],
                onChanged: (value) => setState(() => _year = value),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              _SectionLabel('Overs'),
              const SizedBox(height: AppDimens.spaceXs),
              Wrap(
                spacing: AppDimens.spaceXs,
                runSpacing: AppDimens.spaceXs,
                children: [
                  for (final o in PlayerRankingsOversFilter.uiValues)
                    ChoiceChip(
                      label: Text(o.title),
                      selected: _overs == o,
                      onSelected: (_) => setState(() => _overs = o),
                      selectedColor: cf.accent.withValues(alpha: 0.15),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              _SectionLabel('Location'),
              const SizedBox(height: AppDimens.spaceSm),
              ListenableBuilder(
                listenable: _search,
                builder: (context, _) {
                  return TextField(
                    controller: _search,
                    decoration: _fieldDecoration(
                      'Search city',
                      prefixIcon: _resolvingPlace
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      suffixIcon: _search.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear',
                              onPressed: _clearSearch,
                              icon: Icon(
                                Icons.clear,
                                size: 20,
                                color: cf.textSecondary,
                              ),
                            )
                          : null,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: _onCitySearchChanged,
                  );
                },
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceXs),
                Material(
                  color: cf.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length.clamp(0, 6),
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: cf.border.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final s = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.location_city_outlined,
                          color: cf.textSecondary,
                          size: 20,
                        ),
                        title: Text(
                          s.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _pickSuggestion(s),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined, size: 18),
                label: Text(
                  _locating ? 'Detecting…' : 'Use current location',
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  _statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _country,
                decoration: _fieldDecoration('Country'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _state,
                decoration: _fieldDecoration('State / Province'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _city,
                decoration: _fieldDecoration('City'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _year = null;
                          _overs = PlayerRankingsOversFilter.all;
                          _search.clear();
                          _country.clear();
                          _state.clear();
                          _city.clear();
                          _suggestions = [];
                          _statusMessage = null;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.cf.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
    );
  }
}
