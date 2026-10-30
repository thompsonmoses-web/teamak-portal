/// What non-web builds do with a file download: nothing, loudly — the
/// caller catches this and falls back to showing the receipt on screen.
void saveTextDownload(String filename, String text) {
  throw UnsupportedError('file downloads exist on the web build only');
}
