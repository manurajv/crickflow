import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/atomic_create.dart';
import '../../../../data/models/series/series.dart';
import '../../../../shared/providers/providers.dart';
import '../../../teams/presentation/utils/team_image_upload.dart';

/// Tracks uploads so a failed submit can delete them (no orphan files).
class SeriesRegistrationUploadSession {
  final List<UploadedAsset> assets = [];
  bool committed = false;

  void add(UploadedAsset asset) => assets.add(asset);

  Future<void> rollback() async {
    if (committed) return;
    for (final asset in assets.reversed) {
      try {
        await asset.delete();
      } catch (_) {}
    }
    assets.clear();
  }

  void markCommitted() => committed = true;
}

/// Shared Orgs registration / add-player identity fields driven by [SeriesSettingsModel].
class SeriesRegistrationFields extends ConsumerStatefulWidget {
  const SeriesRegistrationFields({
    super.key,
    required this.settings,
    required this.seriesId,
    required this.fullName,
    required this.playerId,
    required this.phone,
    required this.address,
    required this.nationalId,
    required this.passport,
    required this.dob,
    required this.onDobChanged,
    this.clubId,
    this.subjectUserId,
    this.uploadSession,
    this.profilePhotoUrl,
    this.nationalIdDocUrl,
    this.passportDocUrl,
    this.onProfilePhotoUrl,
    this.onNationalIdDocUrl,
    this.onPassportDocUrl,
    this.customFieldValues,
    this.onCustomFieldsChanged,
    this.showOptionalEmptyFields = false,
  });

  final SeriesSettingsModel settings;
  final String seriesId;
  final String? clubId;
  final String? subjectUserId;
  final SeriesRegistrationUploadSession? uploadSession;
  final TextEditingController fullName;
  final TextEditingController playerId;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController nationalId;
  final TextEditingController passport;
  final DateTime? dob;
  final ValueChanged<DateTime?> onDobChanged;
  final String? profilePhotoUrl;
  final String? nationalIdDocUrl;
  final String? passportDocUrl;
  final ValueChanged<String?>? onProfilePhotoUrl;
  final ValueChanged<String?>? onNationalIdDocUrl;
  final ValueChanged<String?>? onPassportDocUrl;
  final Map<String, String>? customFieldValues;
  final ValueChanged<Map<String, String>>? onCustomFieldsChanged;

  /// When true, show common fields even if not required (admins filling for a player).
  final bool showOptionalEmptyFields;

  @override
  ConsumerState<SeriesRegistrationFields> createState() =>
      _SeriesRegistrationFieldsState();
}

