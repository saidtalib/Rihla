const _maxLines = 2000;

final List<String> _lines = [];

Future<void> append(String line) async {
  _lines.add(line);
  if (_lines.length > _maxLines) _lines.removeAt(0);
}

Future<String> readAll() async {
  return _lines.join('\n');
}

Future<String?> filePath() async {
  return null;
}
