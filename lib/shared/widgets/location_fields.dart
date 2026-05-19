import 'package:flutter/material.dart';
import '../../data/models/location_model.dart';

class LocationFields extends StatelessWidget {
  const LocationFields({
    super.key,
    required this.location,
    required this.onChanged,
  });

  final LocationModel location;
  final void Function(LocationModel) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          initialValue: location.country,
          decoration: const InputDecoration(labelText: 'Country'),
          onChanged: (v) => onChanged(location.copyWith(country: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: location.stateProvince,
          decoration: const InputDecoration(labelText: 'State / Province'),
          onChanged: (v) => onChanged(location.copyWith(stateProvince: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: location.city,
          decoration: const InputDecoration(labelText: 'City'),
          onChanged: (v) => onChanged(location.copyWith(city: v)),
        ),
      ],
    );
  }
}
