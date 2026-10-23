import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';

/// A file system over a [MemoryFileSystem] that logs every file operation and
/// can fail at, or hold, a chosen one (spec 002, tasks T006).
///
/// Counted operations are the async ones the Document model uses: `read`,
/// `write`, `rename` and `delete`. A failed `write` first writes half the
/// bytes, like a full disk.
class FailingFileSystem extends ForwardingFileSystem {
  FailingFileSystem([FileSystem? delegate])
    : super(delegate ?? MemoryFileSystem());

  /// The 1-based number of the operation that throws, or null for none.
  int? failAt;

  /// While set, writes to paths matching [holdPattern] wait for it.
  Completer<void>? holdWrites;

  /// Which writes [holdWrites] holds; null holds every write.
  Pattern? holdPattern;

  /// How many counted operations have run.
  int operationCount = 0;

  /// `'<operation> <path>'` for each counted operation, in order.
  final List<String> operations = [];

  /// The file system underneath, for setting up and checking files without
  /// counting.
  FileSystem get inner => delegate;

  Future<void> _count(String operation, String path) async {
    operationCount++;
    operations.add('$operation $path');
    if (operationCount == failAt) {
      throw io.FileSystemException('Injected failure in $operation', path);
    }
  }

  @override
  File file(dynamic path) => _CountingFile(this, delegate.file(path));
}

class _CountingFile extends ForwardingFileSystemEntity<File, io.File>
    with ForwardingFile {
  _CountingFile(this.fileSystem, this.delegate);

  @override
  final FailingFileSystem fileSystem;

  @override
  final File delegate;

  @override
  File wrapFile(io.File delegate) =>
      _CountingFile(fileSystem, delegate as File);

  @override
  Directory wrapDirectory(io.Directory delegate) => delegate as Directory;

  @override
  Link wrapLink(io.Link delegate) => delegate as Link;

  @override
  Future<Uint8List> readAsBytes() async {
    await fileSystem._count('read', path);
    return delegate.readAsBytes();
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    io.FileMode mode = io.FileMode.write,
    bool flush = false,
  }) async {
    final hold = fileSystem.holdWrites;
    final pattern = fileSystem.holdPattern;
    if (hold != null && (pattern == null || path.contains(pattern))) {
      await hold.future;
    }
    try {
      await fileSystem._count('write', path);
    } on io.FileSystemException {
      await delegate.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));
      rethrow;
    }
    await delegate.writeAsBytes(bytes, mode: mode, flush: flush);
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    await fileSystem._count('rename', path);
    return wrap(await delegate.rename(newPath));
  }

  @override
  Future<File> delete({bool recursive = false}) async {
    await fileSystem._count('delete', path);
    await delegate.delete(recursive: recursive);
    return this;
  }
}
