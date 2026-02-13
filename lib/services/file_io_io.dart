import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readFileBytes(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) return await file.readAsBytes();
  } catch (_) {}
  return null;
}

Future<bool> writeFileBytes(String path, List<int> bytes) async {
  try {
    await File(path).writeAsBytes(bytes);
    return true;
  } catch (_) {}
  return false;
}
