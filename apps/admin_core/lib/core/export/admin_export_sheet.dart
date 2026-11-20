import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_csv.dart';
import 'admin_file_download.dart';

/// Shows CSV / Excel-compatible CSV download options for the current rows.
///
/// PDF is not offered — there is no PDF implementation.
Future<void> showAdminListExport({
  required BuildContext context,
  required String filenameBase,
  required List<String> headers,
  required List<List<String?>> rows,
  bool hasMore = false,
  String? emptyMessage,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          emptyMessage ?? 'Nothing to export for the current filters.',
        ),
      ),
    );
    return;
  }

  final stamp = DateTime.now().toIso8601String().split('T').first;
  final base = '${filenameBase}_$stamp';
  final loadedNote = hasMore
      ? 'Exports the ${rows.length} currently loaded rows. '
            'Load more first to include the rest.'
      : 'Exports ${rows.length} filtered row${rows.length == 1 ? '' : 's'}.';

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(loadedNote, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              subtitle: const Text('UTF-8 comma-separated values'),
              onTap: () async {
                Navigator.pop(ctx);
                await _save(
                  context: context,
                  filename: '$base.csv',
                  content: AdminCsv.table(headers: headers, rows: rows),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: const Text('Excel-compatible CSV'),
              subtitle: const Text(
                'Same CSV with a UTF-8 BOM so Excel opens it correctly',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _save(
                  context: context,
                  filename: '${base}_excel.csv',
                  content: AdminCsv.table(
                    headers: headers,
                    rows: rows,
                    excelCompatible: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Downloads a ready-made text payload (CSV or JSON).
Future<void> downloadAdminTextFile({
  required BuildContext context,
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
  String emptyMessage = 'Nothing to export for the current filters.',
}) async {
  if (content.trim().isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(emptyMessage)));
    return;
  }
  await _save(
    context: context,
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}

Future<void> _save({
  required BuildContext context,
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final result = downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
  if (result.downloaded) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Downloaded ${result.filename}')));
    }
    return;
  }
  await Clipboard.setData(ClipboardData(text: content));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Download is only available in the browser. '
          '${result.filename} was copied to the clipboard instead.',
        ),
      ),
    );
  }
}
