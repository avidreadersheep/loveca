/// ★★ タッチで `Tooltip` が読めるか（`docs/UI設計メモ.md` §7 の 6 ／ **W-25**）★★
///
/// ★★ 直していない。★測っただけである ★★
/// ★**§7 の 6 は「★判断は Phase 5。★★いま決めない★★」と★自ら書いている。**
/// → ★**この群は★★いまの挙動を固定する★★。★直すと落ちる。★それが合図である**（★先例は **D-24** / **W-24**）。
///
/// ## ★★ 何を測るか（★3 つ。★層を分ける / §7-10）★★
///
/// | # | 何 | ★層 |
/// |---|---|---|
/// | ★**1** | ★**マウスを乗せると出るか** | ★**PC** |
/// | ★★**2**★★ | ★★**触って長押しすると出るか**★★ | ★★**モバイル**★★ |
/// | ★**3** | ★**触って叩くだけでは出ないか** | ★同上 |
///
/// ★★ 「タッチでは出ない」は★★どちらの意味かで真偽が変わる★★ ★★
/// ★**(i) 乗せる操作が無いので★★出す手立てが目に入らない★★** → ★**真**
/// ★**(ii) 出す方法が 1 つも無い** → ★★**偽である**★★（★長押しで出る。★下の群が実測する）
/// → ★**§7 の 6 の字面は 1 文字も書き換えない**（**D-35**）。★**この doc に測った結果を置く。**
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/ui/browse/card_grid.dart';

import '../support/fake_deck_repository.dart';
import '../support/recording_image_source.dart';
import '../support/source_scan.dart';

/// ★★ 本番の口を通す（**D-27** の (甲)）★★
/// ★**合成の `Tooltip` を自分で組むと、★★本番が Tooltip を持っていなくても対は通る★★。**
Widget _grid({void Function(BuildContext, dynamic)? onCardTap}) => MaterialApp(
      home: Scaffold(
        body: CardGrid(
          rows: fakeRows,
          imageSource: RecordingImageSource(),
          onCardTap: onCardTap,
        ),
      ),
    );

void main() {
  group('★★ 陽性対照 —— ★本番が Tooltip を持っていること（**D-10**）★★', () {
    testWidgets('★★ 一覧のセルは `Tooltip` に包まれている ★★', (tester) async {
      await tester.pumpWidget(_grid());
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('★★ その文言は★刷り番号を含む（★何にでも当たる検査ではない）★★',
        (tester) async {
      await tester.pumpWidget(_grid());
      await tester.pumpAndSettle();

      final tips = tester.widgetList<Tooltip>(find.byType(Tooltip));
      expect(tips.map((t) => t.message).join('\n'), contains('M-1-N'));
    });
  });

  group('★★ 1. マウスを乗せると出る（★PC）★★', () {
    testWidgets('★★ hover で文言が現れる ★★', (tester) async {
      await tester.pumpWidget(_grid());
      await tester.pumpAndSettle();

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(Tooltip).first));
      // ★`waitDuration` は 600 ms（`card_grid.dart`）。★超えるまで進める。
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.textContaining('M-1-N'), findsWidgets);
    });
  });

  group('★★ 2. 触って長押しすると★★出る★★（★モバイル）★★', () {
    testWidgets('★★ 長押しで文言が現れる ★★', (tester) async {
      await tester.pumpWidget(_grid());
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(Tooltip).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('M-1-N'), findsWidgets,
          reason: '★★出る方法が 1 つも無い、は偽である★★');
    });
  });

  group('★★ 走査 —— ★§7 の 6 の「同じ形が R2〜R6 にもある」を★実物に当てる ★★', () {
    // ★★ 読みが 2 つある。★別々に測る（§7-7）★★
    //   ★**(i)「Tooltip でしか読めない情報が R2〜R6 に在る」** → ★下の 1 つ目
    //   ★**(ii)「無効なボタンの理由が Tooltip に出る形が R2〜R6 に在る」** → ★下の 2 つ目
    final tips = scanDart('lib/src/ui', RegExp(r'Tooltip\('));
    final outsideBoard = <String, int>{
      for (final e in tips.entries)
        if (!e.key.startsWith('board_')) e.key: e.value,
    };

    test('★★ 陽性対照 —— ★走査が当たる（**D-10**）★★', () {
      expect(tips, isNotEmpty);
      expect(tips.keys.where((k) => k.startsWith('board_')), isNotEmpty,
          reason: '★盤面に在ることは §7 の 6 が前提にしている');
    });

    test('★★ (i) 盤面の外にも `Tooltip` は在る ★★', () {
      expect(outsideBoard, isNotEmpty,
          reason: '★★§7 の 6 の「同じ形が R2〜R6 にもある」は★この読みでは真★★');
    });

    test('★★ (ii) 盤面の外の `Tooltip` は★無効なボタンに付いていない ★★', () {
      // ★★ 実測（2026-09-02）—— ★盤面の外の Tooltip は
      //   ★**一覧のセル**（`card_grid.dart`）と ★**アイコン**（`deck_share_import_dialog.dart`）だけである。
      //   ★**無効なボタン（`onPressed: null`）に Tooltip を付けた箇所は★★0 件★★**。
      //   → ★★**§7 の 6 の「無効なボタンの理由」という形は★R2〜R6 に無い**★★。
      //   ★**「§7 の 6 が誤り」とは書かない** —— ★あちらは
      //   ★「★★同じ形★★が R2〜R6 にもある」と書いており、★★どの読みかを述べていない★★。
      expect(outsideBoard.keys.toSet(), <String>{
        'card_grid.dart',
        'deck_share_import_dialog.dart',
      });
    });
  });

  group('★★ 3. 触って叩くだけでは★出ない（★これが「読めない」の中身）★★', () {
    testWidgets('★★ タップでは文言が現れない ★★', (tester) async {
      await tester.pumpWidget(_grid());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Tooltip).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('クリックで詳細'), findsNothing);
    });
  });
}
