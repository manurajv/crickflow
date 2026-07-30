import '../../l10n/generated/admin_localizations.dart';
import '../locale/admin_regional_settings.dart';

/// Export / report localization helpers (CSV / Excel / PDF ready).
///
/// Does not generate files yet — provides locale-aware cell formatting
/// so future export pipelines stay consistent with the UI.
abstract final class AdminExportLocalizer {
  AdminExportLocalizer({
    required this.l10n,
    required this.settings,
    required this.formatDate,
    required this.formatNumber,
  });

  final AdminLocalizations l10n;
  final AdminRegionalSettings settings;
  final String Function(DateTime?) formatDate;
  final String Function(num?) formatNumber;

  /// UTF-8 BOM for Excel-friendly CSV.
  static const csvBom = '\uFEFF';

  String csvEscape(String? value) {
    final v = value ?? '';
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String cellDate(DateTime? value) => formatDate(value);

  String cellNumber(num? value) => formatNumber(value);

  /// Header row using current UI language.
  List<String> commonHeaders() => [
        l10n.actionExport,
        l10n.accountDateFormat,
        l10n.accountTimezone,
      ];
}
