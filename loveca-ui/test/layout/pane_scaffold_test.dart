/// `PaneScaffold` の 1 ペイン ⇄ 2 ペイン切替（決定 D61 / D52 の (c)）.
///
/// ★決定 D52 は「モバイルは設計だけ通す」と定めたが、
/// **「設計だけ通す」を「切替は動く」まで引き上げる**ためにここで固定する。
/// ウィンドウ幅を縮めての切替は Windows でも確認できる。
///
/// ★これはモバイルで動く保証ではない（`docs/UI設計メモ.md` §7）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/ui/layout/pane_scaffold.dart';

/// 指定した論理幅でウィジェットを描く。
///
/// `tester.view.physicalSize` は物理px なので、`devicePixelRatio` を 1 に固定して
/// 論理px と一致させる。★しきい値は論理px で定義されている。
Future<void> _pumpAtWidth(WidgetTester tester, double logicalWidth) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(logicalWidth, 800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PaneScaffold(
          primary: Builder(
            builder: (context) => Text(
              PaneScaffold.isTwoPaneOf(context) ? 'two' : 'one',
            ),
          ),
          secondary: const Text('secondary'),
        ),
      ),
    ),
  );
}

void main() {
  group('決定 D61: しきい値 ${PaneScaffold.twoPaneMinWidth} 論理px', () {
    testWidgets('しきい値ちょうどでは 2 ペイン', (tester) async {
      await _pumpAtWidth(tester, PaneScaffold.twoPaneMinWidth);

      expect(find.text('secondary'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('しきい値を 1 下回ると 1 ペインになり secondary は描かれない',
        (tester) async {
      await _pumpAtWidth(tester, PaneScaffold.twoPaneMinWidth - 1);

      // ★描かれないこと自体を固定する。
      //   隠すだけ（Offstage / Visibility）にすると、見えないのに
      //   build と画像デコードが走る状態を見逃す。
      expect(find.text('secondary'), findsNothing);
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('十分広ければ 2 ペイン', (tester) async {
      await _pumpAtWidth(tester, 1280);

      expect(find.text('secondary'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('狭ければ 1 ペイン', (tester) async {
      await _pumpAtWidth(tester, 400);

      expect(find.text('secondary'), findsNothing);
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('幅を跨いで変えると切り替わる', (tester) async {
      await _pumpAtWidth(tester, 1280);
      expect(find.text('two'), findsOneWidget);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
      expect(find.text('secondary'), findsNothing);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      expect(find.text('secondary'), findsOneWidget);
    });
  });

  group('★ header は全幅で載り、判定結果が読める（M4 で追加）', () {
    // ★★ これが無いと「1 ペインのときだけ出す」が黙って効かない ★★
    // M3 までは `Scaffold.appBar` の中から isTwoPaneOf を呼んでいたが、
    // _PaneScope は body の中で作られるので AppBar からは辿れず、
    // **常に false** になっていた（下の「外では false」がその性質そのもの）。
    Future<void> pumpWithHeader(WidgetTester tester, double width) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaneScaffold(
              header: Builder(
                builder: (context) => Text(
                  PaneScaffold.isTwoPaneOf(context)
                      ? 'header:two'
                      : 'header:one',
                ),
              ),
              primary: const Text('primary'),
              secondary: const Text('secondary'),
            ),
          ),
        ),
      );
    }

    testWidgets('2 ペインのとき header から two が読める', (tester) async {
      await pumpWithHeader(tester, 1280);

      expect(find.text('header:two'), findsOneWidget);
      expect(find.text('secondary'), findsOneWidget);
    });

    testWidgets('1 ペインのとき header から one が読める', (tester) async {
      await pumpWithHeader(tester, 400);

      expect(find.text('header:one'), findsOneWidget);
      expect(find.text('secondary'), findsNothing);
    });

    testWidgets('★header は両ペインの上に全幅で載る', (tester) async {
      await pumpWithHeader(tester, 1280);

      // 全幅 = ウィンドウ幅。secondary の幅に切り詰められていないこと。
      expect(tester.getSize(find.text('header:two')).width, lessThanOrEqualTo(1280));
      expect(
        tester.getTopLeft(find.text('header:two')).dy,
        lessThan(tester.getTopLeft(find.text('primary')).dy),
      );
    });
  });

  testWidgets('PaneScaffold の外では isTwoPaneOf が false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Text(PaneScaffold.isTwoPaneOf(context) ? 'two' : 'one'),
        ),
      ),
    );

    expect(find.text('one'), findsOneWidget);
  });
}
