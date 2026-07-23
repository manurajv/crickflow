import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/location_model.dart';
import '../../../player_onboarding/presentation/widgets/onboarding_location_section.dart';
import '../../domain/opportunity_category.dart';
import '../../domain/opportunity_field_schema.dart';

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
    };
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}

/// Shared create-flow fields (title, description, location, contact, expiry).
class OpportunityCommonFields extends StatelessWidget {
  const OpportunityCommonFields({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.location,
    required this.onLocationChanged,
    required this.contactMethods,
    required this.onContactMethodsChanged,
    required this.contactPhoneController,
    required this.contactWhatsAppController,
    required this.expiry,
    required this.onExpiryChanged,
    this.autoDetectLocation = true,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final LocationModel location;
  final ValueChanged<LocationModel> onLocationChanged;
  final Set<OpportunityContactMethod> contactMethods;
  final ValueChanged<Set<OpportunityContactMethod>> onContactMethodsChanged;
  final TextEditingController contactPhoneController;
  final TextEditingController contactWhatsAppController;
  final OpportunityExpiry expiry;
  final ValueChanged<OpportunityExpiry> onExpiryChanged;
  final bool autoDetectLocation;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel(label: 'Title', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: 'Short, clear headline',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        const _FieldLabel(label: 'Description', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'What are you looking for?',
            border: OutlineInputBorder(),
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        OnboardingLocationSection(
          initialLocation: location,
          onLocationChanged: onLocationChanged,
          autoDetectOnInit: autoDetectLocation,
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        const _FieldLabel(label: 'Contact methods', required: true),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: OpportunityContactMethod.values.map((m) {
            final selected = contactMethods.contains(m);
            return FilterChip(
              avatar: Icon(m.icon, size: 16),
              label: Text(m.label),
              selected: selected,
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
        if (contactMethods.contains(OpportunityContactMethod.phone) ||
            contactMethods.contains(OpportunityContactMethod.whatsapp)) ...[
          const SizedBox(height: AppDimens.spaceMd),
          if (contactMethods.contains(OpportunityContactMethod.phone)) ...[
            const _FieldLabel(label: 'Phone'),
            const SizedBox(height: 6),
            TextFormField(
              controller: contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+94…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                if (!contactMethods.contains(OpportunityContactMethod.phone)) {
                  return null;
                }
                return (v == null || v.trim().isEmpty) ? 'Phone required' : null;
              },
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
          if (contactMethods.contains(OpportunityContactMethod.whatsapp)) ...[
            const _FieldLabel(label: 'WhatsApp'),
            const SizedBox(height: 6),
            TextFormField(
              controller: contactWhatsAppController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+94…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                if (!contactMethods
                    .contains(OpportunityContactMethod.whatsapp)) {
                  return null;
                }
                return (v == null || v.trim().isEmpty)
                    ? 'WhatsApp required'
                    : null;
              },
            ),
          ],
        ],
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
