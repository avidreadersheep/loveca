/// Android の枚数の帯（`docs/Android UI 決定.md` §3-8）.
///
/// ★★ 何を固定するか ★★
/// ★**0 枚のときだけ 0 が列から消える** / ★**「…」はエネルギーだけ** /
/// ★**同じ数字を再度押すと何も起きない** / ★**大きな数字は 0 枚では出さない** /
/// ★**4 枚を超えても押せる**（§1-3 —— ★★`canAdd` を 1 度も呼ばない★★）。
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**実機**（★ウィジェット試験は Android を 1 バイトも走らせない）／
/// ★**呼ぶ側**（★★`lib` に 1 つも無い★★ / **D-20**）／
/// ★**帯の高さ / 押しやすさ**（★★測っていない★★ / **D-28**）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/deck_count_band.dart';
import 'package:path/path.dart' as p;

import '../support/strip_comments.dart';

/// フォームの [value] を叩く。
///
/// ★★ 先に見えるところまで送る ★★
/// ★**`ListView` は画面外を作らない**（`CLAUDE.md` §3 の M5 の作法）——
/// ★★送らずに叩くと★★「見えていない」と「無い」の区別がつかない★★（**D-10**）。
Future<void> _tapPickerItem(WidgetTester tester, int value) async {
  final target = find.byKey(ValueKey('deckCountFullPicker:$value'));
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required CardType cardType,
  required int count,
  required List<int> selected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeckCountBand(
          cardType: cardType,
          count: count,
          onSelect: selected.add,
        ),
      ),
    ),
  );
}

