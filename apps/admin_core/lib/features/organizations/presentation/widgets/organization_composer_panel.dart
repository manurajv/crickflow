import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../models/managed_organization.dart';
import '../../providers/organizations_providers.dart';

class OrganizationComposerPanel extends ConsumerStatefulWidget {
  const OrganizationComposerPanel({
    super.key,
    required this.onClose,
    this.existing,
  });

  final VoidCallback onClose;
  final ManagedOrganization? existing;

  @override
  ConsumerState<OrganizationComposerPanel> createState() =>
      _OrganizationComposerPanelState();
}

class _OrganizationComposerPanelState
    extends ConsumerState<OrganizationComposerPanel> {
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _country;
  late final TextEditingController _state;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _logoUrl;
  late final TextEditingController _bannerUrl;
  late final TextEditingController _description;
  late final TextEditingController _registrationNumber;
  late final TextEditingController _establishedYear;
  late ManagedOrganizationType _type;
  late ManagedOrganizationStatus _status;
  bool _busy = false;
  bool _slugTouched = false;
  String? _formError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _website = TextEditingController(text: e?.website ?? '');
    _country = TextEditingController(text: e?.country ?? '');
    _state = TextEditingController(text: e?.stateProvince ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _logoUrl = TextEditingController(text: e?.logoUrl ?? '');
    _bannerUrl = TextEditingController(text: e?.bannerUrl ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _registrationNumber =
        TextEditingController(text: e?.registrationNumber ?? '');
    _establishedYear = TextEditingController(
      text: e?.establishedYear?.toString() ?? '',
    );
    _type = e?.type ?? ManagedOrganizationType.club;
    _status = (e?.status == ManagedOrganizationStatus.deleted ||
            e?.status == ManagedOrganizationStatus.archived)
        ? ManagedOrganizationStatus.active
        : (e?.status ?? ManagedOrganizationStatus.pending);
    _slugTouched = e?.slug.isNotEmpty == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _country.dispose();
    _state.dispose();
    _city.dispose();
    _address.dispose();
    _logoUrl.dispose();
    _bannerUrl.dispose();
    _description.dispose();
    _registrationNumber.dispose();
    _establishedYear.dispose();
    super.dispose();
  }

  ManagedOrganization _draft() {
    final yearText = _establishedYear.text.trim();
    final year = yearText.isNotEmpty ? int.tryParse(yearText) : null;
    return ManagedOrganization(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      slug: _slug.text.trim().isEmpty
          ? ManagedOrganization.slugify(_name.text)
          : _slug.text.trim(),
      type: _type,
      status: _status,
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      website: _website.text.trim(),
      country: _country.text.trim(),
      stateProvince: _state.text.trim(),
      city: _city.text.trim(),
      address: _address.text.trim(),
      logoUrl: _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
      bannerUrl: _bannerUrl.text.trim().isEmpty ? null : _bannerUrl.text.trim(),
      description: _description.text.trim(),
      registrationNumber: _registrationNumber.text.trim(),
      establishedYear: year,
      primaryAdminUid: widget.existing?.primaryAdminUid,
      primaryAdminEmail: widget.existing?.primaryAdminEmail,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Organization name is required');
      return;
    }
    setState(() {
      _formError = null;
      _busy = true;
    });
    try {
      final controller = ref.read(organizationsListControllerProvider.notifier);
      final draft = _draft();
      if (_isEdit) {
        await controller.update(widget.existing!, draft);
      } else {
        await controller.create(draft);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Organization saved' : 'Organization created'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _formError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    _isEdit
                        ? Icons.edit_outlined
                        : Icons.add_business_outlined,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit Organization' : 'Create Organization',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_formError != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: TextStyle(color: colors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _section('Basic Information'),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name *',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    onChanged: (v) {
                      if (!_slugTouched) {
                        setState(
                          () => _slug.text = ManagedOrganization.slugify(v),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _slug,
                    decoration: const InputDecoration(
                      labelText: 'Slug (URL-safe identifier)',
                      prefixIcon: Icon(Icons.link_outlined),
                      helperText: 'Auto-generated from name',
                    ),
                    onChanged: (_) => _slugTouched = true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedOrganizationType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Organization Type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final t in ManagedOrganizationType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedOrganizationStatus>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.toggle_on_outlined),
                    ),
                    items: [
                      for (final s in [
                        ManagedOrganizationStatus.pending,
                        ManagedOrganizationStatus.active,
                        ManagedOrganizationStatus.verified,
                        ManagedOrganizationStatus.inactive,
                        ManagedOrganizationStatus.suspended,
                      ])
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  _section('Description'),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _section('Legal & Identity'),
                  TextField(
                    controller: _registrationNumber,
                    decoration: const InputDecoration(
                      labelText: 'Registration Number',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _establishedYear,
                    decoration: const InputDecoration(
                      labelText: 'Established Year',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _section('Contact'),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _website,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      prefixIcon: Icon(Icons.language_outlined),
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 20),
                  _section('Location'),
                  TextField(
                    controller: _country,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _state,
                    decoration: const InputDecoration(
                      labelText: 'State / Province',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _city,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.place_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  _section('Media'),
                  TextField(
                    controller: _logoUrl,
                    decoration: const InputDecoration(
                      labelText: 'Logo URL',
                      prefixIcon: Icon(Icons.image_outlined),
                      hintText: 'https://…/logo.png',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bannerUrl,
                    decoration: const InputDecoration(
                      labelText: 'Banner URL',
                      prefixIcon: Icon(Icons.panorama_outlined),
                      hintText: 'https://…/banner.png',
                    ),
                  ),
                  const SizedBox(height: 24),
                  CfButton(
                    label: _busy
                        ? 'Saving…'
                        : (_isEdit ? 'Save changes' : 'Create Organization'),
                    icon: _isEdit ? Icons.save_outlined : Icons.add_circle_outline,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.adminColors.textMuted,
        ),
      ),
    );
  }
}
