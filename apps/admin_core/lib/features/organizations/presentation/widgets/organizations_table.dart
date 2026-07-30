import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_organization.dart';
import '../../models/organization_filters.dart';
import 'organization_status_badge.dart';

class OrganizationsTable extends StatefulWidget {
  const OrganizationsTable({
    super.key,
    required this.organizations,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedOrganization> organizations;
  final OrganizationSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<OrganizationSortField> onSort;
  final ValueChanged<ManagedOrganization> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<OrganizationsTable> createState() => _OrganizationsTableState();
}

class _OrganizationsTableState extends State<OrganizationsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1280.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.organizations;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading organizations…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.apartment_outlined,
            title: 'No organizations found',
            message: 'Create an organization or adjust search / filters.',
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SizedBox(
                      width: _tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(sort: widget.sort, onSort: widget.onSort),
                          Divider(height: 1, color: colors.border),
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: colors.border),
                            _OrgRow(
                              org: items[i],
                              selected: items[i].id == widget.selectedId,
                              onTap: () => widget.onSelect(items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${items.length} shown',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                const Spacer(),
                if (widget.hasMore)
                  TextButton.icon(
                    onPressed: widget.isLoadingMore ? null : widget.onLoadMore,
                    icon: widget.isLoadingMore
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more, size: 18),
                    label: Text(
                      widget.isLoadingMore ? 'Loading…' : 'Load more',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sort, required this.onSort});

  final OrganizationSort sort;
  final ValueChanged<OrganizationSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    Widget cell(String label, OrganizationSortField? field, {double flex = 1}) {
      final active = field != null && sort.field == field;
      return Expanded(
        flex: (flex * 10).round(),
        child: InkWell(
          onTap: field == null ? null : () => onSort(field),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                if (active)
                  Icon(
                    sort.descending
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 14,
                    color: colors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Row(
        children: [
          cell('Organization', OrganizationSortField.name, flex: 2.2),
          cell('Type', OrganizationSortField.type, flex: 1),
          cell('Status', null, flex: 1),
          cell('Location', OrganizationSortField.city, flex: 1.4),
          cell('Org Admin', null, flex: 1.4),
          cell('Created', OrganizationSortField.createdAt, flex: 1),
        ],
      ),
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({
    required this.org,
    required this.selected,
    required this.onTap,
  });

  final ManagedOrganization org;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final df = DateFormat.yMMMd();

    return Material(
      color: selected
          ? AdminColors.primaryBlue.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 22,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colors.background,
                        child: org.logoUrl == null || org.logoUrl!.isEmpty
                            ? Icon(Icons.apartment,
                                size: 16, color: colors.textMuted)
                            : ClipOval(
                                child: Image.network(
                                  org.logoUrl!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.apartment,
                                    size: 16,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org.name.isEmpty ? '—' : org.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              org.slug.isEmpty ? org.id : org.slug,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: OrganizationTypeBadge(type: org.type),
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: OrganizationStatusBadge(status: org.displayStatus),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    org.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    org.primaryAdminEmail?.isNotEmpty == true
                        ? org.primaryAdminEmail!
                        : (org.hasPrimaryAdmin ? org.primaryAdminUid! : '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: org.hasPrimaryAdmin
                          ? null
                          : colors.textMuted,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    org.createdAt == null ? '—' : df.format(org.createdAt!),
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
