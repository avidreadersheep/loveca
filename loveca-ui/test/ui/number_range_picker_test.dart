/// Android の数値の指定（`docs/Android UI 決定.md` §3-7）.
///
/// ★★ 何を固定するか ★★
/// ★**値の欄は★★ボタンである★★**（★キーボードで打たせない）／
/// ★**リストは 未指定 ＋ 0 から上限まで** / ★**絞り込みはリストそのものを絞る** /
/// ★★**キャンセルと「未指定を選んだ」を分ける**★★ / ★**上限は★実データから導く**。
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**実機**（★ウィジェット試験は Android を 1 バイトも走らせない）／
/// ★**呼ぶ側**（★★`lib` に 1 つも無い★★ / **D-20** —— ★§3-6 の絞り込みチップが 1 行も無い）／
/// ★**どの色を出すか**（★★この層は色を 1 つも知らない★★ / §12-6）／
/// ★★**`min > max` を止めていない**★★（★§3-7 が述べていない / ★下の群が★★止めないことを固定する★★）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' as core;
import 'package:loveca_ui/src/ui/browse/number_range_picker.dart';
import 'package:path/path.dart' as p;

import '../support/strip_comments.dart';

core.Card _card({int? cost, int? blade, int? score, int heartTotal = 0}) =>
    core.Card(
      cardNumber: 'X-$cost-$blade-$score-$heartTotal',
      name: 'n',
      cardType: core.CardType.member,
      cost: cost,
      bladeCount: blade,
      score: score,
      heartTotal: heartTotal,
    );

Future<void> _pumpField(
  WidgetTester tester, {
  required NumberRange range,
  required int max,
  required List<NumberRange> changed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NumberRangeField(
          label: '合計ハート',
          range: range,
          max: max,
          onChanged: changed.add,
        ),
      ),
    ),
  );
}

Future<void> _openMin(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('numberRange:合計ハート:min')));
  await tester.pumpAndSettle();
}

