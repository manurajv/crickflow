import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import 'widgets/onboarding_location_section.dart';
import 'widgets/onboarding_widgets.dart';

class PlayerOnboardingScreen extends ConsumerStatefulWidget {
  const PlayerOnboardingScreen({super.key});

  @override
  ConsumerState<PlayerOnboardingScreen> createState() =>
      _PlayerOnboardingScreenState();
}

class _PlayerOnboardingScreenState extends ConsumerState<PlayerOnboardingScreen> {
  static const _stepCount = 6;

  final _pageController = PageController();
  int _step = 0;
  bool _saving = false;

  File? _photoFile;
  String? _photoUrl;

  final _nameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _jerseyController = TextEditingController();

  String _dialCode = '+94';
  LocationModel _location = const LocationModel();
  DateTime? _dob;
  PlayerGender? _gender;
  PlayerPlayingRole? _playingRole;
  PlayerBattingStyle? _battingStyle;
  PlayerBowlingCategory? _bowlingCategory;
  PlayerBowlingArm? _bowlingArm;
  PlayerBowlingStyle? _bowlingStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null || !mounted) return;

    final profile = await ref.read(userRepositoryProvider).getUser(authUser.uid) ??
        await ref.read(authRepositoryProvider).ensureProfileForAuthUser(authUser);
    if (!mounted) return;
    setState(() {
      _photoUrl = profile.photoUrl;
      _nameController.text = profile.name.isNotEmpty
          ? profile.name
          : profile.displayName;
      _displayNameController.text = profile.displayName;
      _location = profile.location;
      _syncDialCodeFromCountry(_location.country);
      if (profile.effectiveMobile.isNotEmpty) {
        final mobile = profile.effectiveMobile;
        final dial = CricketCountry.all
            .map((c) => c.dialCode)
            .where(mobile.startsWith)
            .fold<String?>(
              null,
              (prev, code) =>
                  prev == null || code.length > prev.length ? code : prev,
            );
        if (dial != null) {
          _dialCode = dial;
          _mobileController.text = mobile.substring(dial.length);
        } else {
          _mobileController.text =
              mobile.replaceFirst(RegExp(r'^\+\d+\s*'), '');
        }
      }
      _dob = profile.dateOfBirth;
      _gender = profile.gender;
      _playingRole = profile.playerRole;
      _battingStyle = profile.battingStyle;
      _bowlingStyle = profile.bowlingStyle;
      if (profile.jerseyNumber != null) {
        _jerseyController.text = '${profile.jerseyNumber}';
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _displayNameController.dispose();
    _mobileController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  double get _progress => (_step + 1) / _stepCount;

  String get _phoneNumberHint {
    return switch (_dialCode) {
      '+94' => '771234567',
      '+91' => '9876543210',
      '+92' => '3001234567',
      '+880' => '1712345678',
      '+44' => '7911123456',
      '+61' => '412345678',
      '+64' => '211234567',
      '+27' => '821234567',
      '+1' => '2025551234',
      '+971' => '501234567',
      _ => '771234567',
    };
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 92);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: AppColors.surface,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop photo', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _photoFile = File(cropped.path);
      _photoUrl = null;
    });
  }

  void _syncDialCodeFromCountry(String countryName) {
    final match = CricketCountry.byName(countryName);
    if (match != null) {
      setState(() => _dialCode = match.dialCode);
    }
  }

  void _onLocationChanged(LocationModel location) {
    setState(() => _location = location);
    _syncDialCodeFromCountry(location.country);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1940),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.gold,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 1:
        final name = _nameController.text.trim();
        if (name.length < 2 || name.length > 50) {
          return 'Full name must be 2–50 characters';
        }
        final mobile = _mobileController.text.trim();
        if (mobile.isNotEmpty &&
            !RegExp(r'^[0-9]{6,14}$').hasMatch(mobile)) {
          return 'Enter a valid mobile number (digits only)';
        }
        return null;
      case 2:
        if (_playingRole == null) return 'Select your playing role';
        return null;
      case 3:
        if (_battingStyle == null) return 'Select your batting style';
        return null;
      case 4:
        if (_bowlingCategory == null) return 'Select bowling type';
        if (_bowlingCategory == PlayerBowlingCategory.spin &&
            _bowlingStyle == null) {
          return 'Select your spin bowling style';
        }
        if (_bowlingCategory != PlayerBowlingCategory.spin &&
            _bowlingCategory != PlayerBowlingCategory.doNotBowl &&
            _bowlingArm == null) {
          return 'Select bowling arm';
        }
        return null;
      case 5:
        final jersey = _jerseyController.text.trim();
        if (jersey.isNotEmpty) {
          final n = int.tryParse(jersey);
          if (n == null || n < 0 || n > 999) {
            return 'Jersey number must be 0–999';
          }
        }
        return null;
      default:
        return null;
    }
  }

  void _next() {
    final error = _validateCurrentStep();
    if (error != null) {
      _showValidationError(error);
      return;
    }
    if (_step < _stepCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      setState(() => _step++);
      return;
    }
    _complete();
  }

  void _back() {
    if (_step == 0) {
      context.go('/home');
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    setState(() => _step--);
  }

  Future<void> _complete() async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;

    setState(() => _saving = true);
    try {
      var profile = await ref.read(userRepositoryProvider).getUser(authUser.uid);
      profile ??=
          await ref.read(authRepositoryProvider).ensureProfileForAuthUser(authUser);

      String? photoUrl = _photoUrl;
      if (_photoFile != null) {
        photoUrl = await ref
            .read(storageServiceProvider)
            .uploadUserProfilePhoto(authUser.uid, _photoFile!);
      }

      final name = _nameController.text.trim();
      final displayName = _displayNameController.text.trim();
      final mobileRaw = _mobileController.text.trim();
      final mobile = mobileRaw.isEmpty ? null : '$_dialCode$mobileRaw';

      PlayerBowlingStyle? resolvedBowling = _bowlingStyle;
      if (_bowlingCategory == PlayerBowlingCategory.doNotBowl) {
        resolvedBowling = PlayerBowlingStyle.doNotBowl;
      } else if (_bowlingCategory != null &&
          _bowlingCategory != PlayerBowlingCategory.spin &&
          _bowlingArm != null) {
        resolvedBowling = PlayerBowlingStyleLabels.fromCategoryAndArm(
          category: _bowlingCategory!,
          arm: _bowlingArm!,
        );
      }

      final jersey = _jerseyController.text.trim();
      final jerseyNumber = jersey.isEmpty ? null : int.parse(jersey);

      final cricketCountry = CricketCountry.byName(_location.country);

      final updated = profile.copyWith(
        name: name,
        displayName: displayName.isNotEmpty ? displayName : name,
        mobile: mobile,
        phoneNumber: mobile,
        photoUrl: photoUrl,
        country: _location.country,
        countryCode: cricketCountry?.code ?? profile.countryCode,
        countryFlag: cricketCountry?.flag ?? profile.countryFlag,
        location: _location,
        dateOfBirth: _dob,
        gender: _gender,
        playerRole: _playingRole,
        battingStyle: _battingStyle,
        bowlingStyle: resolvedBowling,
        jerseyNumber: jerseyNumber,
      );

      final saved = await ref
          .read(userRepositoryProvider)
          .completeOnboarding(updated);

      await ref.read(playerRepositoryProvider).ensurePlayerProfileForUser(
            userId: authUser.uid,
            displayName: saved.displayName,
            fullName: saved.name,
            photoUrl: photoUrl,
            email: saved.email,
            playerId: saved.playerId,
          );

      final player =
          await ref.read(playerRepositoryProvider).getPlayerByUserId(authUser.uid);
      if (player != null) {
        await ref.read(playerRepositoryProvider).updatePlayer(
              player.copyWith(
                name: saved.displayName,
                fullName: saved.name,
                photoUrl: photoUrl,
                role: _playingRole?.label ?? player.role,
                battingStyle: _battingStyle?.label ?? player.battingStyle,
                bowlingStyle: resolvedBowling?.label ?? player.bowlingStyle,
                jerseyNumber: jerseyNumber,
                location: saved.location,
                playerId: saved.playerId,
              ),
            );
      }

      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      await PendingAuthAction.runIfAny(ref, context);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (mounted) {
        _showValidationError('Could not save profile: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : _back,
        ),
        title: const Text('Player profile'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: OnboardingProgressHeader(
            step: _step,
            stepCount: _stepCount,
            progress: _progress,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _photoStep(),
                _basicDetailsStep(),
                _roleStep(),
                _battingStep(),
                _bowlingStep(),
                _jerseyStep(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppDimens.cardPadding,
              child: CfButton(
                label: _step == _stepCount - 1 ? 'Finish' : 'Save & Continue',
                isGold: true,
                isLoading: _saving,
                onPressed: _saving ? null : _next,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoStep() {
    ImageProvider? image;
    if (_photoFile != null) {
      image = FileImage(_photoFile!);
    } else if (_photoUrl != null) {
      image = CachedNetworkImageProvider(_photoUrl!);
    }

    return OnboardingStepCard(
      title: 'Profile photo',
      subtitle: 'Optional — shown on your public player profile.',
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: image != null
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : AppColors.border,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.surface,
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person, size: 64, color: AppColors.textMuted)
                  : null,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _basicDetailsStep() {
    return OnboardingStepCard(
      title: 'Basic details',
      subtitle: 'Tell us about yourself. Fields marked * are required.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name *',
              helperText: '2–50 characters',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              helperText: 'Used on scorecards (optional)',
              prefixIcon: Icon(Icons.sports_cricket_outlined),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          OnboardingLocationSection(
            initialLocation: _location,
            onLocationChanged: _onLocationChanged,
            locationService: ref.read(googleMapsLocationServiceProvider),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: Builder(
                  builder: (context) {
                    final dialCodes = [...CricketCountry.phoneDialCodes];
                    if (!dialCodes.contains(_dialCode)) {
                      dialCodes.insert(0, _dialCode);
                    }
                    return DropdownButtonFormField<String>(
                      value: _dialCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      items: dialCodes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _dialCode = v);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: _phoneNumberHint,
                    helperText: 'Optional — digits only',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                helperText: 'Optional — for age-group tournaments',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(
                _dob == null
                    ? 'Select date'
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(
                  color: _dob == null ? AppColors.textMuted : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text('Gender', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PlayerGender.values.map((g) {
              return OnboardingChoiceChip(
                label: g.label,
                selected: _gender == g,
                onSelected: () => setState(() => _gender = g),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _roleStep() {
    return OnboardingStepCard(
      title: 'Playing role *',
      subtitle: 'How do you primarily contribute on the field?',
      child: Column(
        children: PlayerPlayingRole.values
            .map(
              (r) => OnboardingRadioTile<PlayerPlayingRole>(
                value: r,
                groupValue: _playingRole,
                title: r.label,
                onChanged: (v) => setState(() => _playingRole = v),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _battingStep() {
    return OnboardingStepCard(
      title: 'Batting style *',
      child: Column(
        children: PlayerBattingStyle.values
            .map(
              (s) => OnboardingRadioTile<PlayerBattingStyle>(
                value: s,
                groupValue: _battingStyle,
                title: s.label,
                onChanged: (v) => setState(() => _battingStyle = v),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _bowlingStep() {
    return OnboardingStepCard(
      title: 'Bowling style *',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Type', style: Theme.of(context).textTheme.titleSmall),
          ...PlayerBowlingCategory.values.map(
            (c) => OnboardingRadioTile<PlayerBowlingCategory>(
              value: c,
              groupValue: _bowlingCategory,
              title: c.label,
              onChanged: (v) => setState(() {
                _bowlingCategory = v;
                _bowlingArm = null;
                _bowlingStyle = v == PlayerBowlingCategory.doNotBowl
                    ? PlayerBowlingStyle.doNotBowl
                    : null;
              }),
            ),
          ),
          if (_bowlingCategory != null &&
              _bowlingCategory != PlayerBowlingCategory.spin &&
              _bowlingCategory != PlayerBowlingCategory.doNotBowl) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Text('Arm', style: Theme.of(context).textTheme.titleSmall),
            ...PlayerBowlingArm.values.map(
              (a) => OnboardingRadioTile<PlayerBowlingArm>(
                value: a,
                groupValue: _bowlingArm,
                title: a.label,
                onChanged: (v) => setState(() => _bowlingArm = v),
              ),
            ),
          ],
          if (_bowlingCategory == PlayerBowlingCategory.spin) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Text('Spin style', style: Theme.of(context).textTheme.titleSmall),
            Text('Right arm', style: Theme.of(context).textTheme.labelLarge),
            ...PlayerBowlingStyleLabels.spinStylesForArm(PlayerBowlingArm.rightArm)
                .map(
              (s) => OnboardingRadioTile<PlayerBowlingStyle>(
                value: s,
                groupValue: _bowlingStyle,
                title: s.label,
                onChanged: (v) => setState(() => _bowlingStyle = v),
              ),
            ),
            Text('Left arm', style: Theme.of(context).textTheme.labelLarge),
            ...PlayerBowlingStyleLabels.spinStylesForArm(PlayerBowlingArm.leftArm)
                .map(
              (s) => OnboardingRadioTile<PlayerBowlingStyle>(
                value: s,
                groupValue: _bowlingStyle,
                title: s.label,
                onChanged: (v) => setState(() => _bowlingStyle = v),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _jerseyStep() {
    return OnboardingStepCard(
      title: 'Jersey number',
      subtitle: 'Optional — 0 to 999',
      child: TextField(
        controller: _jerseyController,
        decoration: const InputDecoration(
          labelText: 'Jersey number',
          hintText: 'e.g. 7, 18, 333',
          prefixIcon: Icon(Icons.numbers_outlined),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
      ),
    );
  }
}
