import 'package:flutter/material.dart';

/// Report reason prompt that owns its [TextEditingController] lifecycle.
///
/// Returns `null` if cancelled, otherwise the trimmed reason (may be empty if
/// the user tapped Report without typing).
Future<String?> showReportReasonDialog(
  BuildContext context, {
  required String title,
  String hint = 'Spam, harassment, misleading…',
  String confirmLabel = 'Report',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _ReportReasonDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String hint;
  final String confirmLabel;

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  late final TextEditingController _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close([String? result]) {
    // Unfocus before pop so the IME / InputDecorator teardown finishes cleanly.
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Reason',
          hintText: widget.hint,
        ),
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _close(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _close(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
