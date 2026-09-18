import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/series/series.dart';
import '../../../../shared/providers/providers.dart';
import '../../../teams/presentation/utils/team_image_upload.dart';

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
    this.profilePhotoUrl,
    this.nationalIdDocUrl,
    this.passportDocUrl,
    this.onProfilePhotoUrl,
    this.onNationalIdDocUrl,
    this.onPassportDocUrl,
    this.showOptionalEmptyFields = false,
  });

  final SeriesSettingsModel settings;
  final String seriesId;
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

  /// When true, show common fields even if not required (admins filling for a player).
  final bool showOptionalEmptyFields;

  @override
  ConsumerState<SeriesRegistrationFields> createState() =>
      _SeriesRegistrationFieldsState();
}

class _SeriesRegistrationFieldsState
    extends ConsumerState<SeriesRegistrationFields> {
  bool _uploading = false;

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
      final url = await ref.read(storageServiceProvider).uploadSeriesRegistrationImage(
            widget.seriesId,
            file,
            kind: kind,
          );
      onUrl(url);
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
    final showNational = s.requireNationalId || widget.showOptionalEmptyFields;
    final showPassport = s.requirePassport || widget.showOptionalEmptyFields;
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
          TextFormField(
            controller: widget.nationalId,
            decoration: InputDecoration(
              labelText: s.requireNationalId ? 'National ID / ID number *' : 'National ID / ID number',
              helperText: 'Stored privately for organization admins only',
            ),
            validator: (v) => s.requireNationalId &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
          _docTile(
            label: 'National ID document photo',
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
          TextFormField(
            controller: widget.passport,
            decoration: InputDecoration(
              labelText: s.requirePassport ? 'Passport number *' : 'Passport number',
              helperText: 'Stored privately for organization admins only',
            ),
            validator: (v) => s.requirePassport &&
                    (v == null || v.trim().isEmpty)
                ? 'Required'
                : null,
          ),
          _docTile(
            label: 'Passport document photo',
            url: widget.passportDocUrl,
            onPick: () => _uploadDoc(
              kind: 'doc',
              onUrl: widget.onPassportDocUrl,
              title: 'Crop passport page',
            ),
          ),
        ],
      ],
    );
  }
}
