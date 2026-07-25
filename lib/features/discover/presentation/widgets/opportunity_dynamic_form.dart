import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/location_model.dart';
import '../../domain/opportunity_category.dart';
import '../../domain/opportunity_field_schema.dart';
import 'opportunity_location_field.dart';

/// Renders category-specific dynamic fields from [OpportunityFieldSchema].
class OpportunityDynamicForm extends StatelessWidget {
  const OpportunityDynamicForm({
    super.key,
    required this.category,
    required this.values,
    required this.onChanged,
  });

  final OpportunityCategory category;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;

  void _set(String key, dynamic value) {
    final next = Map<String, dynamic>.from(values);
    if (value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty)) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    onChanged(next);
  }

  void _setMany(Map<String, dynamic> updates) {
    final next = Map<String, dynamic>.from(values);
    for (final e in updates.entries) {
      final value = e.value;
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty)) {
        next.remove(e.key);
      } else {
        next[e.key] = value;
      }
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final fields = OpportunityFieldSchema.fieldsFor(category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final def in fields) ...[
          _FieldLabel(label: def.label, required: def.required),
          const SizedBox(height: 6),
          _buildField(context, def),
          const SizedBox(height: AppDimens.fieldSpacing),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, OpportunityFieldDef def) {
    return switch (def.type) {
      OpportunityFieldType.text => TextFormField(
          initialValue: values[def.key]?.toString() ?? '',
          decoration: InputDecoration(
            hintText: def.hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _set(def.key, v),
          validator: def.required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      OpportunityFieldType.multiline => TextFormField(
          initialValue: values[def.key]?.toString() ?? '',
          maxLines: def.maxLines.clamp(2, 6),
          decoration: InputDecoration(
            hintText: def.hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _set(def.key, v),
          validator: def.required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      OpportunityFieldType.number => TextFormField(
          initialValue: values[def.key]?.toString() ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: def.hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _set(def.key, v),
          validator: def.required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      OpportunityFieldType.url => TextFormField(
          initialValue: values[def.key]?.toString() ?? '',
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: def.hint ?? 'https://…',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.link, size: 20),
          ),
          onChanged: (v) => _set(def.key, v.trim()),
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) {
              return def.required ? 'Required' : null;
            }
            if (!_isHttpUrl(trimmed)) {
              return 'Enter a valid URL (https://…)';
            }
            return null;
          },
          onSaved: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) {
              _set(def.key, null);
              return;
            }
            _set(def.key, _normalizeHttpUrl(trimmed));
          },
        ),
      OpportunityFieldType.singleSelect => def.options.length > 6
          ? DropdownButtonFormField<String>(
              key: ValueKey('dd_${def.key}_${values[def.key]}'),
              initialValue: (values[def.key] as String?)?.isNotEmpty == true
                  ? values[def.key] as String
                  : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: def.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => _set(def.key, v),
              validator: def.required
                  ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                  : null,
            )
          : _ChoiceChipWrap(
              options: def.options,
              selected: values[def.key]?.toString(),
              onSelected: (v) => _set(def.key, v),
            ),
      OpportunityFieldType.multiSelect => _FilterChipWrap(
          options: def.options,
          selected: _asStringList(values[def.key]),
          onChanged: (v) => _set(def.key, v),
        ),
      OpportunityFieldType.yesNo => _ChoiceChipWrap(
          options: const ['Yes', 'No'],
          selected: values[def.key]?.toString(),
          onSelected: (v) => _set(def.key, v),
        ),
      OpportunityFieldType.date => _DateField(
          value: values[def.key]?.toString(),
          onChanged: (iso) => _set(def.key, iso),
          required: def.required,
        ),
      OpportunityFieldType.dateOrRange => _DateOrRangeField(
          startValue: values[def.key]?.toString(),
          endValue: values['${def.key}End']?.toString(),
          onChanged: (start, end) => _setMany({
            def.key: start,
            '${def.key}End': end,
          }),
          required: def.required,
        ),
    };
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static bool _isHttpUrl(String raw) {
    final uri = Uri.tryParse(_normalizeHttpUrl(raw));
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;
    return true;
  }

  static String _normalizeHttpUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }
}

