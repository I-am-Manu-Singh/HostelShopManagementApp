/// Cross-platform CSV file download helper.
///
/// On **web**: triggers a real browser file download via dart:html AnchorElement.
/// On **native** (Android/iOS): this is a no-op — callers must use Share.shareXFiles.
///
/// Usage:
/// ```dart
/// import 'package:hostelshop/utils/csv_web_helper.dart';
/// downloadCsvFile(csvString, 'export.csv');
/// ```
export 'csv_web_helper_stub.dart'
    if (dart.library.html) 'csv_web_helper_web.dart';
