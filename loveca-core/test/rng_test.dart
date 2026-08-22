import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

void main() {
  group('DeterministicRng', () {
    test('★同じ seed なら同じシャッフル結果になる', () {
      final source = List.generate(20, (i) => i);
      final a = SeededRng(12345).shuffled(source);
      final b = SeededRng(12345).shuffled(source);
      expect(a, b);
    });

    test('違う seed なら並びが変わる', () {
      final source = List.generate(20, (i) => i);
      expect(SeededRng(1).shuffled(source),
          isNot(SeededRng(2).shuffled(source)));
    });

    test('元のリストを破壊せず、要素は保存される (5.5.1)', () {
      final source = List.generate(10, (i) => i);
      final shuffled = SeededRng(7).shuffled(source);
      expect(source, List.generate(10, (i) => i), reason: '破壊していない');
      expect(shuffled.toSet(), source.toSet(), reason: '要素が保存されている');
      expect(shuffled.length, source.length);
    });

    test('0 枚・1 枚でもシャッフルは成立する (5.5.1.2)', () {
      expect(SeededRng(1).shuffled(<int>[]), isEmpty);
      expect(SeededRng(1).shuffled([42]), [42]);
    });

    test('seed を保持して再現に使える', () {
      final rng = SeededRng(99);
      expect(rng.seed, 99);
    });
  });
}
