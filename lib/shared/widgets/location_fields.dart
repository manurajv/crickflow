import 'package:flutter/material.dart';
import '../../data/models/location_model.dart';
import 'cf_underlined_field.dart';

class LocationFields extends StatelessWidget {
  const LocationFields({
    super.key,
    required this.location,
    required this.onChanged,
    this.showCountry = true,
    this.showState = true,
    this.showCity = true,
    this.cityRequired = false,
  });

  final LocationModel location;
  final void Function(LocationModel) onChanged;
  final bool showCountry;
  final bool showState;
  final bool showCity;
  final bool cityRequired;

  @override
  Widget build(BuildContext context) {
    return CfFormFieldGroup(
      children: [
        if (showCountry)
          CfUnderlinedField(
            initialValue: location.country,
            label: 'Country',
            onChanged: (v) => onChanged(location.copyWith(country: v)),
          ),
        if (showState)
          CfUnderlinedField(
            initialValue: location.stateProvince,
            label: 'State / province',
            onChanged: (v) => onChanged(location.copyWith(stateProvince: v)),
          ),
        if (showCity)
          CfUnderlinedField(
            initialValue: location.city,
            label: 'City / town',
            required: cityRequired,
            onChanged: (v) => onChanged(location.copyWith(city: v)),
          ),
      ],
    );
  }
}
