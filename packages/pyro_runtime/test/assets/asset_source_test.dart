import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_runtime/src/assets/asset_source.dart';

import '../support/images.dart';

/// A bundle that serves one PNG for every `.png` key and fixed text
/// otherwise, recording each request.
final class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.png);

  final Uint8List png;
  final List<String> loads = [];
  final List<({String key, bool cache})> stringLoads = [];
  bool fail = false;

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    if (fail) throw FlutterError('Unable to load asset: "$key".');
    return key.endsWith('.png')
        ? ByteData.sublistView(png)
        : ByteData.sublistView(Uint8List.fromList('text of $key'.codeUnits));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    stringLoads.add((key: key, cache: cache));
    return super.loadString(key, cache: cache);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeBundle bundle;

  setUp(() async => bundle = _FakeBundle(await makePng(4, 2)));

  test('reads text by its exact path, never from a cache', () async {
    final source = AssetSource.bundle(bundle);
    final text = await source.loadText(
      const AssetPath('assets/scenes/a.scene.json'),
    );
    expect(text, 'text of assets/scenes/a.scene.json');
    expect(bundle.stringLoads, [
      (key: 'assets/scenes/a.scene.json', cache: false),
    ]);
  });

  test('reads images by their exact path, with no prefix, once', () async {
    final source = AssetSource.bundle(bundle);
    const path = AssetPath('assets/images/a.png');
    final first = await source.loadImage(path);
    final second = await source.loadImage(path);
    expect(first.width, 4);
    expect(second, same(first));
    expect(bundle.loads, ['assets/images/a.png']);
  });

  test('a failed image load is not cached', () async {
    final source = AssetSource.bundle(bundle);
    const path = AssetPath('assets/images/a.png');
    bundle.fail = true;
    await expectLater(source.loadImage(path), throwsA(isA<FlutterError>()));
    bundle.fail = false;
    expect((await source.loadImage(path)).width, 4);
    expect(bundle.loads, ['assets/images/a.png', 'assets/images/a.png']);
  });

  test('defaults to rootBundle', () {
    final source = AssetSource.bundle() as BundleAssetSource;
    expect(source.bundle, same(rootBundle));
  });
}
