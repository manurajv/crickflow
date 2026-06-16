import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';

/// Location picker with search, GPS detect, and editable country/province/city fields.
class OnboardingLocationSection extends StatefulWidget {
  const OnboardingLocationSection({
    super.key,
    required this.initialLocation,
    required this.onLocationChanged,
    this.locationService,
    this.autoDetectOnInit = true,
  });

  final LocationModel initialLocation;
  final ValueChanged<LocationModel> onLocationChanged;
  final GoogleMapsLocationService? locationService;

  /// When true, attempts GPS on first frame (skipped if [initialLocation] is set).
  final bool autoDetectOnInit;

  @override
  State<OnboardingLocationSection> createState() =>
      _OnboardingLocationSectionState();
}

class _OnboardingLocationSectionState extends State<OnboardingLocationSection> {
  late final GoogleMapsLocationService _service;

  late final TextEditingController _searchController;
  late final TextEditingController _countryController;
  late final TextEditingController _provinceController;
  late final TextEditingController _cityController;

  bool _resolving = false;
  bool _userHasSetLocation = false;
  String? _statusMessage;
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _service = widget.locationService ?? GoogleMapsLocationService();
    _searchController = TextEditingController();
    _countryController =
        TextEditingController(text: widget.initialLocation.country);
    _provinceController =
        TextEditingController(text: widget.initialLocation.stateProvince);
    _cityController = TextEditingController(text: widget.initialLocation.city);
    _userHasSetLocation = !widget.initialLocation.isEmpty;

    if (widget.autoDetectOnInit && widget.initialLocation.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _detectCurrentLocation(userRequested: false),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  LocationModel get _currentLocation => LocationModel(
        country: _countryController.text.trim(),
        stateProvince: _provinceController.text.trim(),
        city: _cityController.text.trim(),
      );

  void _markUserEdited() {
    _userHasSetLocation = true;
  }

  void _emitLocation() {
    widget.onLocationChanged(_currentLocation);
  }

  void _onManualFieldChanged() {
    _markUserEdited();
    _emitLocation();
  }

  void _applyResolvedPlace(
    ResolvedPlace resolved, {
    required bool userRequested,
  }) {
    if (!userRequested && _userHasSetLocation) return;

    setState(() {
      _countryController.text = resolved.location.country;
      _provinceController.text = resolved.location.stateProvince;
      _cityController.text = resolved.location.city;
      _suggestions = [];
      _searchController.clear();
      _statusMessage = null;
    });
    _emitLocation();
  }

  void _showStatus(String message) {
    setState(() => _statusMessage = message);
  }

  Future<void> _detectCurrentLocation({required bool userRequested}) async {
    if (!userRequested && _userHasSetLocation) return;

    setState(() => _resolving = true);
    try {
      final access = await _service.ensureLocationPermission();
      if (!mounted) return;
      if (!userRequested && _userHasSetLocation) return;

      if (access != LocationAccessStatus.granted) {
        _showStatus(_service.messageForAccessStatus(access));
        return;
      }

      final coords = await _service.getCurrentCoords();
      if (!mounted) return;
      if (!userRequested && _userHasSetLocation) return;

      if (coords == null) {
        _showStatus('Could not read GPS position. Try again or search manually.');
        return;
      }

      final resolved = await _service.reverseGeocode(coords);
      if (!mounted) return;
      if (!userRequested && _userHasSetLocation) return;

      _applyResolvedPlace(resolved, userRequested: userRequested);
    } catch (e) {
      if (mounted) _showStatus('Location error: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await _service.searchPlaces(value);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _statusMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _suggestions = []);
          _showStatus('$e');
        }
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    _markUserEdited();
    FocusScope.of(context).unfocus();
    setState(() {
      _resolving = true;
      _suggestions = [];
      _searchController.text = suggestion.description;
    });
    try {
      final resolved = await _service.resolvePlace(suggestion.placeId);
      if (!mounted) return;
      _applyResolvedPlace(resolved, userRequested: true);
    } catch (e) {
      _showStatus('Could not load place: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened && mounted) {
      await Geolocator.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Location',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Search or use current location, then edit fields if needed (optional)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Material(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_statusMessage!.contains('permission') ||
                      _statusMessage!.contains('GPS') ||
                      _statusMessage!.contains('settings'))
                    TextButton(
                      onPressed: _openLocationSettings,
                      child: const Text('Settings'),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceSm),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search location',
            hintText: 'City, province, or country',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _resolving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Use current location',
                    onPressed: _resolving
                        ? null
                        : () => _detectCurrentLocation(userRequested: true),
                  ),
          ),
          onChanged: _onSearchChanged,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surfaceElevated,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(s.description, maxLines: 2),
                  onTap: () => _pickSuggestion(s),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _countryController,
          decoration: const InputDecoration(
            labelText: 'Country',
            prefixIcon: Icon(Icons.public_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onManualFieldChanged(),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        TextField(
          controller: _provinceController,
          decoration: const InputDecoration(
            labelText: 'Province / State',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onManualFieldChanged(),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _onManualFieldChanged(),
        ),
      ],
    );
  }
}
