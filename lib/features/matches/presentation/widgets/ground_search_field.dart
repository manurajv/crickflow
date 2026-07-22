import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/services/google_maps_location_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import '../models/ground_pick_result.dart';
import '../../../../core/theme/cf_colors.dart';

/// Ground name search with Places autocomplete + link to map picker.
class GroundSearchField extends ConsumerStatefulWidget {
  const GroundSearchField({
    super.key,
    required this.controller,
    required this.onVenueChanged,
    required this.onLocationResolved,
    required this.onPickOnMap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onVenueChanged;
  final ValueChanged<LocationModel> onLocationResolved;
  final VoidCallback onPickOnMap;

  @override
  ConsumerState<GroundSearchField> createState() => _GroundSearchFieldState();
}

class _GroundSearchFieldState extends ConsumerState<GroundSearchField> {
  Timer? _debounce;
  bool _resolving = false;
  List<PlaceSuggestion> _suggestions = [];
  String? _statusMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  GoogleMapsLocationService get _service =>
      ref.read(googleMapsLocationServiceProvider);

  void _onSearchChanged(String value) {
    widget.onVenueChanged(value);
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
    });
    try {
      final resolved = await _service.resolvePlace(
        suggestion.placeId,
        fallbackDescription: suggestion.description,
      );
      if (!mounted) return;
      final name = groundNameFromPlaceDescription(suggestion.description);
      widget.controller.text = name.isNotEmpty ? name : suggestion.description;
      widget.onVenueChanged(widget.controller.text);
      widget.onLocationResolved(resolved.location);
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Could not load place: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfUnderlinedField(
          controller: widget.controller,
          label: 'Ground',
          required: true,
          hint: 'Search ground or venue name',
          suffix: _resolving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(Icons.map_outlined, color: cf.accent),
                  tooltip: 'Pick on map',
                  onPressed: widget.onPickOnMap,
                ),
          onChanged: _onSearchChanged,
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _statusMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ],
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            color: cf.sectionBackground,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length.clamp(0, 5),
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cf.border),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.stadium_outlined, size: 20),
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
            onPressed: widget.onPickOnMap,
            icon: const Icon(Icons.pin_drop_outlined, size: 18),
            label: const Text('Not listed? Pick on map'),
            style: TextButton.styleFrom(
              foregroundColor: cf.accent,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
