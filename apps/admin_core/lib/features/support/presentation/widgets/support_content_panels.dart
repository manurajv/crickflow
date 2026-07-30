import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/managed_support.dart';
import '../../models/support_enums.dart';

class SupportContentPanels extends StatelessWidget {
  const SupportContentPanels({
    super.key,
    required this.section,
    required this.kbArticles,
    required this.faqs,
    required this.announcements,
    required this.summary,
    required this.reports,
    required this.onSaveKb,
    required this.onSaveFaq,
    required this.onSaveAnnouncement,
  });

  final SupportHubSection section;
  final List<SupportKbArticle> kbArticles;
  final List<SupportFaqItem> faqs;
  final List<SupportAnnouncement> announcements;
  final SupportSummaryStats summary;
  final SupportReportSnapshot reports;
  final Future<void> Function(SupportKbArticle) onSaveKb;
  final Future<void> Function(SupportFaqItem) onSaveFaq;
  final Future<void> Function(SupportAnnouncement) onSaveAnnouncement;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      SupportHubSection.knowledgeBase => _KbPanel(
          articles: kbArticles,
          onSave: onSaveKb,
        ),
      SupportHubSection.faq => _FaqPanel(items: faqs, onSave: onSaveFaq),
      SupportHubSection.announcements => _AnnouncementPanel(
          items: announcements,
          onSave: onSaveAnnouncement,
        ),
      SupportHubSection.csat => _CsatPanel(summary: summary),
      SupportHubSection.reports => _ReportsPanel(reports: reports, summary: summary),
      _ => const SizedBox.shrink(),
    };
  }
}

