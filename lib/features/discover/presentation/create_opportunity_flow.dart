import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_gate.dart';
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CreateOpportunityFlow(initialCategory: initialCategory),
  );
}

class CreateOpportunityFlow extends ConsumerStatefulWidget {
  const CreateOpportunityFlow({super.key, this.initialCategory});

  final OpportunityCategory? initialCategory;

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
  final List<File> _pendingImages = [];

  bool get _supportsImages =>
      _category == OpportunityCategory.findGround ||
      _category == OpportunityCategory.findTournament;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (_category != null) _step = 1;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null && !profile.location.isEmpty) {
      _location = profile.location;
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
          const SnackBar(content: Text('Choose a category')),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
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

        setState(() => _publishing = true);
        try {
          final mediaUrls = <String>[];
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
          await ref.read(opportunityRepositoryProvider).createPost(
                authorId: uid,
                authorName: profile.effectiveName,
                authorPhotoUrl: profile.photoUrl,
                authorPlayerId: profile.playerId,
                authorVerified:
                    profile.playerId != null && profile.playerId!.isNotEmpty,
                category: category,
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                location: _location,
                fields: _fields,
                contactMethods: _contactMethods.toList(),
                contactPhone: _phoneController.text.trim(),
                contactWhatsApp: _whatsAppController.text.trim(),
                expiryDays: _expiry.days,
                mediaUrls: mediaUrls,
              );
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opportunity published')),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not publish: $e')),
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
    return OpportunityPostModel(
      id: 'preview',
      authorId: profile?.id ?? '',
      authorName: profile?.effectiveName ?? 'You',
      authorPhotoUrl: profile?.photoUrl,
      authorPlayerId: profile?.playerId,
      authorVerified:
          profile?.playerId != null && profile!.playerId!.isNotEmpty,
      category: _category ?? OpportunityCategory.findPlayer,
      title: _titleController.text.trim().isEmpty
          ? 'Your title'
          : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? 'Your description'
          : _descriptionController.text.trim(),
      location: _location,
      fields: _fields,
      contactMethods: _contactMethods.toList(),
      contactPhone: _phoneController.text.trim(),
      contactWhatsApp: _whatsAppController.text.trim(),
      expiryDays: _expiry.days,
      createdAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.92;

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
                if (_step > 0)
                  IconButton(
                    tooltip: 'Back',
                    onPressed:
                        _publishing ? null : () => setState(() => _step -= 1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Text(
                    switch (_step) {
                      0 => 'Choose category',
                      1 => 'Post details',
                      _ => 'Preview & publish',
                    },
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_step + 1}/3',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cf.textMuted,
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: (_step + 1) / 3,
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
                      }
                      _category = c;
                    }),
                  ),
                1 => Form(
                    key: _formKey,
                    child: ListView(
                      key: const ValueKey(1),
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      children: [
                        if (_category != null) ...[
                          Row(
                            children: [
                              Icon(_category!.icon, color: cf.accent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _category!.chipLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cf.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.spaceLg),
                        ],
                        OpportunityCommonFields(
                          titleController: _titleController,
                          descriptionController: _descriptionController,
                          location: _location,
                          onLocationChanged: (loc) =>
                              setState(() => _location = loc),
                          contactMethods: _contactMethods,
                          onContactMethodsChanged: (m) =>
                              setState(() => _contactMethods = m),
                          contactPhoneController: _phoneController,
                          contactWhatsAppController: _whatsAppController,
                          expiry: _expiry,
                          onExpiryChanged: (e) => setState(() => _expiry = e),
                          autoDetectLocation: _location.isEmpty,
                        ),
                        const SizedBox(height: AppDimens.spaceLg),
                        Text(
                          'Details',
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
                            _category == OpportunityCategory.findTournament
                                ? 'Tournament poster'
                                : 'Ground images',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < _pendingImages.length; i++)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _pendingImages[i],
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.cover,
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
                              if (_pendingImages.length < 4)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await pickAndCropCommunityImage(
                                      context,
                                    );
                                    if (picked == null || !mounted) return;
                                    setState(
                                      () => _pendingImages.add(picked.file),
                                    );
                                  },
                                  icon: const Icon(Icons.add_photo_alternate_outlined),
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
                      : Text(_step < 2 ? 'Continue' : 'Publish'),
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
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemCount: OpportunityCategory.values.length,
      itemBuilder: (context, i) {
        final c = OpportunityCategory.values[i];
        final isOn = selected == c;
        return Material(
          color: isOn
              ? c.badgeColor.withValues(alpha: 0.15)
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(c.icon, size: 22, color: c.badgeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.chipLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
