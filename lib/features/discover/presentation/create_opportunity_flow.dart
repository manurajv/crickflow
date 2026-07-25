import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/opportunity_post_model.dart';
import '../../../shared/providers/opportunity_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../community/presentation/utils/community_image_crop.dart';
import '../domain/opportunity_category.dart';
import '../domain/opportunity_field_schema.dart';
import 'widgets/opportunity_dynamic_form.dart';
import 'widgets/opportunity_post_card.dart';

Future<void> showCreateOpportunityFlow(
  BuildContext context, {
  OpportunityCategory? initialCategory,
  OpportunityPostModel? editingPost,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CreateOpportunityFlow(
      initialCategory: initialCategory,
      editingPost: editingPost,
    ),
  );
}

Future<void> showEditOpportunityFlow(
  BuildContext context,
  OpportunityPostModel post,
) {
  return showCreateOpportunityFlow(context, editingPost: post);
}

class CreateOpportunityFlow extends ConsumerStatefulWidget {
  const CreateOpportunityFlow({
    super.key,
    this.initialCategory,
    this.editingPost,
  });

  final OpportunityCategory? initialCategory;
  final OpportunityPostModel? editingPost;

  @override
  ConsumerState<CreateOpportunityFlow> createState() =>
      _CreateOpportunityFlowState();
}

