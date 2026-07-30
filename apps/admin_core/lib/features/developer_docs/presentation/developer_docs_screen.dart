import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../../shared/widgets/cf_search_bar.dart';
import '../../shell/providers/shell_providers.dart';
import '../data/developer_docs_catalog.dart';
import '../providers/developer_docs_providers.dart';

/// Searchable Material 3 documentation browser (content only — no business logic).
class DeveloperDocsScreen extends ConsumerStatefulWidget {
  const DeveloperDocsScreen({super.key});

  @override
  ConsumerState<DeveloperDocsScreen> createState() =>
      _DeveloperDocsScreenState();
}

class _DeveloperDocsScreenState extends ConsumerState<DeveloperDocsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Developer Docs',
      ];
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final filtered = ref.watch(developerDocsFilteredProvider);
    final selectedId = ref.watch(developerDocsSelectedIdProvider);
    final selected = DeveloperDocsCatalog.byId(selectedId);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Padding(
      padding: dimens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Developer Docs',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Architecture, APIs, standards, and runbooks for CrickFlow Admin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          SizedBox(height: dimens.spaceLg),
          CfSearchBar(
            controller: _search,
            hintText: 'Search modules, providers, collections, APIs…',
            onChanged: (q) =>
                ref.read(developerDocsQueryProvider.notifier).state = q,
          ),
          SizedBox(height: dimens.spaceLg),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 280,
                        child: _Toc(
                          pages: filtered,
                          selectedId: selectedId,
                          onSelect: _select,
                        ),
                      ),
                      SizedBox(width: dimens.spaceLg),
                      Expanded(
                        child: _DocBody(page: selected, pageId: selectedId),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: _Toc(
                          pages: filtered,
                          selectedId: selectedId,
                          onSelect: _select,
                        ),
                      ),
                      SizedBox(height: dimens.spaceMd),
                      Expanded(
                        child: _DocBody(page: selected, pageId: selectedId),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _select(DeveloperDocPage page) {
    ref.read(developerDocsSelectedIdProvider.notifier).state = page.id;
    ref.read(breadcrumbProvider.notifier).state = [
      'System',
      'Developer Docs',
      page.title,
    ];
  }
}

class _Toc extends StatelessWidget {
  const _Toc({
    required this.pages,
    required this.selectedId,
    required this.onSelect,
  });

  final List<DeveloperDocPage> pages;
  final String selectedId;
  final ValueChanged<DeveloperDocPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final sections = <String, List<DeveloperDocPage>>{};
    for (final p in pages) {
      sections.putIfAbsent(p.section, () => []).add(p);
    }

    return Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: dimens.borderRadiusLg,
        side: BorderSide(color: colors.border),
      ),
      child: ListView(
        padding: EdgeInsets.all(dimens.spaceMd),
        children: [
          if (pages.isEmpty)
            Padding(
              padding: EdgeInsets.all(dimens.spaceMd),
              child: Text(
                'No matching pages',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          for (final entry in sections.entries) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                dimens.spaceSm,
                dimens.spaceMd,
                dimens.spaceSm,
                dimens.spaceSm,
              ),
              child: Text(
                entry.key.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: colors.textMuted,
                    ),
              ),
            ),
            for (final page in entry.value)
              ListTile(
                dense: true,
                selected: page.id == selectedId,
                selectedTileColor: colors.rowHover,
                shape: RoundedRectangleBorder(
                  borderRadius: dimens.borderRadiusMd,
                ),
                title: Text(
                  page.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: page.summary.isEmpty
                    ? null
                    : Text(
                        page.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => onSelect(page),
              ),
          ],
        ],
      ),
    );
  }
}

class _DocBody extends ConsumerWidget {
  const _DocBody({required this.page, required this.pageId});

  final DeveloperDocPage? page;
  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final async = ref.watch(developerDocBodyProvider(pageId));

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: dimens.borderRadiusLg,
        side: BorderSide(color: colors.border),
      ),
      child: async.when(
        loading: () => const CfLoadingState(message: 'Loading documentation…'),
        error: (e, _) => Center(child: Text('$e')),
        data: (md) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (page != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dimens.spaceXl,
                    dimens.spaceLg,
                    dimens.spaceXl,
                    0,
                  ),
                  child: Text(
                    page!.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              Expanded(
                child: Markdown(
                  data: md,
                  selectable: true,
                  padding: EdgeInsets.all(dimens.spaceXl),
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context),
                  ).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.55,
                        ),
                    h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    code: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          backgroundColor: colors.background,
                        ),
                    codeblockDecoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: dimens.borderRadiusMd,
                      border: Border.all(color: colors.border),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: colors.focusRing, width: 3),
                      ),
                    ),
                    tableBorder: TableBorder.all(color: colors.border),
                    tableHead: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTapLink: (text, href, title) async {
                    if (href == null) return;
                    // In-app cross links: architecture.md → select catalog id
                    if (href.endsWith('.md') && !href.contains('://')) {
                      final id = href
                          .split('/')
                          .last
                          .replaceAll('.md', '')
                          .replaceAll('README', 'readme');
                      final target = DeveloperDocsCatalog.byId(
                        id == 'readme' ? 'readme' : id,
                      );
                      if (target != null) {
                        ref
                            .read(developerDocsSelectedIdProvider.notifier)
                            .state = target.id;
                        return;
                      }
                    }
                    final uri = Uri.tryParse(href);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
