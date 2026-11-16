import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/related_records.dart';
import '../../core/extensions/context_extensions.dart';

class RelatedRecordsSection extends StatelessWidget {
  const RelatedRecordsSection({
    super.key,
    required this.title,
    required this.section,
    required this.emptyMessage,
    this.footer,
  });

  final String title;
  final RelatedSection section;
  final String emptyMessage;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (section.hasError)
            Text(
              'Could not load: ${section.error}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            )
          else if (section.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            )
          else
            for (final item in section.items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: item.subtitle.isEmpty
                    ? null
                    : Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: item.occurredAt == null
                    ? null
                    : Text(
                        DateFormat('MMM d').format(item.occurredAt!),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
              ),
          if (footer != null) ...[const SizedBox(height: 4), footer!],
        ],
      ),
    );
  }
}

class RelatedRecordsAsync<T> extends StatelessWidget {
  const RelatedRecordsAsync({
    super.key,
    required this.async,
    required this.builder,
  });

  final AsyncValue<T> async;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Could not load related data: $e',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
      ),
      data: builder,
    );
  }
}

class RelatedNote extends StatelessWidget {
  const RelatedNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(color: context.adminColors.textMuted, fontSize: 13),
      ),
    );
  }
}
