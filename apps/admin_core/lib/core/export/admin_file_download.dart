import 'admin_download_result.dart';
import 'admin_file_download_stub.dart'
    if (dart.library.html) 'admin_file_download_web.dart'
    if (dart.library.js_interop) 'admin_file_download_web.dart'
    as impl;

export 'admin_download_result.dart';

/// Triggers a browser file download on web. Returns [downloaded] = false
/// on other platforms so the caller can fall back to the clipboard.
AdminDownloadResult downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