/// Shared create-flow fields (description, location, contact, expiry).
/// Title is locked to [OpportunityCategory.fixedTitle] and shown via the intent banner.
class OpportunityCommonFields extends StatelessWidget {
  const OpportunityCommonFields({
    super.key,
    required this.category,
    required this.descriptionController,
    required this.location,
    required this.onLocationChanged,
    required this.contactMethods,
    required this.onContactMethodsChanged,
    required this.contactPhoneController,
    required this.contactWhatsAppController,
    required this.whatsAppSameAsPhone,
    required this.onWhatsAppSameAsPhoneChanged,
    required this.expiry,
    required this.onExpiryChanged,
    this.profilePhone = '',
    this.showExpiry = true,
  });

  final OpportunityCategory category;
  final TextEditingController descriptionController;
  final LocationModel location;
  final ValueChanged<LocationModel> onLocationChanged;
  final Set<OpportunityContactMethod> contactMethods;
  final ValueChanged<Set<OpportunityContactMethod>> onContactMethodsChanged;
  final TextEditingController contactPhoneController;
  final TextEditingController contactWhatsAppController;
  final bool whatsAppSameAsPhone;
  final ValueChanged<bool> onWhatsAppSameAsPhoneChanged;
  final String profilePhone;
  final OpportunityExpiry expiry;
  final ValueChanged<OpportunityExpiry> onExpiryChanged;
  final bool showExpiry;