Future<void> _tapOption(WidgetTester tester, int? value) async {
  final target =
      find.byKey(ValueKey('numberPickerSheet:option:${value ?? 'none'}'));
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('numberPickerSheet:list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('純粋関数 —— 選択肢の列', () {
    test('未指定 が先頭に 1 つ在り、そのあと 0 から上限まで並ぶ', () {
      expect(numberPickerOptions(3), [null, 0, 1, 2, 3]);
      expect(numberPickerOptions(0), [null, 0]);
    });

    test('★対: 上限を 1 つも超えない', () {
      expect(numberPickerOptions(22), hasLength(24));
      expect(numberPickerOptions(22).last, 22);
    });

    test('字面は 未指定 と数字である', () {
      expect(numberOptionLabel(null), '未指定');
      expect(numberOptionLabel(0), '0');
      expect(numberOptionLabel(21), '21');
    });
  });

  group('純粋関数 —— 絞り込み', () {
    test('空なら何も落とさない', () {
      final all = numberPickerOptions(3);
      expect(filterNumberOptions(all, ''), all);
      expect(filterNumberOptions(all, '   '), all);
    });

    test('数字で絞ると★含むものが残る（★既定値）', () {
      final all = numberPickerOptions(22);
      expect(filterNumberOptions(all, '1'),
          [1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21]);
    });

    test('★対: 前方一致ではない（★21 が「1」で残る）', () {
      expect(filterNumberOptions(numberPickerOptions(22), '1'), contains(21));
    });

    test('未指定 も絞り込みの対象である', () {
      expect(filterNumberOptions(numberPickerOptions(3), '未'), [null]);
      // ★★ 対 —— ★数字で絞ると 未指定 は消える ★★
      expect(filterNumberOptions(numberPickerOptions(3), '2'), [2]);
    });
  });

  group('純粋関数 —— 上限を実データから導く（§3-7）', () {
    test('コスト / ブレード / スコア / 合計ハート の最大を採る', () {
      final cards = [
        _card(cost: 3, blade: 2, score: 1, heartTotal: 4),
        _card(cost: 22, blade: 7, score: 9, heartTotal: 9),
      ];
      expect(numberAxisMax(cards, (c) => c.cost), 22);
      expect(numberAxisMax(cards, (c) => c.bladeCount), 7);
      expect(numberAxisMax(cards, (c) => c.score), 9);
      expect(numberAxisMax(cards, (c) => c.heartTotal), 9);
    });

    test('null は数えない', () {
      final cards = [_card(cost: null), _card(cost: 5)];
      expect(numberAxisMax(cards, (c) => c.cost), 5);
    });

    test('1 枚も持っていなければ 0 である', () {
      expect(numberAxisMax(const <core.Card>[], (c) => c.cost), 0);
      expect(numberAxisMax([_card(cost: null)], (c) => c.cost), 0);
    });

    test('★対: 色ごとの上限も同じ口で導ける（★この層は色を知らない）', () {
      final cards = [
        core.Card(
          cardNumber: 'a',
          name: 'n',
          cardType: core.CardType.member,
          hearts: const {core.HeartColor.pink: 6},
        ),
        core.Card(
          cardNumber: 'b',
          name: 'n',
          cardType: core.CardType.member,
          hearts: const {core.HeartColor.pink: 2},
        ),
      ];
      expect(
        numberAxisMax(cards, (c) => c.hearts[core.HeartColor.pink]),
        6,
      );
    });
  });

  group('画面 —— 軸の行', () {
    testWidgets('未指定 のときは両方の欄が「未指定」と出る', (tester) async {
      await _pumpField(
        tester,
        range: (min: null, max: null),
        max: 9,
        changed: [],
      );
      expect(find.text('未指定'), findsNWidgets(2));
      expect(find.text('合計ハート'), findsOneWidget);
    });

    testWidgets('値が入っていればその数字が出る', (tester) async {
      await _pumpField(
        tester,
        range: (min: 0, max: 4),
        max: 9,
        changed: [],
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('未指定'), findsNothing);
    });

    testWidgets('★キーボードで打たせない —— ★値の行に TextField が 1 つも無い',
        (tester) async {
      await _pumpField(
        tester,
        range: (min: null, max: null),
        max: 9,
        changed: [],
      );
      expect(find.byType(TextField), findsNothing);
      // ★★ 対 —— ★フォームを開くと★絞り込みの TextField が 1 本だけ出る ★★
      await _openMin(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('★min > max を止めていない（★§3-7 が述べていない / ★既定値）',
        (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: null, max: 2),
        max: 9,
        changed: changed,
      );
      await _openMin(tester);
      await _tapOption(tester, 5);
      // ★★ 入れ替えない。★断らない ★★
      expect(changed, [(min: 5, max: 2)]);
    });
  });

  group('画面 —— フォーム', () {
    testWidgets('未指定 と 0 から上限までが並び、いまの値に印が付く', (tester) async {
      await _pumpField(
        tester,
        range: (min: 2, max: null),
        max: 4,
        changed: [],
      );
      await _openMin(tester);
      expect(find.byKey(const ValueKey('numberPickerSheet')), findsOneWidget);
      Finder tileAt(int? v) =>
          find.byKey(ValueKey('numberPickerSheet:option:${v ?? 'none'}'));
      expect(tileAt(null), findsOneWidget);
      expect(tileAt(4), findsOneWidget);
      expect(
        find.descendant(of: tileAt(2), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      // ★★ 対 —— ★ほかの行には付かない ★★
      expect(
        find.descendant(of: tileAt(0), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('数字を選ぶと下の欄に入る', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: null, max: null),
        max: 4,
        changed: changed,
      );
      await _openMin(tester);
      await _tapOption(tester, 3);
      expect(changed, [(min: 3, max: null)]);
    });

    testWidgets('上の欄を押すと★上だけが変わる', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: 1, max: null),
        max: 4,
        changed: changed,
      );
      await tester.tap(find.byKey(const ValueKey('numberRange:合計ハート:max')));
      await tester.pumpAndSettle();
      await _tapOption(tester, 4);
      expect(changed, [(min: 1, max: 4)]);
    });

    testWidgets('未指定 を選ぶと 未指定 になる', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: 2, max: null),
        max: 4,
        changed: changed,
      );
      await _openMin(tester);
      await _tapOption(tester, null);
      expect(changed, [(min: null, max: null)]);
    });

    testWidgets('★キャンセルは何も変えない（★未指定を選んだのと区別する）', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: 2, max: null),
        max: 4,
        changed: changed,
      );
      await _openMin(tester);
      await tester.tap(find.byKey(const ValueKey('numberPickerSheet:cancel')));
      await tester.pumpAndSettle();
      expect(changed, isEmpty);
    });

    testWidgets('クリアは 未指定 にする（★★選んだのと同じ結果になる★★）', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: 2, max: null),
        max: 4,
        changed: changed,
      );
      await _openMin(tester);
      await tester.tap(find.byKey(const ValueKey('numberPickerSheet:clear')));
      await tester.pumpAndSettle();
      expect(changed, [(min: null, max: null)]);
    });

    testWidgets('絞り込みでリストが減る（★★クリアはそれでも押せる★★）', (tester) async {
      final changed = <NumberRange>[];
      await _pumpField(
        tester,
        range: (min: 2, max: null),
        max: 4,
        changed: changed,
      );
      await _openMin(tester);
      await tester.enterText(
        find.byKey(const ValueKey('numberPickerSheet:query')),
        '3',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('numberPickerSheet:option:3')),
        findsOneWidget,
      );
      // ★★ 「未指定」は消える ★★
      expect(
        find.byKey(const ValueKey('numberPickerSheet:option:none')),
        findsNothing,
      );
      // ★★ それでも「クリア」は押せる（★§3-7 が 2 つを置いたことの★実際の違い）★★
      await tester.tap(find.byKey(const ValueKey('numberPickerSheet:clear')));
      await tester.pumpAndSettle();
      expect(changed, [(min: null, max: null)]);
    });

    testWidgets('絞り込みの ✕ で文字が消え、リストが戻る', (tester) async {
      await _pumpField(
        tester,
        range: (min: null, max: null),
        max: 4,
        changed: [],
      );
      await _openMin(tester);
      await tester.enterText(
        find.byKey(const ValueKey('numberPickerSheet:query')),
        '3',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('numberPickerSheet:option:none')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('numberPickerSheet:clearQuery')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('numberPickerSheet:option:none')),
        findsOneWidget,
      );
    });
  });

  group('走査 —— 共有そのものの受け（**D-27** の (乙)）', () {
    test('★フォームが★列と絞り込みの純粋関数を実際に呼んでいる', () {
      // ★★ 共有しただけでは★戻されたことに 1 つも気づけない ★★
      //   ★**自分で回しても★★出る値は 1 つも変わらない★★**（★先例は `deck_count_band` の (N)）。
      final src = stripComments(
        File(p.join('lib', 'src', 'ui', 'browse', 'number_range_picker.dart'))
            .readAsStringSync(),
      );
      expect(src.contains('filterNumberOptions('), isTrue);
      expect(src.contains('numberPickerOptions(widget.max)'), isTrue);
      // ★★ 上限を回す式は★宣言の 1 か所だけである ★★
      expect('i <= max'.allMatches(src).length, 1);
      // ★★ 陽性対照（**D-10**）—— ★コメントを外す処理が働いていること ★★
      //   ★**doc には「測った値」の数字が在る**（★§12-5 の写し）。
      //   ★★**外したあとの本文には 1 つも無い**★★。
      expect(src.contains('コスト 22'), isFalse);
    });
  });
}
