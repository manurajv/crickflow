import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import '../../../player_onboarding/presentation/widgets/country_picker_sheet.dart';

/// Country + city filter sheet opened from the scope bar icon.
Future<void> showTeamsLocationFilterSheet(
  BuildContext context, {
  required String country,
  required String city,
  required void Function(String country, String city) onApply,
}) async {
  final cf = context.cf;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cf.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
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
    final cf = context.cf;
    final theme = Theme.of(context);

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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cf.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfUnderlinedField(
            key: ValueKey('sheet-country-$_country'),
            initialValue: _country.isEmpty ? null : _country,
            label: 'Country',
            hint: 'All countries',
            readOnly: true,
            onTap: _pickCountry,
            suffix: Icon(
              Icons.expand_more,
              size: 20,
              color: cf.textSecondary,
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
              TextButton(
                onPressed: _clear,
                child: Text('Clear', style: TextStyle(color: cf.link)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    widget.onApply(_country, _cityController.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: cf.accent,
                  foregroundColor: cf.onAccent,
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
