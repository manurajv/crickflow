import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import '../../../player_onboarding/presentation/widgets/country_picker_sheet.dart';

/// Country + city filter sheet opened from the scope bar icon.
Future<void> showTeamsLocationFilterSheet(
  BuildContext context, {
  required String country,
  required String city,
  required void Function(String country, String city) onApply,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) {
      return _TeamsLocationFilterSheet(
        initialCountry: country,
        initialCity: city,
        onApply: (c, city) {
          onApply(c, city);
          Navigator.pop(ctx);
        },
      );
    },
  );
}

class _TeamsLocationFilterSheet extends StatefulWidget {
  const _TeamsLocationFilterSheet({
    required this.initialCountry,
    required this.initialCity,
    required this.onApply,
  });

  final String initialCountry;
  final String initialCity;
  final void Function(String country, String city) onApply;

  @override
  State<_TeamsLocationFilterSheet> createState() =>
      _TeamsLocationFilterSheetState();
}

class _TeamsLocationFilterSheetState extends State<_TeamsLocationFilterSheet> {
  late String _country;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
    _cityController = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context);
    if (picked == null) return;
    setState(() => _country = picked.name);
  }

  void _clear() {
    setState(() {
      _country = '';
      _cityController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        bottom: MediaQuery.paddingOf(context).bottom + AppDimens.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter by location',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfUnderlinedField(
            key: ValueKey('sheet-country-$_country'),
            initialValue: _country.isEmpty ? null : _country,
            label: 'Country',
            hint: 'All countries',
            readOnly: true,
            onTap: _pickCountry,
            suffix: const Icon(
              Icons.expand_more,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfUnderlinedField(
            controller: _cityController,
            label: 'City',
            hint: 'Any city',
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Row(
            children: [
              TextButton(onPressed: _clear, child: const Text('Clear')),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    widget.onApply(_country, _cityController.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
