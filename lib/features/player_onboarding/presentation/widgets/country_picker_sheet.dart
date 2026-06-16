import 'package:flutter/material.dart';
import '../../../../core/constants/player_profile_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Searchable country picker with pinned cricket nations at the top.
Future<CricketCountry?> showCountryPickerSheet(BuildContext context) {
  return showModalBottomSheet<CricketCountry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _pinnedCount = 15;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CricketCountry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return CricketCountry.all;
    return CricketCountry.all
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.dialCode.contains(q) ||
              c.code.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final showSectionHeader = _query.isEmpty && items.length > _pinnedCount;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scroll) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search country',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: items.length + (showSectionHeader ? 1 : 0),
                itemBuilder: (_, i) {
                  if (showSectionHeader && i == _pinnedCount) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        AppDimens.spaceSm,
                      ),
                      child: Text(
                        'All countries',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    );
                  }
                  final dataIndex =
                      showSectionHeader && i > _pinnedCount ? i - 1 : i;
                  final c = items[dataIndex];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name),
                    subtitle: Text(c.dialCode),
                    trailing: Text(
                      c.code,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
