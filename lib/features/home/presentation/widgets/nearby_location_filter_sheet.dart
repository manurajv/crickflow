import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';
import '../../providers/nearby_anchor_location_provider.dart';

/// Home nearby location filter — search a city to set state/province + country.
Future<LocationModel?> showNearbyLocationFilterSheet(
  BuildContext context, {
  required LocationModel initial,
  required Future<LocationModel?> Function() onUseCurrentLocation,
  required GoogleMapsLocationService locationService,
}) {
  return showModalBottomSheet<LocationModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _NearbyLocationFilterSheet(
      initial: initial,
      onUseCurrentLocation: onUseCurrentLocation,
      locationService: locationService,
    ),
  );
}

class _NearbyLocationFilterSheet extends StatefulWidget {
  const _NearbyLocationFilterSheet({
    required this.initial,
    required this.onUseCurrentLocation,
    required this.locationService,
  });

  final LocationModel initial;
  final Future<LocationModel?> Function() onUseCurrentLocation;
  final GoogleMapsLocationService locationService;

  @override
  State<_NearbyLocationFilterSheet> createState() =>
      _NearbyLocationFilterSheetState();
}

class _NearbyLocationFilterSheetState extends State<_NearbyLocationFilterSheet> {
  late TextEditingController _search;
  late TextEditingController _country;
  late TextEditingController _state;
  var _locating = false;
  var _resolvingPlace = false;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final region = nearbyRegionFilter(widget.initial);
    final label = nearbyRegionLabel(widget.initial);
    _search = TextEditingController(
      text: label.isNotEmpty
          ? label
          : widget.initial.displayLabel.trim(),
    );
    _country = TextEditingController(text: region.country);
    _state = TextEditingController(text: region.stateProvince);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _country.dispose();
    _state.dispose();
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

  void _applyLocation(LocationModel loc) {
    final state = loc.stateProvince.trim().isNotEmpty
        ? loc.stateProvince.trim()
        : (loc.district.trim().isNotEmpty
            ? loc.district.trim()
            : loc.city.trim());
    final country = loc.country.trim();
    _country.text = country;
    _state.text = state;
    final label = [
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');
    _search.text = label.isNotEmpty
        ? label
        : (loc.displayLabel.isNotEmpty ? loc.displayLabel : _search.text);
    _suggestions = [];
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
        _applyLocation(loc);
        if (_state.text.trim().isEmpty) {
          _statusMessage =
              'Could not determine state or province. Enter it below.';
        }
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
      setState(() {
        _applyLocation(resolved.location);
        if (_state.text.trim().isEmpty) {
          _statusMessage =
              'Could not determine state or province. Enter it below.';
        }
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
    final fromFields = LocationModel(
      country: _country.text.trim(),
      stateProvince: _state.text.trim(),
    );
    Navigator.pop(
      context,
      fromFields.isEmpty ? const LocationModel() : fromFields,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

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
                'Location',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Search a city to set the state or province. Matches are shown for that region.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                    : const Icon(Icons.my_location, size: 18),
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
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _search.clear();
                          _country.clear();
                          _state.clear();
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
                      onPressed: _resolvingPlace ? null : _apply,
                      child: const Text('Apply'),
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