class _KbPanel extends StatelessWidget {
  const _KbPanel({required this.articles, required this.onSave});
  final List<SupportKbArticle> articles;
  final Future<void> Function(SupportKbArticle) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'New article',
            icon: Icons.add,
            onPressed: () => _edit(context, null),
          ),
        ),
        const SizedBox(height: 12),
        if (articles.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 200,
              child: CfEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No knowledge base articles',
                message:
                    'Create Getting Started, Scoring, Streaming, Tournament guides…',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final a in articles)
                  Material(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text('${a.category} · ${a.status.label}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(context, a),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'CMS FAQ/Help pages remain in Settings → CMS; this KB is support-ops content.',
          style: TextStyle(fontSize: 11, color: context.adminColors.textMuted),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, SupportKbArticle? existing) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    final category = TextEditingController(text: existing?.category ?? 'General');
    var status = existing?.status ?? SupportContentStatus.draft;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New article' : 'Edit article'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Body'),
                ),
                DropdownButtonFormField<SupportContentStatus>(
                  // ignore: deprecated_member_use
                  value: status,
                  items: [
                    for (final s in SupportContentStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onSave(
                  SupportKbArticle(
                    id: existing?.id ?? '',
                    title: title.text.trim(),
                    body: body.text.trim(),
                    category: category.text.trim(),
                    status: status,
                    keywords: existing?.keywords ?? const [],
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    category.dispose();
  }
}

class _FaqPanel extends StatelessWidget {
  const _FaqPanel({required this.items, required this.onSave});
  final List<SupportFaqItem> items;
  final Future<void> Function(SupportFaqItem) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'New FAQ',
            icon: Icons.add,
            onPressed: () => _edit(context, null),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 200,
              child: CfEmptyState(
                icon: Icons.help_outline,
                title: 'No FAQs yet',
                message: 'Manage question / answer / keywords here.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final f in items)
                  Material(
                    child: ListTile(
                      title: Text(f.question),
                      subtitle: Text('${f.category} · ${f.status.label}'),
                      onTap: () => _edit(context, f),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, SupportFaqItem? existing) async {
    final q = TextEditingController(text: existing?.question ?? '');
    final a = TextEditingController(text: existing?.answer ?? '');
    final cat = TextEditingController(text: existing?.category ?? 'General');
    final kw = TextEditingController(
      text: existing?.keywords.join(', ') ?? '',
    );
    var status = existing?.status ?? SupportContentStatus.draft;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New FAQ' : 'Edit FAQ'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: q,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                TextField(
                  controller: a,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Answer'),
                ),
                TextField(
                  controller: cat,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: kw,
                  decoration: const InputDecoration(
                    labelText: 'Search keywords (comma-separated)',
                  ),
                ),
                DropdownButtonFormField<SupportContentStatus>(
                  // ignore: deprecated_member_use
                  value: status,
                  items: [
                    for (final s in SupportContentStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onSave(
                  SupportFaqItem(
                    id: existing?.id ?? '',
                    question: q.text.trim(),
                    answer: a.text.trim(),
                    category: cat.text.trim(),
                    status: status,
                    keywords: kw.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    q.dispose();
    a.dispose();
    cat.dispose();
    kw.dispose();
  }
}

class _AnnouncementPanel extends StatelessWidget {
  const _AnnouncementPanel({required this.items, required this.onSave});
  final List<SupportAnnouncement> items;
  final Future<void> Function(SupportAnnouncement) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'New announcement',
            icon: Icons.add,
            onPressed: () => _edit(context, null),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 200,
              child: CfEmptyState(
                icon: Icons.campaign_outlined,
                title: 'No support announcements',
                message:
                    'Known issues, maintenance, disruptions, resolved incidents.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final a in items)
                  Material(
                    child: ListTile(
                      title: Text(a.title),
                      subtitle: Text('${a.type.label} · ${a.status.label}'),
                      onTap: () => _edit(context, a),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    SupportAnnouncement? existing,
  ) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    var type = existing?.type ?? SupportAnnouncementType.general;
    var status = existing?.status ?? SupportContentStatus.draft;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New announcement' : 'Edit'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: body,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Body'),
                ),
                DropdownButtonFormField<SupportAnnouncementType>(
                  // ignore: deprecated_member_use
                  value: type,
                  items: [
                    for (final t in SupportAnnouncementType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                DropdownButtonFormField<SupportContentStatus>(
                  // ignore: deprecated_member_use
                  value: status,
                  items: [
                    for (final s in SupportContentStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await onSave(
                  SupportAnnouncement(
                    id: existing?.id ?? '',
                    title: title.text.trim(),
                    body: body.text.trim(),
                    type: type,
                    status: status,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }
}

class _CsatPanel extends StatelessWidget {
  const _CsatPanel({required this.summary});
  final SupportSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer satisfaction',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _Stat('Average', summary.csatAverage == 0
                  ? '—'
                  : summary.csatAverage.toStringAsFixed(2)),
              _Stat('Positive', '${summary.csatPositive}'),
              _Stat('Neutral', '${summary.csatNeutral}'),
              _Stat('Negative', '${summary.csatNegative}'),
              _Stat(
                'Response time',
                '${summary.avgResponseMins.toStringAsFixed(0)}m',
              ),
              _Stat(
                'Resolution time',
                '${summary.avgResolutionMins.toStringAsFixed(0)}m',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'NPS support prepared for a future survey channel.',
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({required this.reports, required this.summary});
  final SupportReportSnapshot reports;
  final SupportSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket trends (sample)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Avg resolution ${summary.avgResolutionMins.toStringAsFixed(0)}m · '
                'Open ${summary.open} · Overdue ${summary.overdue}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _NamedList(title: 'Most common issues', items: reports.commonIssues),
        const SizedBox(height: 12),
        _NamedList(
          title: 'Most active agents',
          items: reports.agentActivity,
        ),
        const SizedBox(height: 12),
        _NamedList(
          title: 'Category distribution',
          items: reports.categoryDistribution,
        ),
      ],
    );
  }
}

class _NamedList extends StatelessWidget {
  const _NamedList({required this.title, required this.items});
  final String title;
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data in sample window'),
            )
          else
            for (final i in items)
              Material(
                child: ListTile(
                  title: Text(i.$1),
                  trailing: Text(
                    '${i.$2}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
