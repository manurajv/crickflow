import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/location_model.dart';

/// Filters lists by country / city (client-side).
class LocationFilterBar extends StatefulWidget {
  const LocationFilterBar({
    super.key,
    this.initialCountry = '',
    this.initialCity = '',
    required this.onFilterChanged,
  });

  final String initialCountry;
  final String initialCity;
  final void Function(String country, String city) onFilterChanged;

  @override
  State<LocationFilterBar> createState() => _LocationFilterBarState();
}

class _LocationFilterBarState extends State<LocationFilterBar> {
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _countryController = TextEditingController(text: widget.initialCountry);
    _cityController = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onFilterChanged(
      _countryController.text.trim(),
      _cityController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.public, size: 22),
              ),
              onChanged: (_) => _notify(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city, size: 22),
              ),
              onChanged: (_) => _notify(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _countryController.clear();
              _cityController.clear();
              _notify();
            },
            tooltip: 'Clear filters',
          ),
        ],
      ),
    );
  }
}

bool locationMatchesFilter(LocationModel location, String country, String city) {
  if (country.isNotEmpty) {
    final c = country.toLowerCase();
    if (location.country.toLowerCase() != c &&
        !location.country.toLowerCase().contains(c)) {
      return false;
    }
  }
  if (city.isNotEmpty) {
    final q = city.toLowerCase();
    if (!location.city.toLowerCase().contains(q) &&
        !location.stateProvince.toLowerCase().contains(q)) {
      return false;
    }
  }
  return true;
}
