import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';

import '../helpers/fixtures.dart';

void main() {
  group('discoverAssetFolders (T009, FR-009, Q53)', () {
    test('declared folders are listed with their scene files', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj/assets/images').createSync(recursive: true);
      fs.directory('/proj/assets/scenes').createSync(recursive: true);
      fs.file('/proj/pubspec.yaml').writeAsStringSync(pubspecDeclaredFolders);
      fs.file('/proj/assets/scenes/level2.scene.json').writeAsStringSync('{}');
      fs.file('/proj/assets/scenes/level1.scene.json').writeAsStringSync('{}');
      fs.file('/proj/assets/scenes/notes.txt').writeAsStringSync('x');
      fs.file('/proj/assets/images/ship.png').writeAsStringSync('x');
      final folders = await discoverAssetFolders('/proj', fileSystem: fs);
      expect(folders.declared, ['assets/images', 'assets/scenes']);
      expect(folders.scenes, [
        'assets/scenes/level1.scene.json',
        'assets/scenes/level2.scene.json',
      ]);
    });

    test('scenes nest under declared folders', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj/assets/scenes/ch1').createSync(recursive: true);
      fs.file('/proj/pubspec.yaml').writeAsStringSync(pubspecDeclaredFolders);
      fs.file('/proj/assets/scenes/ch1/a.scene.json').writeAsStringSync('{}');
      final folders = await discoverAssetFolders('/proj', fileSystem: fs);
      expect(folders.scenes, ['assets/scenes/ch1/a.scene.json']);
    });

    test('isDeclaredFolder marks undeclared target folders (FR-008)', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj/assets/images').createSync(recursive: true);
      fs
          .file('/proj/pubspec.yaml')
          .writeAsStringSync(pubspecMissingScenesFolder);
      final folders = await discoverAssetFolders('/proj', fileSystem: fs);
      expect(isDeclaredFolder(folders, 'assets/scenes'), isFalse);
      expect(isDeclaredFolder(folders, 'assets/images'), isTrue);
    });

    test('a pubspec without a flutter section is empty', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj').createSync(recursive: true);
      fs.file('/proj/pubspec.yaml').writeAsStringSync(pubspecNoFlutterSection);
      expect(
        await discoverAssetFolders('/proj', fileSystem: fs),
        AssetFolders.empty,
      );
    });

    test('no pubspec at all is empty, never an error', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj').createSync(recursive: true);
      expect(
        await discoverAssetFolders('/proj', fileSystem: fs),
        AssetFolders.empty,
      );
    });
  });
}
