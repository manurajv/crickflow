import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_model.dart';
import '../../../data/services/google_maps_location_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import 'models/ground_pick_result.dart';
import 'widgets/ground_map_web_view.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../core/theme/cf_colors.dart';

/// Full-screen map to search and pin a ground location.
class GroundMapPickerScreen extends ConsumerStatefulWidget {
  const GroundMapPickerScreen({
    super.key,
    this.initialLocation = const LocationModel(),
    this.initialGroundName = '',
  });

  final LocationModel initialLocation;
  final String initialGroundName;

  @override
  ConsumerState<GroundMapPickerScreen> createState() =>
      _GroundMapPickerScreenState();
}

class _GroundMapPickerScreenState extends ConsumerState<GroundMapPickerScreen> {
  final _searchController = TextEditingController();
  final _groundNameController = TextEditingController();
  final _mapKey = GlobalKey<GroundMapWebViewState>();

  Timer? _debounce;
  bool _loading = true;
  bool _resolving = false;
  List<PlaceSuggestion> _suggestions = [];
  String? _statusMessage;
  LocationModel _resolvedLocation = const LocationModel();
  double _pinLat = 6.9271;
  double _pinLng = 79.8612;

  @override
  void initState() {
    super.initState();
    _groundNameController.text = widget.initialGroundName;
    _resolvedLocation = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMapCenter());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _groundNameController.dispose();
    super.dispose();
  }

  GoogleMapsLocationService get _service =>
      ref.read(googleMapsLocationServiceProvider);

  Future<void> _initMapCenter() async {
    setState(() => _loading = true);
    try {
      if (!widget.initialLocation.isEmpty) {
        final query = [
          widget.initialLocation.city,
          widget.initialLocation.stateProvince,
          widget.initialLocation.country,
        ].where((p) => p.isNotEmpty).join(', ');
        if (query.isNotEmpty) {
          final results = await _service.searchPlaces(query);
          if (results.isNotEmpty) {
            final resolved = await _service.resolvePlace(results.first.placeId);
            _applyCoords(resolved.coords, resolved.location);
            return;
          }
        }
      }

      final access = await _service.ensureLocationPermission();
      if (access == LocationAccessStatus.granted) {
        final coords = await _service.getCurrentCoords();
        if (coords != null) {
          final resolved = await _service.reverseGeocode(coords);
          _applyCoords(coords, resolved.location);
          return;
        }
      }

      _applyCoords(
        const GeoCoords(latitude: 6.9271, longitude: 79.8612),
        widget.initialLocation,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not load map: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyCoords(GeoCoords coords, LocationModel location) {
    setState(() {
      _pinLat = coords.latitude;
      _pinLng = coords.longitude;
      _resolvedLocation = location;
    });
    _mapKey.currentState?.movePin(coords.latitude, coords.longitude);
  }

  Future<void> _movePin(GeoCoords coords) async {
    setState(() {
      _pinLat = coords.latitude;
      _pinLng = coords.longitude;
      _resolving = true;
      _statusMessage = null;
    });
    try {
      final resolved = await _service.reverseGeocode(coords);
      if (!mounted) return;
      setState(() => _resolvedLocation = resolved.location);
    } catch (e) {
      if (mounted) {
        setState(
          () => _statusMessage = 'Could not resolve address for pin: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.trim().length < 2) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
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
          _statusMessage = '$e';
        }
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resolving = true;
      _suggestions = [];
      _searchController.text = suggestion.description;
    });
    try {
      final resolved = await _service.resolvePlace(
        suggestion.placeId,
        fallbackDescription: suggestion.description,
      );
      if (!mounted) return;
      _applyCoords(resolved.coords, resolved.location);
      final suggestedName =
          groundNameFromPlaceDescription(suggestion.description);
      if (_groundNameController.text.trim().isEmpty && suggestedName.isNotEmpty) {
        _groundNameController.text = suggestedName;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not load place: $e');
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _confirm() {
    final name = _groundNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the ground name')),
      );
      return;
    }
    final coords = GeoCoords(latitude: _pinLat, longitude: _pinLng);
    Navigator.pop(
      context,
      GroundPickResult(
        groundName: name,
        location: _resolvedLocation.copyWith(
          latitude: coords.latitude,
          longitude: coords.longitude,
        ),
        coords: coords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final locationLine = _resolvedLocation.displayLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Pick ground on map')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search near ground',
                hintText: 'Stadium, park, or address',
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
                        onPressed: _loading ? null : _initMapCenter,
                      ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                color: cf.sectionBackground,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length.clamp(0, 4),
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: cf.border),
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
            ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: 4,
              ),
              child: Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GroundMapWebView(
                    key: _mapKey,
                    latitude: _pinLat,
                    longitude: _pinLng,
                    onPinMoved: _movePin,
                  ),
          ),
          Material(
            color: cf.card,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (locationLine.isNotEmpty)
                      Text(
                        locationLine,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                    const SizedBox(height: AppDimens.spaceSm),
                    CfUnderlinedField(
                      controller: _groundNameController,
                      label: 'Ground name',
                      required: true,
                      hint: 'e.g. R Premadasa Stadium',
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    FilledButton(
                      onPressed: _confirm,
                      style: ScoringUiKit.primaryButtonStyle(context),
                      child: const Text('Use this location'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
