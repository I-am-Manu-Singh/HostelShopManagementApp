// Stub implementation for non-web platforms.
// On native, CSV export is handled by Share.shareXFiles.
void downloadCsvFile(String content, String filename) {
  // No-op on Android/iOS — caller uses Share.shareXFiles instead.
}
