/// デバウンスの固定（決定 D44）.
///
/// ★`testWidgets` を使うのはウィジェットが要るからではない。
/// `Timer` を進める手段（`tester.pump(Duration)`）がここにしか無いため。
/// 素の `test` で書くと実時間を待つことになり、遅くて不安定になる。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/ui/common/debouncer.dart';

void main() {
  test('既定は 150ms（決定 D44 の実測値）', () {
    expect(Debouncer.defaultDelay, const Duration(milliseconds: 150));
    expect(Debouncer().delay, const Duration(milliseconds: 150));
  });

  testWidgets('待ち時間の途中では実行されない', (tester) async {
    var calls = 0;
    final debouncer = Debouncer()..run(() => calls++);
    addTearDown(debouncer.dispose);

    await tester.pump(const Duration(milliseconds: 149));
    expect(calls, 0, reason: '149ms では発火しない');

    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
  });

  testWidgets('★連続して呼ぶと最後の 1 回だけ実行される', (tester) async {
    final executed = <String>[];
    final debouncer = Debouncer();
    addTearDown(debouncer.dispose);

    // 打鍵 120ms 相当で 8 回（`docs/UI技術検証メモ.md` §4-3 と同じ条件）。
    for (final s in ['ス', 'スク', 'スクー', 'スクール', 'スクールア', 'スクールアイ',
      'スクールアイド', 'スクールアイドル']) {
      debouncer.run(() => executed.add(s));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 150));

    // ★150ms は打鍵間隔 120ms を上回るので 1 回に畳める。
    //   100ms だと 8 回とも走る（＝待ち時間だけ増えて損 / 決定 D44）。
    expect(executed, ['スクールアイドル']);
  });

  testWidgets('cancel は保留を捨てる。実行はしない', (tester) async {
    var calls = 0;
    final debouncer = Debouncer()..run(() => calls++);
    addTearDown(debouncer.dispose);

    expect(debouncer.isPending, isTrue);
    debouncer.cancel();
    expect(debouncer.isPending, isFalse);

    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0);
  });

  testWidgets('★dispose 後は発火もしないし受け付けもしない', (tester) async {
    var calls = 0;
    final debouncer = Debouncer()..run(() => calls++);

    debouncer.dispose();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0, reason: '画面を閉じたあとに Store を触らせない');

    debouncer.run(() => calls++);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0);
  });
}
