import 'crash_log_storage_io.dart' if (dart.library.html) 'crash_log_storage_web.dart' as storage;

/// Persists errors and stack traces so you can share them for debugging.
/// On mobile: writes to a file in app documents. On web: in-memory only.
class CrashLogService {
  CrashLogService._();
  static final CrashLogService instance = CrashLogService._();

  Future<void> log(String line) async {
    final stamped = '${DateTime.now().toIso8601String()} | $line';
    await storage.append(stamped);
  }

  Future<void> logError(Object error, StackTrace? stackTrace) async {
    await log('ERROR: $error');
    if (stackTrace != null) await log(stackTrace.toString());
  }

  Future<String> getLogContent() async {
    return storage.readAll();
  }

  Future<String?> getLogFilePath() async {
    return storage.filePath();
  }
}