  String get _sameNumberSource {
    final phone = contactPhoneController.text.trim();
    if (phone.isNotEmpty) return phone;
    return profilePhone.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final showPhone =
        contactMethods.contains(OpportunityContactMethod.phone);
    final showWhatsApp =
        contactMethods.contains(OpportunityContactMethod.whatsapp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IntentBanner(category: category),
        const SizedBox(height: AppDimens.fieldSpacing),
        const _FieldLabel(label: 'Description', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: category.descriptionHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Description is required'
              : null,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        Text(
          'Location',
          style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        OpportunityLocationField(
          location: location,
          onLocationChanged: onLocationChanged,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        const _FieldLabel(label: 'Contact methods', required: true),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: OpportunityContactMethod.values.map((m) {
            final selected = contactMethods.contains(m);
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(m.label),
                ],
              ),
              selected: selected,
              selectedColor: cf.accent.withValues(alpha: 0.2),
              showCheckmark: false,
              onSelected: (on) {
                final next = Set<OpportunityContactMethod>.from(contactMethods);
                if (on) {
                  next.add(m);
                } else if (next.length > 1) {
                  next.remove(m);
                }
                onContactMethodsChanged(next);
              },
            );
          }).toList(),
        ),
        if (showPhone || showWhatsApp) ...[
          const SizedBox(height: AppDimens.spaceMd),
          if (showPhone) ...[
            const _FieldLabel(label: 'Phone', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: profilePhone.isNotEmpty ? profilePhone : '+94…',
                helperText: profilePhone.isNotEmpty
                    ? 'From your profile — edit if needed'
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                if (!showPhone) return null;
                return (v == null || v.trim().isEmpty) ? 'Phone required' : null;
              },
            ),
            if (showWhatsApp) const SizedBox(height: AppDimens.spaceMd),
          ],
          if (showWhatsApp) ...[
            const _FieldLabel(label: 'WhatsApp number', required: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text(
                    showPhone ? 'Same as phone' : 'Same as profile',
                  ),
                  selected: whatsAppSameAsPhone,
                  selectedColor: cf.accent.withValues(alpha: 0.2),
                  showCheckmark: false,
                  onSelected: (_) => onWhatsAppSameAsPhoneChanged(true),
                ),
                ChoiceChip(
                  label: const Text('Different number'),
                  selected: !whatsAppSameAsPhone,
                  selectedColor: cf.accent.withValues(alpha: 0.2),
                  showCheckmark: false,
                  onSelected: (_) => onWhatsAppSameAsPhoneChanged(false),
                ),
              ],
            ),
            if (whatsAppSameAsPhone) ...[
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: contactPhoneController,
                builder: (context, _) {
                  final source = _sameNumberSource;
                  return Text(
                    source.isNotEmpty
                        ? 'WhatsApp will use $source'
                        : showPhone
                            ? 'Enter a phone number above to use for WhatsApp'
                            : 'Add a phone number in your profile, or choose a different number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
                  );
                },
              ),
              FormField<String>(
                validator: (_) {
                  if (!showWhatsApp || !whatsAppSameAsPhone) return null;
                  if (_sameNumberSource.isNotEmpty) return null;
                  return 'Add a phone number or choose a different WhatsApp number';
                },
                builder: (_) => const SizedBox.shrink(),
              ),
            ] else ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: contactWhatsAppController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+94…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (!showWhatsApp || whatsAppSameAsPhone) return null;
                  return (v == null || v.trim().isEmpty)
                      ? 'WhatsApp number required'
                      : null;
                },
              ),
            ],
          ],
        ],
        if (showExpiry) ...[
          const SizedBox(height: AppDimens.fieldSpacing),
          const _FieldLabel(label: 'Expires in'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: OpportunityExpiry.values.map((e) {
              final selected = e == expiry;
              return ChoiceChip(
                label: Text(e.label),
                selected: selected,
                selectedColor: cf.accent.withValues(alpha: 0.2),
                onSelected: (_) => onExpiryChanged(e),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _IntentBanner extends StatelessWidget {
  const _IntentBanner({required this.category});

  final OpportunityCategory category;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: category.badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: category.badgeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(category.icon, color: category.badgeColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.fixedTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Posting as: ${category.posterRole}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (required)
            TextSpan(
              text: ' *',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceChipWrap extends StatelessWidget {
  const _ChoiceChipWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((o) {
        final isOn = selected == o;
        return ChoiceChip(
          label: Text(o),
          selected: isOn,
          selectedColor: cf.accent.withValues(alpha: 0.2),
          onSelected: (_) => onSelected(o),
        );
      }).toList(),
    );
  }
}

class _FilterChipWrap extends StatelessWidget {
  const _FilterChipWrap({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((o) {
        final isOn = selected.contains(o);
        return FilterChip(
          label: Text(o),
          selected: isOn,
          onSelected: (on) {
            final next = List<String>.from(selected);
            if (on) {
              next.add(o);
            } else {
              next.remove(o);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onChanged,
    required this.required,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final parsed = value != null && value!.isNotEmpty
        ? DateTime.tryParse(value!)
        : null;
    final label = parsed != null ? AppDateUtils.formatShort(parsed) : 'Pick date';

    return FormField<String>(
      initialValue: value,
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Required' : null
          : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: parsed ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 3),
                );
                if (picked == null) return;
                final iso =
                    DateTime(picked.year, picked.month, picked.day)
                        .toIso8601String()
                        .split('T')
                        .first;
                onChanged(iso);
                state.didChange(iso);
              },
              icon: Icon(Icons.calendar_today_outlined,
                  size: 16, color: cf.accent),
              label: Text(label),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateOrRangeField extends StatefulWidget {
  const _DateOrRangeField({
    required this.startValue,
    required this.endValue,
    required this.onChanged,
    required this.required,
  });

  final String? startValue;
  final String? endValue;
  final void Function(String? start, String? end) onChanged;
  final bool required;

  @override
  State<_DateOrRangeField> createState() => _DateOrRangeFieldState();
}

class _DateOrRangeFieldState extends State<_DateOrRangeField> {
  late bool _rangeMode;
  String? _start;
  String? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startValue;
    _end = widget.endValue;
    _rangeMode = (_end ?? '').trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _DateOrRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start = widget.startValue;
    _end = widget.endValue;
    final hasEnd = (_end ?? '').trim().isNotEmpty;
    if (hasEnd && !_rangeMode) {
      _rangeMode = true;
    }
  }

  String _isoDay(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;

  Future<String?> _pickStart(BuildContext context) async {
    final now = DateTime.now();
    final parsed = _start != null && _start!.isNotEmpty
        ? DateTime.tryParse(_start!)
        : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return null;
    final start = _isoDay(picked);
    String? end;
    if (_rangeMode) {
      end = _end;
      final endParsed =
          end != null && end.isNotEmpty ? DateTime.tryParse(end) : null;
      if (endParsed != null && endParsed.isBefore(picked)) {
        end = start;
      }
    }
    setState(() {
      _start = start;
      _end = end;
    });
    widget.onChanged(start, end);
    return start;
  }

  Future<String?> _pickEnd(BuildContext context) async {
    final now = DateTime.now();
    final startParsed =
        _start != null && _start!.isNotEmpty ? DateTime.tryParse(_start!) : null;
    final endParsed =
        _end != null && _end!.isNotEmpty ? DateTime.tryParse(_end!) : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: endParsed ?? startParsed ?? now,
      firstDate: startParsed ?? DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return null;
    final start =
        _start != null && _start!.isNotEmpty ? _start! : _isoDay(picked);
    final end = _isoDay(picked);
    setState(() {
      _start = start;
      _end = end;
    });
    widget.onChanged(start, end);
    return start;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final startParsed =
        _start != null && _start!.isNotEmpty ? DateTime.tryParse(_start!) : null;
    final endParsed =
        _end != null && _end!.isNotEmpty ? DateTime.tryParse(_end!) : null;

    return FormField<String>(
      initialValue: _start,
      validator: (v) {
        if (!widget.required) {
          if (_rangeMode &&
              (v != null && v.isNotEmpty) &&
              (_end == null || _end!.trim().isEmpty)) {
            return 'Pick an end date';
          }
          return null;
        }
        if (v == null || v.isEmpty) return 'Required';
        if (_rangeMode && (_end == null || _end!.trim().isEmpty)) {
          return 'Pick an end date';
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('One day'),
                  selected: !_rangeMode,
                  selectedColor: cf.accent.withValues(alpha: 0.2),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _rangeMode = false;
                      _end = null;
                    });
                    widget.onChanged(_start, null);
                    state.didChange(_start);
                  },
                ),
                ChoiceChip(
                  label: const Text('Date range'),
                  selected: _rangeMode,
                  selectedColor: cf.accent.withValues(alpha: 0.2),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _rangeMode = true);
                    state.didChange(_start);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final start = await _pickStart(context);
                    if (start != null) state.didChange(start);
                  },
                  icon: Icon(Icons.calendar_today_outlined,
                      size: 16, color: cf.accent),
                  label: Text(
                    startParsed != null
                        ? (_rangeMode
                            ? 'From ${AppDateUtils.formatShort(startParsed)}'
                            : AppDateUtils.formatShort(startParsed))
                        : (_rangeMode ? 'Start date' : 'Pick date'),
                  ),
                ),
                if (_rangeMode) ...[
                  Text('–', style: TextStyle(color: cf.textMuted)),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final start = await _pickEnd(context);
                      if (start != null) state.didChange(start);
                    },
                    icon: Icon(Icons.event_outlined,
                        size: 16, color: cf.accent),
                    label: Text(
                      endParsed != null
                          ? 'To ${AppDateUtils.formatShort(endParsed)}'
                          : 'End date',
                    ),
                  ),
                ],
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
