import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _fileName = 'rihla_crash_log.txt';
const _maxLines = 2000;

final List<String> _lines = [];

Future<void> append(String line) async {
  _lines.add(line);
  if (_lines.length > _maxLines) _lines.removeAt(0);
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    await file.writeAsString('$line\n', mode: FileMode.append);
  } catch (_) {}
}

Future<String> readAll() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    if (await file.exists()) return await file.readAsString();
  } catch (_) {}
  return _lines.join('\n');
}

Future<String?> filePath() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  } catch (_) {}
  return null;
}
