import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_model.dart';
import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_fields.dart';
import '../community_post_ui.dart';

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
  late CommunityPostCategory _category;
  late LocationModel _location;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? CommunityPostCategory.general;
    _location = const LocationModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && !profile.location.isEmpty && mounted) {
        setState(() => _location = profile.location);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
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
      await ref.read(communityRepositoryProvider).createPost(
            authorId: user.uid,
            authorName: profile.displayName,
            authorRole: profile.role.name,
            title: _titleController.text,
            body: _bodyController.text,
            category: _category,
            location: _location,
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
                'New post',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceMd),
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
                  if (v != null) setState(() => _category = v);
                },
              ),
              const SizedBox(height: AppDimens.spaceSm),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title required' : null,
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Details required' : null,
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
