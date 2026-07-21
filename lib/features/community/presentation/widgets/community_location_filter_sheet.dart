import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import '../../../player_onboarding/presentation/widgets/country_picker_sheet.dart';
import '../../data/community_location_filter_store.dart';

Future<List<CommunityLocationSelection>?> showCommunityLocationFilterSheet(
  BuildContext context, {
  required List<CommunityLocationSelection> initial,
}) {
  return showModalBottomSheet<List<CommunityLocationSelection>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => CommunityLocationFilterSheet(initial: initial),
  );
}

class CommunityLocationFilterSheet extends StatefulWidget {
  const CommunityLocationFilterSheet({super.key, required this.initial});

  final List<CommunityLocationSelection> initial;

  @override
  State<CommunityLocationFilterSheet> createState() =>
      _CommunityLocationFilterSheetState();
}

class _CommunityLocationFilterSheetState
    extends State<CommunityLocationFilterSheet> {
  late List<CommunityLocationSelection> _selected;
  String _country = '';
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.initial);
  }

  @override
  void dispose() {
    _stateController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(context);
    if (picked == null) return;
    setState(() => _country = picked.name);
  }

  void _addCurrent() {
    final entry = CommunityLocationSelection(
      country: _country.trim(),
      stateProvince: _stateController.text.trim(),
      district: _districtController.text.trim(),
      city: _cityController.text.trim(),
    );
    if (entry.isEmpty) return;
    if (_selected.contains(entry)) return;
    setState(() => _selected = [..._selected, entry]);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        bottom + AppDimens.spaceMd,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter by location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Add countries, provinces, districts, or cities. Posts matching any selection are shown.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            InkWell(
              onTap: _pickCountry,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _country.isEmpty ? 'Select country' : _country,
                  style: TextStyle(
                    color: _country.isEmpty ? cf.textMuted : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            CfUnderlinedField(
              controller: _stateController,
              label: 'State / Province',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            CfUnderlinedField(
              controller: _districtController,
              label: 'District',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            CfUnderlinedField(
              controller: _cityController,
              label: 'City / Location',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            OutlinedButton.icon(
              onPressed: _addCurrent,
              icon: const Icon(Icons.add),
              label: const Text('Add to filter'),
            ),
            if (_selected.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.map((s) {
                  return InputChip(
                    label: Text(s.label),
                    onDeleted: () {
                      setState(() {
                        _selected = _selected.where((e) => e != s).toList();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selected = []);
                      Navigator.pop(context, <CommunityLocationSelection>[]);
                    },
                    child: const Text('Clear filter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
