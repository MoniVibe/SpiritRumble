// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const String _defaultStorageKey = 'SpiritRumble/recent_matches.json';

String resolveDiagnosticsPath(String? overridePath) {
  if (overridePath != null && overridePath.isNotEmpty) {
    return overridePath;
  }
  return _defaultStorageKey;
}

String? readDiagnostics(String path) {
  try {
    return html.window.localStorage[path];
  } catch (_) {
    return null;
  }
}

void writeDiagnostics(String path, String encoded) {
  try {
    html.window.localStorage[path] = encoded;
  } catch (_) {
    // Ignore storage errors (for example private mode quotas).
  }
}
