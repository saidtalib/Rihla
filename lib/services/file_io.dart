import 'dart:typed_data';

import 'file_io_io.dart' if (dart.library.html) 'file_io_web.dart' as impl;

Future<Uint8List?> readFileBytes(String path) => impl.readFileBytes(path);

Future<bool> writeFileBytes(String path, List<int> bytes) =>
    impl.writeFileBytes(path, bytes);
