import 'package:pyro_annotations/pyro_annotations.dart';
import 'package:test/test.dart';

void main() {
  test('annotations are const with and without arguments', () {
    const behaviors = [
      PyroBehavior(),
      PyroBehavior(label: 'Patrol', category: 'Movement', id: 'enemy.patrol'),
    ];
    const components = [
      PyroComponent(),
      PyroComponent(
        label: 'Boss',
        category: 'Enemies',
        id: 'enemy.boss',
        preview: 'assets/images/boss.png',
      ),
    ];
    const editables = [
      Editable(),
      Editable(min: 0, max: 400, tooltip: 'Pixels per second', label: 'Speed'),
    ];
    expect(behaviors[1].id, 'enemy.patrol');
    expect(components[1].preview, 'assets/images/boss.png');
    expect(editables[1].max, 400);
  });

  group('ImagePath', () {
    test('is const and compares by path', () {
      const a = ImagePath('assets/images/a.png');
      expect(a, const ImagePath('assets/images/a.png'));
      expect(a, isNot(const ImagePath('assets/images/b.png')));
      expect(a.hashCode, const ImagePath('assets/images/a.png').hashCode);
    });

    test('toString names the path', () {
      expect(const ImagePath('a').toString(), 'ImagePath(a)');
    });
  });
}