class _CreateOpportunityFlowState extends ConsumerState<CreateOpportunityFlow> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsAppController = TextEditingController();

  int _step = 0;
  OpportunityCategory? _category;
  LocationModel _location = const LocationModel();
  Map<String, dynamic> _fields = {};
  Set<OpportunityContactMethod> _contactMethods = {
    OpportunityContactMethod.chat,
  };
  OpportunityExpiry _expiry = OpportunityExpiry.sevenDays;
  bool _publishing = false;
  bool _whatsAppSameAsPhone = true;
  final List<File> _pendingImages = [];
  final List<String> _existingMediaUrls = [];

  bool get _isEditing => widget.editingPost != null;

  String get _profilePhone {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    return profile?.effectiveMobile.trim() ?? '';
  }

  /// Number used when WhatsApp is "same as phone".
  String get _whatsAppSourceNumber {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) return phone;
    return _profilePhone;
  }

  void _onContactMethodsChanged(Set<OpportunityContactMethod> next) {
    setState(() {
      if (next.contains(OpportunityContactMethod.phone) &&
          _phoneController.text.trim().isEmpty &&
          _profilePhone.isNotEmpty) {
        _phoneController.text = _profilePhone;
      }
      if (next.contains(OpportunityContactMethod.whatsapp) &&
          _whatsAppSameAsPhone) {
        _whatsAppController.text = _whatsAppSourceNumber;
      }
      _contactMethods = next;
    });
  }

  String _resolvedWhatsApp() {
    if (!_contactMethods.contains(OpportunityContactMethod.whatsapp)) {
      return '';
    }
    if (_whatsAppSameAsPhone) return _whatsAppSourceNumber;
    return _whatsAppController.text.trim();
  }

  String _resolvedPhone() {
    if (!_contactMethods.contains(OpportunityContactMethod.phone)) {
      return '';
    }
    return _phoneController.text.trim();
  }

  bool get _supportsImages => _category == OpportunityCategory.findGround;

  int get _mediaCount => _existingMediaUrls.length + _pendingImages.length;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingPost;
    if (editing != null) {
      _category = editing.category;
      _step = 1;
      _titleController.text = editing.category.fixedTitle;
      _descriptionController.text = editing.description;
      _location = editing.location;
      _fields = Map<String, dynamic>.from(editing.fields);
      _contactMethods = editing.contactMethods.isEmpty
          ? {OpportunityContactMethod.chat}
          : editing.contactMethods.toSet();
      _phoneController.text = editing.contactPhone;
      _whatsAppController.text = editing.contactWhatsApp;
      final phone = editing.contactPhone.trim();
      final wa = editing.contactWhatsApp.trim();
      _whatsAppSameAsPhone =
          wa.isEmpty || phone.isNotEmpty && wa == phone;
      _expiry = OpportunityExpiry.values.firstWhere(
        (e) => e.days == editing.expiryDays,
        orElse: () => OpportunityExpiry.sevenDays,
      );
      _existingMediaUrls.addAll(editing.mediaUrls);
      return;
    }
    _category = widget.initialCategory;
    if (_category != null && !_category!.isCreatable && !_isEditing) {
      _category = null;
    }
    if (_category != null) {
      _step = 1;
      _titleController.text = _category!.fixedTitle;
    }
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null && !profile.location.isEmpty) {
      _location = profile.location;
    }
    final mobile = profile?.effectiveMobile.trim() ?? '';
    if (mobile.isNotEmpty) {
      _phoneController.text = mobile;
      _whatsAppController.text = mobile;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step == 0) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose what you are looking for')),
        );
        return;
      }
      _titleController.text = _category!.fixedTitle;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _formKey.currentState?.save();
      for (final def in OpportunityFieldSchema.fieldsFor(_category!)) {
        if (!def.required) continue;
        final v = _fields[def.key];
        if (v == null ||
            (v is String && v.trim().isEmpty) ||
            (v is List && v.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${def.label} is required')),
          );
          return;
        }
      }
      setState(() => _step = 2);
    }
  }

  Future<void> _publish() async {
    final category = _category;
    if (category == null) return;

    await requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final profile = ref.read(currentUserProfileProvider).valueOrNull ??
            await ref.read(currentUserProfileProvider.future);
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (profile == null || uid == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to publish')),
            );
          }
          return;
        }

        final editing = widget.editingPost;
        if (editing != null && editing.authorId != uid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only edit your own posts')),
            );
          }
          return;
        }

        setState(() => _publishing = true);
        try {
          final mediaUrls = List<String>.from(_existingMediaUrls);
          if (_pendingImages.isNotEmpty) {
            final storage = ref.read(storageServiceProvider);
            for (final file in _pendingImages) {
              final url = await storage.uploadOpportunityImage(
                userId: uid,
                file: file,
              );
              mediaUrls.add(url);
            }
          }

          final repo = ref.read(opportunityRepositoryProvider);
          final title = category.fixedTitle;
          _titleController.text = title;
          if (editing != null) {
            await repo.updatePost(
              postId: editing.id,
              title: title,
              description: _descriptionController.text.trim(),
              location: _location,
              fields: _fields,
              contactMethods: _contactMethods.toList(),
              contactPhone: _resolvedPhone(),
              contactWhatsApp: _resolvedWhatsApp(),
              mediaUrls: mediaUrls,
            );
          } else {
            await repo.createPost(
              authorId: uid,
              authorName: profile.effectiveName,
              authorPhotoUrl: profile.photoUrl,
              authorPlayerId: profile.playerId,
              authorVerified:
                  profile.playerId != null && profile.playerId!.isNotEmpty,
              category: category,
              title: title,
              description: _descriptionController.text.trim(),
              location: _location,
              fields: _fields,
              contactMethods: _contactMethods.toList(),
              contactPhone: _resolvedPhone(),
              contactWhatsApp: _resolvedWhatsApp(),
              expiryDays: _expiry.days,
              mediaUrls: mediaUrls,
            );
          }
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing ? 'Opportunity updated' : 'Opportunity published',
              ),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditing
                      ? 'Could not update: $e'
                      : 'Could not publish: $e',
                ),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _publishing = false);
        }
      },
    );
  }

  OpportunityPostModel _previewPost() {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final editing = widget.editingPost;
    return OpportunityPostModel(
      id: editing?.id ?? 'preview',
      authorId: editing?.authorId ?? profile?.id ?? '',
      authorName: editing?.authorName ?? profile?.effectiveName ?? 'You',
      authorPhotoUrl: editing?.authorPhotoUrl ?? profile?.photoUrl,
      authorPlayerId: editing?.authorPlayerId ?? profile?.playerId,
      authorVerified: editing?.authorVerified ??
          (profile?.playerId != null && profile!.playerId!.isNotEmpty),
      category: _category ?? OpportunityCategory.findPlayer,
      title: _titleController.text.trim().isEmpty
          ? (_category?.fixedTitle ?? 'Your title')
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'Your description'
          : _descriptionController.text.trim(),
      location: _location,
      fields: _fields,
      contactMethods: _contactMethods.toList(),
      contactPhone: _resolvedPhone(),
      contactWhatsApp: _resolvedWhatsApp(),
      expiryDays: _expiry.days,
      mediaUrls: _existingMediaUrls,
      createdAt: editing?.createdAt ?? DateTime.now(),
      viewCount: editing?.viewCount ?? 0,
      isPinned: editing?.isPinned ?? false,
      isFeatured: editing?.isFeatured ?? false,
    );
  }

  void _onBack() {
    if (_publishing) return;
    if (_step <= (_isEditing ? 1 : 0)) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final showBack = _step > (_isEditing ? 1 : 0);
    final stepLabel = switch (_step) {
      0 => 'What are you looking for?',
      1 => _isEditing ? 'Edit details' : 'Post details',
      _ => _isEditing ? 'Preview & save' : 'Preview & publish',
    };
    final totalSteps = _isEditing ? 2 : 3;
    final progressStep = _isEditing ? (_step - 1) : _step;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              0,
              AppDimens.spaceLg,
              AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _publishing ? null : _onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Text(
                    stepLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${progressStep + 1}/$totalSteps',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cf.textMuted,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: (progressStep + 1) / totalSteps,
            minHeight: 2,
            backgroundColor: cf.border.withValues(alpha: 0.4),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_step) {
                0 => _CategoryStep(
                    key: const ValueKey(0),
                    selected: _category,
                    onSelected: (c) => setState(() {
                      if (_category != c) {
                        _fields = {};
                        _pendingImages.clear();
                        _existingMediaUrls.clear();
                      }
                      _category = c;
                      _titleController.text = c.fixedTitle;
                    }),
                  ),
                1 => Form(
                    key: _formKey,
                    child: ListView(
                      key: const ValueKey(1),
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      children: [
                        if (_category != null)
                          OpportunityCommonFields(
                            category: _category!,
                            descriptionController: _descriptionController,
                            location: _location,
                            onLocationChanged: (loc) =>
                                setState(() => _location = loc),
                            contactMethods: _contactMethods,
                            onContactMethodsChanged: _onContactMethodsChanged,
                            contactPhoneController: _phoneController,
                            contactWhatsAppController: _whatsAppController,
                            whatsAppSameAsPhone: _whatsAppSameAsPhone,
                            onWhatsAppSameAsPhoneChanged: (same) {
                              setState(() {
                                _whatsAppSameAsPhone = same;
                                if (same) {
                                  _whatsAppController.text =
                                      _whatsAppSourceNumber;
                                }
                              });
                            },
                            profilePhone: _profilePhone,
                            expiry: _expiry,
                            onExpiryChanged: (e) =>
                                setState(() => _expiry = e),
                            showExpiry: !_isEditing,
                          ),
                        const SizedBox(height: AppDimens.spaceLg),
                        Text(
                          _category?.detailsSectionTitle ?? 'Details',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        if (_category != null)
                          OpportunityDynamicForm(
                            category: _category!,
                            values: _fields,
                            onChanged: (v) => setState(() => _fields = v),
                          ),
                        if (_supportsImages) ...[
                          const SizedBox(height: AppDimens.spaceLg),
                          Text(
                            'Ground images',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Up to 4 photos · 16:9 crop · shown as a swipeable gallery',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cf.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0;
                                  i < _existingMediaUrls.length;
                                  i++)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 120,
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            _existingMediaUrls[i],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                              color: cf.sectionBackground,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                                color: cf.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _existingMediaUrls.removeAt(i),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              for (var i = 0; i < _pendingImages.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 120,
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.file(
                                            _pendingImages[i],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: InkWell(
                                        onTap: () => setState(
                                          () => _pendingImages.removeAt(i),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_mediaCount < 4)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await pickAndCropCommunityImage(
                                      context,
                                      fixedAspect:
                                          CommunityMediaAspect.landscape16x9,
                                    );
                                    if (picked == null || !mounted) return;
                                    setState(
                                      () => _pendingImages.add(picked.file),
                                    );
                                  },
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined),
                                  label: const Text('Add photo'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                _ => ListView(
                    key: const ValueKey(2),
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    children: [
                      Text(
                        'This is how your post will appear',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      OpportunityPostCard(
                        post: _previewPost(),
                        previewMode: true,
                      ),
                    ],
                  ),
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                AppDimens.spaceSm,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppDimens.buttonHeightLarge,
                child: FilledButton(
                  onPressed:
                      _publishing ? null : (_step < 2 ? _goNext : _publish),
                  child: _publishing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _step < 2
                              ? 'Continue'
                              : (_isEditing ? 'Save changes' : 'Publish'),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final OpportunityCategory? selected;
  final ValueChanged<OpportunityCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      itemCount: OpportunityCategoryX.creatableCategories.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: AppDimens.spaceMd) : const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(
            'Pick the option that matches who you are and what you need. '
            'Your post title is set automatically. '
            'Tournaments belong in Community.',
            style: theme.textTheme.bodySmall?.copyWith(color: cf.textSecondary),
          );
        }
        final c = OpportunityCategoryX.creatableCategories[i - 1];
        final isOn = selected == c;
        return Material(
          color: isOn
              ? c.badgeColor.withValues(alpha: 0.12)
              : cf.sectionBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: InkWell(
            onTap: () => onSelected(c),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(
                  color: isOn ? c.badgeColor : cf.border,
                  width: isOn ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.icon, size: 24, color: c.badgeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.lookingForLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Post as: ${c.posterRole}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cf.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.createSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOn)
                    Icon(Icons.check_circle, color: c.badgeColor, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
