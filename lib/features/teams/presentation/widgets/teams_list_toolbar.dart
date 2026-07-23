import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/location_filter_selection.dart';
import '../../../../shared/widgets/location_filter_sheet.dart';
import 'team_list_scope.dart';

/// Inline search field for team lists (My Cricket tab + `/teams`).
class TeamsSearchBar extends StatefulWidget {
  const TeamsSearchBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.hint = 'Search team name or ID (TM00042)',
    this.debounceMs = 200,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final String hint;
  final int debounceMs;

  @override
  State<TeamsSearchBar> createState() => _TeamsSearchBarState();
}

class _TeamsSearchBarState extends State<TeamsSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  static const double _fieldHeight = 46;

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
    final cf = context.cf;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Container(
        height: _fieldHeight,
        decoration: BoxDecoration(
          color: cf.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cf.border),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cf.textPrimary,
            height: 1.2,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: cf.textHint,
              height: 1.2,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 22,
              color: cf.textMuted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: _fieldHeight,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 20, color: cf.textMuted),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                      setState(() {});
                    },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: _fieldHeight,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            isDense: true,
          ),
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
      ),
    );
  }
}

/// Scope + location filter row (My Cricket tab style).
class TeamsScopeFilterBar extends StatelessWidget {
  const TeamsScopeFilterBar({
    super.key,
    required this.scope,
    required this.locations,
    required this.onScopeChanged,
    required this.onLocationsChanged,
  });

  final TeamListScope scope;
  final List<LocationFilterSelection> locations;
  final ValueChanged<TeamListScope> onScopeChanged;
  final ValueChanged<List<LocationFilterSelection>> onLocationsChanged;

  bool get _locationActive => locations.isNotEmpty;

  Future<void> _openLocationFilter(BuildContext context) async {
    final result = await showLocationFilterSheet(
      context,
      initial: locations,
      subtitle:
          'Search or use GPS, then add locations. Teams matching any selection '
          'are shown. Clear city/province fields to broaden a filter.',
    );
    if (result == null) return;
    onLocationsChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

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
                  _TeamsScopeChip(
                    label: s.chipLabel,
                    selected: scope == s,
                    onTap: () => onScopeChanged(s),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                ],
                _TeamsScopeChip(
                  label: 'Location',
                  selected: _locationActive,
                  icon: Icons.place_outlined,
                  onTap: () => _openLocationFilter(context),
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
                      locations.length == 1
                          ? locations.first.label
                          : '${locations.length} locations',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onLocationsChanged(const []),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: cf.link),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamsScopeChip extends StatelessWidget {
  const _TeamsScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    final foreground = selected ? cf.onAccent : cf.textSecondary;
    final iconColor = selected ? cf.onAccent : cf.textMuted;

    return Material(
      color: selected ? cf.accent : cf.sectionBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
