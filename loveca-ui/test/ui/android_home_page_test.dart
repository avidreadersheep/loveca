/// ★★ Android の画面の構成 —— ★★下段タブ 3 つ★★（`docs/Android UI 決定.md` §3-1）★★
///
/// ★★ この試験が覆わないもの（★言い切る）★★
/// ★**1)** ★★実機★★ —— ★ウィジェット試験は Android を 1 バイトも走らせない。
/// ★**2)** ★**呼ぶ側** —— ★★`lib` に 1 つも無い★★（**D-20** を承知で置いた）。
/// ★**3)** ★**タブの絵** —— ★★選んでいない★★（★§3-1 は字面しか述べていない / **D-28**）。
/// ★**4)** ★**タブの高さ / 押しやすさ** —— ★★測っていない★★。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/ui/android/android_home_page.dart';

Future<void> _pump(WidgetTester tester, {int initialIndex = 0}) =>
    tester.pumpWidget(
      MaterialApp(
        home: AndroidHomePage(
          initialIndex: initialIndex,
          tabs: <Widget>[
            for (var i = 0; i < kAndroidTabLabels.length; i++)
              Center(child: Text('中身 $i')),
          ],
        ),
      ),
    );

void main() {
  group('★★ 下段タブ（★§3-1）★★', () {
    testWidgets('★★ 並びは `kAndroidTabLabels` から来る（★書き写さない）★★',
        (tester) async {
      await _pump(tester);
      for (final label in kAndroidTabLabels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('★★ 本数は 3 —— ★「新商品」を置かない（★§3-1）★★', (tester) async {
      await _pump(tester);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      // ★★ 対: ★WS の 4 つ目に当たる字面が 1 つも出ない ★★
      expect(find.text('新商品'), findsNothing);
    });

    testWidgets('★ 最初は 1 つ目の中身が出る', (tester) async {
      await _pump(tester);
      expect(
        tester.widget<IndexedStack>(find.byKey(const ValueKey('androidHome:body'))).index,
        0,
      );
    });

    testWidgets('★ 押すと切り替わる', (tester) async {
      await _pump(tester);
      await tester.tap(find.text(kAndroidTabLabels[2]));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(find.byKey(const ValueKey('androidHome:body'))).index,
        2,
      );
    });

    testWidgets('★★ `initialIndex` で始まる位置を変えられる（★§3-1 は述べていない）★★',
        (tester) async {
      await _pump(tester, initialIndex: 1);
      expect(
        tester.widget<IndexedStack>(find.byKey(const ValueKey('androidHome:body'))).index,
        1,
      );
    });

    testWidgets('★★ 木を捨てない —— ★見えていないタブも作られている ★★', (tester) async {
      // ★★ `IndexedStack` は 3 つとも作る（★★スクロール位置や入力中の字が消えない★★）★★
      //   ★**対: ★`PageView` や `switch` で作り直す形だと★★1 つしか無い★★。**
      await _pump(tester);
      expect(find.text('中身 0', skipOffstage: false), findsOneWidget);
      expect(find.text('中身 1', skipOffstage: false), findsOneWidget);
      expect(find.text('中身 2', skipOffstage: false), findsOneWidget);
    });

    testWidgets('★★ 選ばれているものを押しても★変わらない（★外れない）★★', (tester) async {
      await _pump(tester, initialIndex: 1);
      await tester.tap(find.text(kAndroidTabLabels[1]));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byKey(const ValueKey('androidHome:tabs')))
            .selectedIndex,
        1,
      );
    });
  });
}
