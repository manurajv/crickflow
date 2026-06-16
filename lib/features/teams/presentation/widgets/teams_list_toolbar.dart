import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import 'team_list_scope.dart';
import 'teams_location_filter_sheet.dart';

/// Inline search field for team lists (My Cricket tab + `/teams`).
class TeamsSearchBar extends StatefulWidget {
  const TeamsSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.hint = 'Search team name or ID (TM00042)',
    this.showLabel = false,
    this.debounceMs = 200,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool showLabel;
  final int debounceMs;

  @override
  State<TeamsSearchBar> createState() => _TeamsSearchBarState();
}

class _TeamsSearchBarState extends State<TeamsSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant TeamsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: CfUnderlinedField(
        controller: _controller,
        label: widget.showLabel ? 'Search teams' : null,
        hint: widget.hint,
        textInputAction: TextInputAction.search,
        suffix: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        onChanged: (v) {
          setState(() {});
          _debounce?.cancel();
          if (widget.debounceMs <= 0) {
            widget.onChanged(v.trim());
            return;
          }
          _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
            widget.onChanged(v.trim());
          });
        },
      ),
    );
  }
}

/// Scope + location filter row (My Cricket tab style).
class TeamsScopeFilterBar extends StatelessWidget {
  const TeamsScopeFilterBar({
    super.key,
    required this.scope,
    required this.country,
    required this.city,
    required this.onScopeChanged,
    required this.onLocationChanged,
  });

  final TeamListScope scope;
  final String country;
  final String city;
  final ValueChanged<TeamListScope> onScopeChanged;
  final void Function(String country, String city) onLocationChanged;

  bool get _locationActive => country.isNotEmpty || city.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in TeamListScope.values) ...[
                  _TeamsFilterChip(
                    label: s.chipLabel,
                    selected: scope == s,
                    onSelected: () => onScopeChanged(s),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                ],
                _TeamsFilterChip(
                  label: 'Location',
                  selected: _locationActive,
                  icon: Icons.place_outlined,
                  onSelected: () => showTeamsLocationFilterSheet(
                    context,
                    country: country,
                    city: city,
                    onApply: onLocationChanged,
                  ),
                ),
              ],
            ),
          ),
          if (_locationActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (country.isNotEmpty) country,
                        if (city.isNotEmpty) city,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onLocationChanged('', ''),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamsFilterChip extends StatelessWidget {
  const _TeamsFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 18,
              color: selected ? AppColors.gold : AppColors.textSecondary,
            )
          : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.35),
      checkmarkColor: AppColors.gold,
      showCheckmark: icon == null,
      labelStyle: TextStyle(
        color: selected ? AppColors.gold : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
