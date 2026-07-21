import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/community_post_model.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_fields.dart';
import '../community_post_ui.dart';
import 'utils/community_image_crop.dart';

Future<void> showCreateCommunityPostSheet(
  BuildContext context, {
  CommunityPostCategory? initialCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => CreateCommunityPostSheet(initialCategory: initialCategory),
  );
}

class CreateCommunityPostSheet extends ConsumerStatefulWidget {
  const CreateCommunityPostSheet({super.key, this.initialCategory});

  final CommunityPostCategory? initialCategory;

  @override
  ConsumerState<CreateCommunityPostSheet> createState() =>
      _CreateCommunityPostSheetState();
}

class _CreateCommunityPostSheetState
    extends ConsumerState<CreateCommunityPostSheet> {
  final _formKey = GlobalKey<FormState>();
  late CommunityPostKind _kind;
  late CommunityPostCategory _category;
  late LocationModel _location;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<({File file, CommunityMediaAspect aspect})> _pendingMedia = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? CommunityPostCategory.general;
    _kind = _kindFromCategory(_category);
    _location = const LocationModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && !profile.location.isEmpty && mounted) {
        setState(() => _location = profile.location);
      }
    });
  }

  CommunityPostKind _kindFromCategory(CommunityPostCategory c) {
    return switch (c) {
      CommunityPostCategory.tournamentNeed => CommunityPostKind.tournament,
      CommunityPostCategory.team => CommunityPostKind.team,
      CommunityPostCategory.achievement => CommunityPostKind.achievement,
      CommunityPostCategory.match => CommunityPostKind.match,
      _ => CommunityPostKind.general,
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    final result = await pickAndCropCommunityImage(context);
    if (result == null || !mounted) return;
    setState(() {
      _pendingMedia.add(result);
      if (_kind == CommunityPostKind.general) {
        _kind = CommunityPostKind.image;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).valueOrNull;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (user == null || profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to post')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final media = <CommunityMediaItem>[];
      for (final item in _pendingMedia) {
        final url = await storage.uploadCommunityPostImage(
          userId: user.uid,
          file: item.file,
        );
        media.add(CommunityMediaItem(url: url, aspect: item.aspect));
      }

      final category = widget.initialCategory ?? categoryFromPostKind(_kind);
      await ref.read(communityRepositoryProvider).createPost(
            authorId: user.uid,
            authorName: profile.effectiveName,
            authorRole: profile.role.name,
            authorPhotoUrl: profile.photoUrl,
            authorPlayerId: profile.playerId,
            authorVerified: profile.badgeIds.isNotEmpty,
            title: _titleController.text,
            body: _bodyController.text,
            category: category,
            postKind: _kind,
            location: _location,
            media: media,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final cf = context.cf;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        bottom + AppDimens.spaceMd,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create post',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text('Post type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CommunityPostKind.values
                    .where((k) => k != CommunityPostKind.video)
                    .map((k) {
                  final selected = _kind == k;
                  return ChoiceChip(
                    label: Text(communityPostKindLabel(k)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _kind = k;
                        _category = categoryFromPostKind(k);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              if (_kind != CommunityPostKind.image)
                DropdownButtonFormField<CommunityPostCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: CommunityPostCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(communityCategoryLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _category = v;
                        _kind = _kindFromCategory(v);
                      });
                    }
                  },
                ),
              if (_kind != CommunityPostKind.image)
                const SizedBox(height: AppDimens.spaceSm),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: _kind == CommunityPostKind.image
                      ? 'Caption title (optional)'
                      : 'Title',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (_kind == CommunityPostKind.image) return null;
                  return (v == null || v.trim().isEmpty)
                      ? 'Title required'
                      : null;
                },
              ),
              const SizedBox(height: AppDimens.spaceSm),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (_pendingMedia.isNotEmpty) return null;
                  return (v == null || v.trim().isEmpty)
                      ? 'Details required'
                      : null;
                },
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  Text('Photos', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pendingMedia.length >= 6 ? null : _addImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_pendingMedia.isNotEmpty)
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pendingMedia.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final item = _pendingMedia[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              item.file,
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
                                () => _pendingMedia.removeAt(i),
                              ),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: cf.card,
                                child: const Icon(Icons.close, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppDimens.spaceMd),
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimens.spaceXs),
              LocationFields(
                location: _location,
                onChanged: (loc) => setState(() => _location = loc),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