class _SeriesRegistrationFieldsState
    extends ConsumerState<SeriesRegistrationFields> {
  bool _uploading = false;
  final Map<String, TextEditingController> _custom = {};

  @override
  void initState() {
    super.initState();
    _syncCustomControllers();
  }

  @override
  void didUpdateWidget(covariant SeriesRegistrationFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCustomControllers();
  }

  @override
  void dispose() {
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncCustomControllers() {
    final keys = widget.settings.customRequiredFields;
    for (final key in keys) {
      if (_custom.containsKey(key)) continue;
      _custom[key] = TextEditingController(
        text: widget.customFieldValues?[key] ?? '',
      );
    }
  }

  void _emitCustom() {
    widget.onCustomFieldsChanged?.call({
      for (final e in _custom.entries) e.key: e.value.text.trim(),
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) widget.onDobChanged(picked);
  }

  Future<void> _uploadDoc({
    required String kind,
    required ValueChanged<String?>? onUrl,
    required String title,
  }) async {
    if (onUrl == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await pickAndCropTeamImage(
      context,
      kind: TeamImageKind.profile,
      source: source,
      cropTitle: title,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final asset = await ref
          .read(storageServiceProvider)
          .uploadSeriesRegistrationImageAsset(
            widget.seriesId,
            file,
            kind: kind,
            clubId: widget.clubId,
            subjectUserId: widget.subjectUserId,
          );
      widget.uploadSession?.add(asset);
      onUrl(asset.url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload image. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _docTile({
    required String label,
    required String? url,
    required VoidCallback onPick,
  }) {
    final cf = context.cf;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: url == null
          ? Icon(Icons.upload_file_outlined, color: cf.accent)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, width: 44, height: 44, fit: BoxFit.cover),
            ),
      title: Text(label),
      subtitle: Text(url == null ? 'Tap to upload a clear photo' : 'Photo attached'),
      trailing: _uploading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(url == null ? Icons.add_a_photo_outlined : Icons.check_circle,
              color: url == null ? cf.textSecondary : Colors.green),
      onTap: _uploading ? null : onPick,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final showName = s.requireFullName || widget.showOptionalEmptyFields;
    final showPlayerId =
        s.requireCrickFlowPlayerId || widget.showOptionalEmptyFields;
    final showPhone = s.requirePhoneNumber || widget.showOptionalEmptyFields;
    final showDob = s.requireDateOfBirth || widget.showOptionalEmptyFields;
    final showAddress = s.requireAddress || widget.showOptionalEmptyFields;
    final showNational = s.requireNationalId ||
        s.requireNationalIdDocument ||
        widget.showOptionalEmptyFields;
    final showPassport = s.requirePassport ||
        s.requirePassportDocument ||
        widget.showOptionalEmptyFields;
    final showPhoto = s.requireProfilePhoto || widget.showOptionalEmptyFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showName)
          TextFormField(
            controller: widget.fullName,
            decoration: InputDecoration(
              labelText: s.requireFullName ? 'Full name *' : 'Full name',
            ),
            validator: (v) => s.requireFullName &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
        if (showPlayerId) ...[
          const SizedBox(height: AppDimens.spaceMd),
          TextFormField(
            controller: widget.playerId,
            decoration: InputDecoration(
              labelText: s.requireCrickFlowPlayerId
                  ? 'CrickFlow Player ID *'
                  : 'CrickFlow Player ID',
            ),
            validator: (v) => s.requireCrickFlowPlayerId &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
        ],
        if (showPhone) ...[
          const SizedBox(height: AppDimens.spaceMd),
          TextFormField(
            controller: widget.phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: s.requirePhoneNumber ? 'Phone number *' : 'Phone number',
            ),
            validator: (v) => s.requirePhoneNumber &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
        ],
        if (showDob) ...[
          const SizedBox(height: AppDimens.spaceMd),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              widget.dob == null
                  ? (s.requireDateOfBirth ? 'Date of birth *' : 'Date of birth')
                  : 'DOB: ${widget.dob!.toIso8601String().split('T').first}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDob,
          ),
        ],
        if (showAddress) ...[
          const SizedBox(height: AppDimens.spaceMd),
          TextFormField(
            controller: widget.address,
            decoration: InputDecoration(
              labelText: s.requireAddress ? 'Address *' : 'Address',
            ),
            validator: (v) => s.requireAddress &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
        ],
        if (showPhoto) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _docTile(
            label: s.requireProfilePhoto ? 'Profile photo *' : 'Profile photo',
            url: widget.profilePhotoUrl,
            onPick: () => _uploadDoc(
              kind: 'photo',
              onUrl: widget.onProfilePhotoUrl,
              title: 'Crop profile photo',
            ),
          ),
        ],
        if (showNational) ...[
          const SizedBox(height: AppDimens.spaceMd),
          if (s.requireNationalId || widget.showOptionalEmptyFields)
            TextFormField(
              controller: widget.nationalId,
              decoration: InputDecoration(
                labelText: s.requireNationalId
                    ? 'National ID / ID number *'
                    : 'National ID / ID number',
                helperText: 'Stored privately for organization and team admins',
              ),
              validator: (v) => s.requireNationalId &&
                      (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
          _docTile(
            label: s.requireNationalIdDocument
                ? 'National ID document photo *'
                : 'National ID document photo',
            url: widget.nationalIdDocUrl,
            onPick: () => _uploadDoc(
              kind: 'doc',
              onUrl: widget.onNationalIdDocUrl,
              title: 'Crop ID document',
            ),
          ),
        ],
        if (showPassport) ...[
          const SizedBox(height: AppDimens.spaceMd),
          if (s.requirePassport || widget.showOptionalEmptyFields)
            TextFormField(
              controller: widget.passport,
              decoration: InputDecoration(
                labelText: s.requirePassport
                    ? 'Passport number *'
                    : 'Passport number',
                helperText: 'Stored privately for organization and team admins',
              ),
              validator: (v) => s.requirePassport &&
                      (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
          _docTile(
            label: s.requirePassportDocument
                ? 'Passport document photo *'
                : 'Passport document photo',
            url: widget.passportDocUrl,
            onPick: () => _uploadDoc(
              kind: 'doc',
              onUrl: widget.onPassportDocUrl,
              title: 'Crop passport page',
            ),
          ),
        ],
        for (final key in s.customRequiredFields) ...[
          const SizedBox(height: AppDimens.spaceMd),
          TextFormField(
            controller: _custom[key],
            decoration: InputDecoration(labelText: '$key *'),
            onChanged: (_) => _emitCustom(),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ],
    );
  }
}
