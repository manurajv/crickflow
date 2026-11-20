/// Client-side CSV helpers for Super Admin list exports.
///
/// Excel-compatible CSV is the same table with a UTF-8 BOM so Excel
/// on Windows opens Unicode correctly. There is no XLSX or PDF writer.
abstract final class AdminCsv {
  AdminCsv._();

  /// UTF-8 BOM prefix that Excel expects for UTF-8 CSV files.
  static const bom = '\uFEFF';

  static String escape(String? value) {
    final v = value ?? '';
    if (v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String cellDate(DateTime? value) {
    if (value == null) return '';
    return value.toUtc().toIso8601String();
  }

  static String table({
    required List<String> headers,
    required List<List<String?>> rows,
    bool excelCompatible = false,
  }) {
    final buf = StringBuffer();
    if (excelCompatible) buf.write(bom);
    buf.writeln(headers.map(escape).join(','));
    for (final row in rows) {
      buf.writeln(
        [
          for (var i = 0; i < headers.length; i++)
            escape(i < row.length ? row[i] : ''),
        ].join(','),
      );
    }
    return buf.toString();
  }
}
