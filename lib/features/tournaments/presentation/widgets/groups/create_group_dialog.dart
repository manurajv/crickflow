import 'package:flutter/material.dart';

enum GroupCreationMethod { manual, autoDistribution }

Future<CreateGroupResult?> showCreateGroupDialog(
  BuildContext context, {
  required GroupCreationMethod method,
}) {
  return showDialog<CreateGroupResult>(
    context: context,
    builder: (ctx) => _CreateGroupDialog(method: method),
  );
}

class CreateGroupResult {
  const CreateGroupResult({
    required this.method,
    required this.groupCount,
    this.names = const [],
    this.qualificationCount = 2,
    this.qualificationTarget = '',
  });

  final GroupCreationMethod method;
  final int groupCount;
  final List<String> names;
  final int qualificationCount;
  final String qualificationTarget;
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.method});

  final GroupCreationMethod method;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  int _count = 2;
  int _qualify = 2;
  final _target = TextEditingController(text: 'Quarter Final');

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = widget.method == GroupCreationMethod.autoDistribution;
    return AlertDialog(
      title: Text(isAuto ? 'Auto distribute teams' : 'Create groups'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            value: _count,
            decoration: const InputDecoration(
              labelText: 'Number of groups',
              border: OutlineInputBorder(),
            ),
            items: List.generate(8, (i) => i + 1)
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) => setState(() => _count = v ?? 2),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _qualify,
            decoration: const InputDecoration(
              labelText: 'Teams qualifying per group',
              border: OutlineInputBorder(),
            ),
            items: const [1, 2, 4]
                .map((n) => DropdownMenuItem(value: n, child: Text('Top $n')))
                .toList(),
            onChanged: (v) => setState(() => _qualify = v ?? 2),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            decoration: const InputDecoration(
              labelText: 'Qualification target round',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final names = List.generate(
              _count,
              (i) => 'Group ${String.fromCharCode(65 + i)}',
            );
            Navigator.pop(
              context,
              CreateGroupResult(
                method: widget.method,
                groupCount: _count,
                names: names,
                qualificationCount: _qualify,
                qualificationTarget: _target.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