void main() {
  group('純粋関数 —— 帯の中身（§3-8 の表）', () {
    test('0 枚のときは 0 を出さない', () {
      final spec = deckCountBandOf(cardType: CardType.member, count: 0);
      expect(spec.numbers, [1, 2, 3, 4]);
      expect(spec.bigNumber, isNull);
    });

    test('1 枚以上のときは 0 が左に現れる', () {
      final spec = deckCountBandOf(cardType: CardType.member, count: 1);
      expect(spec.numbers, [0, 1, 2, 3, 4]);
      expect(spec.bigNumber, 1);
    });

    test('★対: 上限は RuleConfig から来る（★字面ではない）', () {
      final spec = deckCountBandOf(
        cardType: CardType.member,
        count: 1,
        config: const RuleConfig(maxCopiesPerCardNumber: 2),
      );
      expect(spec.numbers, [0, 1, 2]);
    });

    test('「…」はエネルギーだけに出る', () {
      expect(
        deckCountBandOf(cardType: CardType.energy, count: 0).hasMore,
        isTrue,
      );
      // ★★ 対 —— ★メンバー / ライブには出ない（★6.1.1.2 は「メインデッキには」）★★
      expect(
        deckCountBandOf(cardType: CardType.member, count: 0).hasMore,
        isFalse,
      );
      expect(
        deckCountBandOf(cardType: CardType.live, count: 0).hasMore,
        isFalse,
      );
    });

    test('フォームの上限はエネルギーだけ在り、RuleConfig から来る', () {
      expect(
        deckCountBandOf(cardType: CardType.energy, count: 0).moreMax,
        12,
      );
      expect(
        deckCountBandOf(cardType: CardType.member, count: 0).moreMax,
        isNull,
      );
      expect(
        deckCountBandOf(
          cardType: CardType.energy,
          count: 0,
          config: const RuleConfig(energyDeckSize: 8),
        ).moreMax,
        8,
      );
    });

    test('4 枚を超えていても列は変わらず、大きな数字が実数を出す（§1-3）', () {
      final spec = deckCountBandOf(cardType: CardType.energy, count: 12);
      expect(spec.numbers, [0, 1, 2, 3, 4]);
      expect(spec.bigNumber, 12);
    });
  });

  group('純粋関数 —— 見た目と空振り', () {
    test('選択中はオレンジ / 0 は灰色 / それ以外は素のまま', () {
      expect(deckCountEmphasisOf(2, 2), DeckCountEmphasis.selected);
      expect(deckCountEmphasisOf(0, 2), DeckCountEmphasis.zero);
      expect(deckCountEmphasisOf(3, 2), DeckCountEmphasis.plain);
    });

    test('★選択中が 0 のときは「選択中」を採る（★合成の入力でしか作れない）', () {
      expect(deckCountEmphasisOf(0, 0), DeckCountEmphasis.selected);
    });

    test('同じ数字は空振りである', () {
      expect(deckCountIsNoop(2, 2), isTrue);
      expect(deckCountIsNoop(3, 2), isFalse);
      expect(deckCountIsNoop(0, 0), isTrue);
    });

    test('フォームの列は 0 から上限までで、★上限を 1 つも超えない', () {
      expect(deckCountPickerValues(12), hasLength(13));
      expect(deckCountPickerValues(12).first, 0);
      expect(deckCountPickerValues(12).last, 12);
      // ★★ 対 —— ★上限が変われば列も変わる（★「常に 13 個」と区別できる形）★★
      expect(deckCountPickerValues(3), [0, 1, 2, 3]);
    });
  });

  group('画面 —— 帯', () {
    testWidgets('0 枚では 0 のボタンも大きな数字も出ない', (tester) async {
      await _pump(
        tester,
        cardType: CardType.member,
        count: 0,
        selected: [],
      );
      expect(find.byKey(const ValueKey('deckCountBand:0')), findsNothing);
      expect(find.byKey(const ValueKey('deckCountBand:1')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckCountBand:4')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckCountBand:big')), findsNothing);
    });

    testWidgets('1 枚以上では 0 のボタンと大きな数字が出る', (tester) async {
      await _pump(
        tester,
        cardType: CardType.member,
        count: 3,
        selected: [],
      );
      expect(find.byKey(const ValueKey('deckCountBand:0')), findsOneWidget);
      final big = tester.widget<Text>(
        find.byKey(const ValueKey('deckCountBand:big')),
      );
      expect(big.data, '3');
    });

    testWidgets('選択中の数字だけがオレンジで、0 は灰色である', (tester) async {
      await _pump(
        tester,
        cardType: CardType.member,
        count: 2,
        selected: [],
      );
      Color? colorOf(int v) => tester
          .widget<Text>(find.byKey(ValueKey('deckCountBand:label:$v')))
          .style
          ?.color;
      expect(colorOf(2), DeckCountBand.selectedColor);
      expect(colorOf(0), DeckCountBand.zeroColor);
      // ★★ 対 —— ★それ以外は 2 つのどちらでもない（★「常に色を付ける」と区別できる形）★★
      //   ★**`isNull` では見ない** —— ★★`copyWith(color: null)` は元の色を落とさない★★
      //   （★先例は `deck_counters_band_test.dart` で同じ罠を踏んだ / `CLAUDE.md` §3）。
      expect(colorOf(1), isNot(DeckCountBand.selectedColor));
      expect(colorOf(1), isNot(DeckCountBand.zeroColor));
      expect(colorOf(4), colorOf(1));
    });

    testWidgets('数字を押すと枚数が返る', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.member,
        count: 1,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:4')));
      await tester.pump();
      expect(selected, [4]);
    });

    testWidgets('0 を押すと 0 が返る（★灰色でも押せる）', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.member,
        count: 1,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:0')));
      await tester.pump();
      expect(selected, [0]);
    });

    testWidgets('同じ数字を再度押しても何も起きない（§3-8）', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.member,
        count: 2,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:2')));
      await tester.pump();
      expect(selected, isEmpty);
      // ★★ 対 —— ★別の数字なら返る（★「常に何も起きない」と区別できる形）★★
      await tester.tap(find.byKey(const ValueKey('deckCountBand:3')));
      await tester.pump();
      expect(selected, [3]);
    });

    testWidgets('「…」はエネルギーだけに出る', (tester) async {
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 0,
        selected: [],
      );
      expect(find.byKey(const ValueKey('deckCountBand:more')), findsOneWidget);
      await _pump(
        tester,
        cardType: CardType.member,
        count: 0,
        selected: [],
      );
      expect(find.byKey(const ValueKey('deckCountBand:more')), findsNothing);
    });

    testWidgets('4 枚を超えて入っていても押せる（§1-3 —— ★canAdd を見ない）',
        (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 12,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:4')));
      await tester.pump();
      expect(selected, [4]);
    });
  });

  group('画面 —— 「…」のフォーム', () {
    testWidgets('0 から 12 まで並び、いまの枚数に印が付く', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 5,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deckCountFullPicker')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckCountFullPicker:0')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('deckCountFullPicker:12')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('deckCountFullPicker:12')),
        findsOneWidget,
      );
      // ★★ 「上限を 1 つ超えたものが無いこと」は★ここでは見ない ★★
      //   ★**`ListView` は画面外を作らないので★★見えないことと無いことの区別がつかない★★**
      //   （**D-10** / ★実測: ★★上限を 1 つ増やしても★この群は 0 件だった★★）。
      //   → ★**列そのものは `deckCountPickerValues` の群が見る。**
    });

    testWidgets('いまの枚数に印が付く（★対: 別の枚数には付かない）', (tester) async {
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 2,
        selected: [],
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:more')));
      await tester.pumpAndSettle();
      Finder tileAt(int v) => find.byKey(ValueKey('deckCountFullPicker:$v'));
      expect(
        find.descendant(of: tileAt(2), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      // ★★ 対 —— ★ほかの行には付かない（★「常に付ける」と区別できる形）★★
      expect(
        find.descendant(of: tileAt(0), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
      expect(
        find.descendant(of: tileAt(3), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('フォームで選ぶと枚数が返る', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 0,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:more')));
      await tester.pumpAndSettle();
      await _tapPickerItem(tester, 7);
      expect(selected, [7]);
    });

    test('★フォームが★列の純粋関数を実際に呼んでいる（**D-27** の (乙)）', () {
      // ★★ 共有しただけでは★戻されたことに 1 つも気づけない ★★
      //   ★**widget が自分で回しても★★出る値は 1 つも変わらない★★**
      //   （★実測: ★★自分で回す形に戻しても★22 件が全部通った★★）。
      //   → ★**呼び出しが在ることを★ソースで見る**（★先例は `master_update_section` の走査）。
      final src = stripComments(
        File(p.join('lib', 'src', 'ui', 'deck', 'deck_count_band.dart'))
            .readAsStringSync(),
      );
      // ★★ 2026-09-04 追記: ★「呼び出しが在る」だけでは★足りない（★運転指示【0】(7) の 1）★★
      //   ★**測ったら★★呼びつつ隣で自分でも回す形が★通った★★**
      //   （2026-09-04 実測 / ★仕込み (P) が 0 件 —— ★`List.generate` で組み直す形）。
      //   → ★**回す先そのものを見る**（★呼び出しの有無ではなく★★for の相手★★）。
      expect(src.contains('for (final i in deckCountPickerValues(max))'), isTrue);
      // ★★ 上限を回す式は★★宣言の 1 か所だけである★★ ★★
      //   ★**widget が自分で回すと★★2 か所になる★★**（★それが (N) の仕込みである）。
      //   ★**`isFalse` では見られない** —— ★★宣言そのものがこの字面を持つ★★。
      expect('i <= max'.allMatches(src).length, 1);
      // ★★ 陽性対照（**D-10**）—— ★コメントを外す処理が働いていること ★★
      //   ★**doc には `i <= max + 1` と書いた説明が在る**（★上の doc の実測の行）。
      //   ★★**外したあとの本文には 1 つも無い**★★。
      expect(src.contains('max + 1'), isFalse);
      // ★★ 覆わないもの（★言い切る）★★
      //   ★**字面での走査は★★どれも回避できる★★**（★例: `deckCountPickerValues(max).toList()`）。
      //   ★**見ているのは★★この 1 つの書き方だけである★★**。
      //   ★**強くしたのは「呼べば通る」から「★★この形で回していれば通る★★」までで、
      //     ★★「値が本当にそこから来ている」ことは★1 ビットも見ていない★★**（**D-28**）。
      //   → ★**振る舞いに出ない守りに対して★★これが上限である★★**（★詳細は `docs/tools/measure_pairs.py`）。
    });

    testWidgets('★対: フォームで同じ枚数を選んでも何も起きない', (tester) async {
      final selected = <int>[];
      await _pump(
        tester,
        cardType: CardType.energy,
        count: 3,
        selected: selected,
      );
      await tester.tap(find.byKey(const ValueKey('deckCountBand:more')));
      await tester.pumpAndSettle();
      await _tapPickerItem(tester, 3);
      expect(selected, isEmpty);
    });
  });
}
