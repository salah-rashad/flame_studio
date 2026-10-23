import 'dart:developer' as developer;
import 'dart:math';

import 'package:file/file.dart';

final _random = Random.secure();

/// Writes [bytes] to [path] so that any reader sees either the whole old file
/// or the whole new one (spec 002, FR-019, research R7).
///
/// The bytes go to a temporary file in the same folder, are flushed to disk,
/// and the temporary file is renamed onto [path] in one step. On failure the
/// temporary file is removed and the error rethrown; [path] is untouched. The
/// folder is never created.
Future<void> writeAtomically(
  FileSystem fs,
  String path,
  List<int> bytes,
) async {
  final name = fs.path.basename(path);
  final suffix = [
    for (var i = 0; i < 6; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  final temp = fs.file(
    fs.path.join(fs.path.dirname(path), '.$name.$suffix.pyro-tmp'),
  );
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(path);
  } catch (_) {
    await _removeQuietly(temp);
    rethrow;
  }
}

Future<void> _removeQuietly(File temp) async {
  try {
    if (temp.existsSync()) await temp.delete();
  } on FileSystemException catch (error) {
    developer.log(
      'Could not remove the temporary file "${temp.path}": $error',
      name: 'pyro.document',
    );
  }
}
