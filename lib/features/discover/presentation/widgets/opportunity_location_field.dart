import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../matches/presentation/models/ground_pick_result.dart';

/// Exact place / ground picker (Discover opportunities, team home ground, etc.).
class OpportunityLocationField extends ConsumerStatefulWidget {
  const OpportunityLocationField({
    super.key,
    required this.location,
    required this.onLocationChanged,
    this.helperText = 'Search a ground or pin the exact spot on the map',
    this.hintText = 'Ground / venue name',
  });

  final LocationModel location;
  final ValueChanged<LocationModel> onLocationChanged;
  final String helperText;
  final String hintText;

  @override
  ConsumerState<OpportunityLocationField> createState() =>
      _OpportunityLocationFieldState();
}

class _OpportunityLocationFieldState
    extends ConsumerState<OpportunityLocationField> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  bool _resolving = false;
  List<PlaceSuggestion> _suggestions = [];
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.location.placeName.isNotEmpty
          ? widget.location.placeName
          : widget.location.displayLabel,
    );
  }

  @override
  void didUpdateWidget(covariant OpportunityLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      final next = widget.location.placeName.isNotEmpty
          ? widget.location.placeName
          : widget.location.displayLabel;
      if (_searchController.text != next && _suggestions.isEmpty) {
        _searchController.text = next;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  GoogleMapsLocationService get _service =>
      ref.read(googleMapsLocationServiceProvider);

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = value.trim();
      if (q.length < 2) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      try {
        GeoCoords? bias;
        if (widget.location.hasCoordinates) {
          bias = GeoCoords(
            latitude: widget.location.latitude!,
            longitude: widget.location.longitude!,
          );
        } else {
          try {
            bias = await _service.getCurrentCoords();
          } catch (_) {}
        }
        final results = await _service.searchPlaces(q, bias: bias);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _statusMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _statusMessage = '$e';
          });
        }
      }
    });
  }

  Future<void> _pickSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _resolving = true;
      _suggestions = [];
    });
    try {
      final resolved = await _service.resolvePlace(
        suggestion.placeId,
        fallbackDescription: suggestion.description,
      );
      if (!mounted) return;
      final name = groundNameFromPlaceDescription(suggestion.description);
      final placeName =
          name.isNotEmpty ? name : suggestion.description.trim();
      _searchController.text = placeName;
      widget.onLocationChanged(
        resolved.location.copyWith(placeName: placeName),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not load place: $e');
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': widget.location,
        'groundName': _searchController.text.trim(),
      },
    );
    if (result == null || !mounted) return;
    final placeName = result.groundName.trim().isNotEmpty
        ? result.groundName.trim()
        : groundNameFromPlaceDescription(_searchController.text);
    _searchController.text = placeName;
    widget.onLocationChanged(
      result.location.copyWith(
        placeName: placeName,
        latitude: result.coords?.latitude ?? result.location.latitude,
        longitude: result.coords?.longitude ?? result.location.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final area = [
      widget.location.city,
      widget.location.district,
      widget.location.stateProvince,
    ].where((p) => p.trim().isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.helperText,
          style: theme.textTheme.bodySmall?.copyWith(color: cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.stadium_outlined),
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
                    icon: Icon(Icons.map_outlined, color: cf.accent),
                    tooltip: 'Pick on map',
                    onPressed: _pickOnMap,
                  ),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: _onSearchChanged,
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusMessage!,
            style: theme.textTheme.bodySmall?.copyWith(color: cf.textMuted),
          ),
        ],
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: cf.surfaceElevated,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length.clamp(0, 6),
              separatorBuilder: (_, _) => const Divider(height: 1),
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _pickOnMap,
            icon: const Icon(Icons.pin_drop_outlined, size: 18),
            label: const Text('Pick on map'),
            style: TextButton.styleFrom(
              foregroundColor: cf.accent,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (widget.location.placeName.isNotEmpty ||
            widget.location.hasCoordinates) ...[
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceSm + 2),
            decoration: BoxDecoration(
              color: cf.sectionBackground,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: cf.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 18, color: cf.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.location.placeName.isNotEmpty
                            ? widget.location.placeName
                            : 'Pinned location',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (area.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          area,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                        ),
                      ],
                      if (widget.location.hasCoordinates) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Exact pin saved',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cf.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
