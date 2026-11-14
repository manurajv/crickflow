import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/admin_delete_service.dart';

/// Confirm + run a permanent, cascading delete. Returns true when deleted.
Future<bool> showPermanentDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AdminDeleteTarget target,
  required String id,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await showDialog<AdminDeleteResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PermanentDeleteDialog(target: target, id: id, name: name),
  );
  if (result == null) return false;
  messenger?.showSnackBar(SnackBar(content: Text(result.summary(target))));
  return true;
}

class _PermanentDeleteDialog extends ConsumerStatefulWidget {
  const _PermanentDeleteDialog({
    required this.target,
    required this.id,
    required this.name,
  });

  final AdminDeleteTarget target;
  final String id;
  final String name;

  @override
  ConsumerState<_PermanentDeleteDialog> createState() =>
      _PermanentDeleteDialogState();
}

class _PermanentDeleteDialogState
    extends ConsumerState<_PermanentDeleteDialog> {
  final _reason = TextEditingController();
  var _understood = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminDeleteServiceProvider).deletePermanently(
            target: widget.target,
            id: widget.id,
            reason: _reason.text,
          );
      if (mounted) Navigator.of(context).pop(result);
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.target.label;
    final displayName = widget.name.trim().isEmpty ? 'this $label' : '"${widget.name}"';
    return AlertDialog(
      key: const Key('permanent_delete_dialog'),
      title: Text('Delete $label permanently?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$displayName will be deleted for everyone. This cannot be undone.',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('What happens:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              for (final line in widget.target.impact)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Reason (shown to the people notified)',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _understood,
                onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I understand this permanently deletes it'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Could not delete: $_error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: (_understood && !_busy) ? _run : null,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete permanently'),
        ),
      ],
    );
  }
}
