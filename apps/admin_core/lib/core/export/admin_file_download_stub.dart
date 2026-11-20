import 'admin_download_result.dart';

AdminDownloadResult downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  return AdminDownloadResult(downloaded: false, filename: filename);
}
