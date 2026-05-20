import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_setup_draft_models.dart';
import '../../../shared/widgets/cf_underlined_field.dart';

/// Add or edit one match official by name and email.
class AddMatchOfficialScreen extends ConsumerStatefulWidget {
  const AddMatchOfficialScreen({
    super.key,
    required this.title,
    required this.slotLabel,
    this.initial,
  });

  final String title;
  final String slotLabel;
  final MatchOfficialEntry? initial;

  @override
  ConsumerState<AddMatchOfficialScreen> createState() =>
      _AddMatchOfficialScreenState();
}

class _AddMatchOfficialScreenState extends ConsumerState<AddMatchOfficialScreen> {
  final _contactController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _showCard = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.name.isNotEmpty) {
      _nameController.text = initial.name;
      _emailController.text = initial.email ?? '';
      _showCard = true;
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _find() {
    final query = _contactController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter phone number or email')),
      );
      return;
    }
    setState(() {
      _showCard = true;
      if (_nameController.text.isEmpty) {
        _nameController.text = query.contains('@') ? query.split('@').first : query;
      }
      if (query.contains('@') && _emailController.text.isEmpty) {
        _emailController.text = query;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter official details below')),
    );
  }

  void _done() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Official name is required')),
      );
      return;
    }
    final email = _emailController.text.trim();
    Navigator.pop(
      context,
      MatchOfficialEntry(
        name: name,
        email: email.isEmpty ? null : email,
        slotLabel: widget.slotLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    hintText: 'Add via phone number or email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              FilledButton(
                onPressed: _find,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                child: const Text('Find'),
              ),
            ],
          ),
          if (_showCard) ...[
            const SizedBox(height: AppDimens.spaceLg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _showCard = false;
                          _nameController.clear();
                          _emailController.clear();
                        }),
                      ),
                    ),
                    CfUnderlinedField(
                      controller: _nameController,
                      label: 'Official name',
                    ),
                    const SizedBox(height: AppDimens.fieldSpacing),
                    CfUnderlinedField(
                      controller: _emailController,
                      label: 'Valid email address',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: _showCard ? _done : null,
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size(double.infinity, AppDimens.buttonHeightLarge),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}
