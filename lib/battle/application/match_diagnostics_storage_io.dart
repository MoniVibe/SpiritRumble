import 'dart:io';

String resolveDiagnosticsPath(String? overridePath) {
  if (overridePath != null && overridePath.isNotEmpty) {
    return overridePath;
  }
  final sep = Platform.pathSeparator;
  final base = Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
  return '$base${sep}SpiritRumble${sep}diagnostics${sep}recent_matches.json';
}

String? readDiagnostics(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  try {
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

void writeDiagnostics(String path, String encoded) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(encoded);
}
