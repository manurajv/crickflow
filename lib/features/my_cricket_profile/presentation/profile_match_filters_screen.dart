import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../domain/services/player_cricket_profile_models.dart';
import '../../../domain/services/profile_match_filter_service.dart';
import '../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

enum _ProfileMatchFilterCategory { overs, ball, type, year }

class ProfileMatchFiltersScreen extends ConsumerStatefulWidget {
  const ProfileMatchFiltersScreen({
    super.key,
    required this.options,
  });

  final ProfileMatchFilterOptions options;

  @override
  ConsumerState<ProfileMatchFiltersScreen> createState() =>
      _ProfileMatchFiltersScreenState();
}

class _ProfileMatchFiltersScreenState
    extends ConsumerState<ProfileMatchFiltersScreen> {
  late ProfileMatchFilters _draft;
  _ProfileMatchFilterCategory _category = _ProfileMatchFilterCategory.overs;

  @override
  void initState() {
    super.initState();
    // Drop legacy team filter — Team is no longer offered in the UI.
    final current = ref.read(profileMatchFiltersProvider);
    _draft = current.copyWith(teamId: () => null);
  }

  void _apply() {
    ref.read(profileMatchFiltersProvider.notifier).state =
        _draft.copyWith(teamId: () => null);
    Navigator.pop(context);
  }

  bool _isCategoryActive(_ProfileMatchFilterCategory category) =>
      switch (category) {
        _ProfileMatchFilterCategory.overs => _draft.overs != null,
        _ProfileMatchFilterCategory.ball => _draft.ballType != null,
        _ProfileMatchFilterCategory.type => _draft.matchType != null,
        _ProfileMatchFilterCategory.year => _draft.year != null,
      };

  Future<void> _pickCustomOvers() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom overs'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter overs'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.pop(ctx, parsed);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(overs: () => value));
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: _apply,
            child: const Text('Apply'),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryPanel(
            cf: cf,
            selected: _category,
            isActive: _isCategoryActive,
            onSelected: (category) => setState(() => _category = category),
          ),
          VerticalDivider(width: 1, color: cf.border),
          Expanded(child: _buildOptionsPanel(cf)),
        ],
      ),
    );
  }

  Widget _buildOptionsPanel(CfColors cf) {
    return switch (_category) {
      _ProfileMatchFilterCategory.overs => _buildOversOptions(cf),
      _ProfileMatchFilterCategory.ball => _buildBallOptions(cf),
      _ProfileMatchFilterCategory.type => _buildTypeOptions(cf),
      _ProfileMatchFilterCategory.year => _buildYearOptions(cf),
    };
  }

  Widget _buildOversOptions(CfColors cf) {
    final customSelected = _draft.overs != null &&
        _draft.overs! > 0 &&
        !profileOversFilterOptions.contains(_draft.overs);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      children: [
        ...profileOversFilterOptions.map(
          (overs) => _optionTile(
            cf: cf,
            label: profileMatchOversFilterLabel(overs),
            selected: _draft.overs == overs,
            onTap: () => setState(
              () => _draft = _draft.copyWith(
                overs: () => _draft.overs == overs ? null : overs,
              ),
            ),
          ),
        ),
        _optionTile(
          cf: cf,
          label: 'Test',
          selected: _draft.overs == -1,
          onTap: () => setState(
            () => _draft = _draft.copyWith(
              overs: () => _draft.overs == -1 ? null : -1,
            ),
          ),
        ),
        _optionTile(
          cf: cf,
          label: customSelected
              ? 'Custom (${_draft.overs} overs)'
              : 'Custom overs',
          selected: customSelected,
          onTap: _pickCustomOvers,
        ),
      ],
    );
  }

  Widget _buildBallOptions(CfColors cf) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      children: CricketBallType.values
          .map(
            (type) => _optionTile(
              cf: cf,
              label: profileMatchBallTypeFilterLabel(type),
              selected: _draft.ballType == type,
              onTap: () => setState(
                () => _draft = _draft.copyWith(
                  ballType: () => _draft.ballType == type ? null : type,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTypeOptions(CfColors cf) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      children: CricketMatchType.values
          .map(
            (type) => _optionTile(
              cf: cf,
              label: profileMatchTypeFilterLabel(type),
              selected: _draft.matchType == type,
              onTap: () => setState(
                () => _draft = _draft.copyWith(
                  matchType: () => _draft.matchType == type ? null : type,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildYearOptions(CfColors cf) {
    if (widget.options.years.isEmpty) {
      return _emptyOptions(cf, 'No years available');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      children: widget.options.years
          .map(
            (year) => _optionTile(
              cf: cf,
              label: '$year',
              selected: _draft.year == year,
              onTap: () => setState(
                () => _draft = _draft.copyWith(
                  year: () => _draft.year == year ? null : year,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _emptyOptions(CfColors cf, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _optionTile({
    required CfColors cf,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: cf.accent, size: 20) : null,
      selected: selected,
      selectedTileColor: cf.accent.withValues(alpha: 0.08),
      onTap: onTap,
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.cf,
    required this.selected,
    required this.isActive,
    required this.onSelected,
  });

  final CfColors cf;
  final _ProfileMatchFilterCategory selected;
  final bool Function(_ProfileMatchFilterCategory category) isActive;
  final ValueChanged<_ProfileMatchFilterCategory> onSelected;

  static const _labels = {
    _ProfileMatchFilterCategory.overs: 'Overs',
    _ProfileMatchFilterCategory.ball: 'Ball',
    _ProfileMatchFilterCategory.type: 'Type',
    _ProfileMatchFilterCategory.year: 'Year',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cf.sectionBackground,
      child: SizedBox(
        width: 120,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
          children: _ProfileMatchFilterCategory.values
              .map(
                (category) => _CategoryTile(
                  cf: cf,
                  label: _labels[category]!,
                  selected: selected == category,
                  active: isActive(category),
                  onTap: () => onSelected(category),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.cf,
    required this.label,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final CfColors cf;
  final String label;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? cf.surface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? cf.accent : cf.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cf.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
