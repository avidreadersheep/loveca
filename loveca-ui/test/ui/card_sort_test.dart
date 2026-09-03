/// Android のカード検索の上部（`docs/Android UI 決定.md` §3-15）.
///
/// ★★ 何を固定するか ★★
/// ★**軸 4 つ** / ★★**「すべて」タブでは種別で束ねてから並べる**★★ /
/// ★**同じ軸を再度選ぶと反転** / ★**別の軸に移ると昇順から** /
/// ★★**値が無い行は★降順でも末尾**★★ / ★**件数と並び順だけを出す**。
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**コスト・スコアの値の取り方**（★★呼び出し側から受け取る★★ / U21 の論点 1 に触らない）／
/// ★**呼ぶ側**（★★`lib` に 1 つも無い★★ / **D-20**）／
/// ★★**日本語の読み順**★★（★`compareTo` は★★符号位置の比較である★★ —— ★読みも表記ゆれも見ない）／
/// ★**実機**（★ウィジェット試験は Android を 1 バイトも走らせない）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/ui/browse/card_sort.dart';

CardListRow _row({
  required String printingId,
  String cardNumber = 'X-001',
  String name = 'n',
  CardType cardType = CardType.member,
  String expansion = 'bp1',
  int? cost,
}) =>
    CardListRow(
      printingId: printingId,
      cardNumber: cardNumber,
      name: name,
      cardType: cardType,
      expansion: expansion,
      rarity: 'R',
      isParallel: false,
      imageHash: '',
      cost: cost,
    );

/// ★★ コスト・スコアの取り方（★呼び出し側の役）★★
///   ★**メンバーは `cost`、★ライブは★★この試験が持つ表★★から引く。**
int? Function(CardListRow) _costOrScore(Map<String, int> scores) =>
    (row) => switch (row.cardType) {
          CardType.member => row.cost,
          CardType.live => scores[row.printingId],
          CardType.energy => null,
        };

List<String> _ids(List<CardListRow> rows) =>
    [for (final r in rows) r.printingId];

void main() {
  group('軸（§3-15 の 4 つ）', () {
    test('4 つで、★字面も定まっている', () {
      expect(CardSortAxis.values, hasLength(4));
      expect(
        [for (final a in CardSortAxis.values) a.label],
        ['収録商品', 'カード番号', 'カード名', 'コスト・スコア'],
      );
    });

    test('収録商品 / カード番号 / カード名 で並ぶ', () {
      final rows = [
        _row(printingId: 'b', cardNumber: 'X-002', name: 'い', expansion: 'bp2'),
        _row(printingId: 'a', cardNumber: 'X-001', name: 'あ', expansion: 'bp1'),
      ];
      int? none(CardListRow r) => null;
      expect(
        _ids(sortCardList(rows, (axis: CardSortAxis.expansion, descending: false),
            costOrScoreOf: none)),
        ['a', 'b'],
      );
      expect(
        _ids(sortCardList(rows, (axis: CardSortAxis.cardNumber, descending: false),
            costOrScoreOf: none)),
        ['a', 'b'],
      );
      expect(
        _ids(sortCardList(rows, (axis: CardSortAxis.name, descending: false),
            costOrScoreOf: none)),
        ['a', 'b'],
      );
    });

    test('★元の列を書き換えない', () {
      final rows = [
        _row(printingId: 'b', cardNumber: 'X-002'),
        _row(printingId: 'a', cardNumber: 'X-001'),
      ];
      sortCardList(rows, kDefaultCardSortOrder, costOrScoreOf: (_) => null);
      expect(_ids(rows), ['b', 'a']);
    });
  });

  group('コスト・スコア（★統合した 1 つの軸）', () {
    test('メンバーはコスト、ライブはスコアで並ぶ', () {
      final rows = [
        _row(printingId: 'm5', cost: 5),
        _row(printingId: 'l2', cardType: CardType.live),
        _row(printingId: 'm1', cost: 1),
      ];
      final rows2 = sortCardList(
        rows,
        (axis: CardSortAxis.costOrScore, descending: false),
        costOrScoreOf: _costOrScore({'l2': 2}),
      );
      expect(_ids(rows2), ['m1', 'l2', 'm5']);
    });

    test('★値が無い行は★末尾である（★決定 D99 と同じ規則）', () {
      final rows = [
        _row(printingId: 'none', cost: null),
        _row(printingId: 'c3', cost: 3),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.costOrScore, descending: false),
          costOrScoreOf: _costOrScore(const {}),
        )),
        ['c3', 'none'],
      );
    });

    test('★★降順でも末尾である（★「無い」を最小として扱わない）★★', () {
      final rows = [
        _row(printingId: 'none', cost: null),
        _row(printingId: 'c3', cost: 3),
        _row(printingId: 'c9', cost: 9),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.costOrScore, descending: true),
          costOrScoreOf: _costOrScore(const {}),
        )),
        ['c9', 'c3', 'none'],
      );
    });

    test('★エネルギーは値を持たないので末尾である', () {
      final rows = [
        _row(printingId: 'e', cardType: CardType.energy),
        _row(printingId: 'm', cost: 2),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.costOrScore, descending: false),
          costOrScoreOf: _costOrScore(const {}),
        )),
        ['m', 'e'],
      );
    });
  });

  group('「すべて」タブ —— ★種別で束ねてから並べる（§3-15）', () {
    List<CardListRow> mixed() => [
          _row(printingId: 'e1', cardType: CardType.energy, cardNumber: 'A'),
          _row(printingId: 'l1', cardType: CardType.live, cardNumber: 'B'),
          _row(printingId: 'm1', cardType: CardType.member, cardNumber: 'C'),
        ];

    test('メンバー → ライブ → エネルギー の順に束ねる', () {
      expect(
        _ids(sortCardList(
          mixed(),
          (axis: CardSortAxis.cardNumber, descending: false),
          costOrScoreOf: (_) => null,
          groupByType: true,
        )),
        ['m1', 'l1', 'e1'],
      );
    });

    test('★★束ねる向きは★降順でも変わらない★★', () {
      expect(
        _ids(sortCardList(
          mixed(),
          (axis: CardSortAxis.cardNumber, descending: true),
          costOrScoreOf: (_) => null,
          groupByType: true,
        )),
        ['m1', 'l1', 'e1'],
      );
    });

    test('★対: 束ねないときは★軸だけで並ぶ', () {
      expect(
        _ids(sortCardList(
          mixed(),
          (axis: CardSortAxis.cardNumber, descending: false),
          costOrScoreOf: (_) => null,
        )),
        ['e1', 'l1', 'm1'],
      );
    });

    test('束の中では軸が効く', () {
      final rows = [
        _row(printingId: 'm2', cardNumber: 'Z'),
        _row(printingId: 'm1', cardNumber: 'A'),
        _row(printingId: 'l1', cardType: CardType.live, cardNumber: 'M'),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.cardNumber, descending: false),
          costOrScoreOf: (_) => null,
          groupByType: true,
        )),
        ['m1', 'm2', 'l1'],
      );
    });
  });

  group('最後の鍵 —— ★全順序にする', () {
    test('軸が同値なら `printingId` の昇順である', () {
      final rows = [
        _row(printingId: 'z', cardNumber: 'X-001'),
        _row(printingId: 'a', cardNumber: 'X-001'),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.cardNumber, descending: false),
          costOrScoreOf: (_) => null,
        )),
        ['a', 'z'],
      );
    });

    test('★★降順でも `printingId` は昇順である★★', () {
      final rows = [
        _row(printingId: 'z', cardNumber: 'X-001'),
        _row(printingId: 'a', cardNumber: 'X-001'),
      ];
      expect(
        _ids(sortCardList(
          rows,
          (axis: CardSortAxis.cardNumber, descending: true),
          costOrScoreOf: (_) => null,
        )),
        ['a', 'z'],
      );
    });
  });

  group('昇順 / 降順（§3-15 —— ★同じ軸を再度選ぶと反転）', () {
    test('同じ軸を押すと反転する', () {
      var order = kDefaultCardSortOrder;
      order = toggleCardSort(order, CardSortAxis.cardNumber);
      expect(order, (axis: CardSortAxis.cardNumber, descending: true));
      order = toggleCardSort(order, CardSortAxis.cardNumber);
      expect(order, (axis: CardSortAxis.cardNumber, descending: false));
    });

    test('★別の軸に移ると昇順から始まる（★前の向きを引き継がない）', () {
      const desc = (axis: CardSortAxis.cardNumber, descending: true);
      expect(
        toggleCardSort(desc, CardSortAxis.name),
        (axis: CardSortAxis.name, descending: false),
      );
    });

    test('既定はカード番号の昇順である（★既定値）', () {
      expect(kDefaultCardSortOrder,
          (axis: CardSortAxis.cardNumber, descending: false));
    });
  });

  group('画面 —— 上部', () {
    Future<void> pump(
      WidgetTester tester, {
      required int count,
      required CardSortOrder order,
      required List<CardSortOrder> changed,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardSortHeader(
                count: count,
                order: order,
                onChanged: changed.add,
              ),
            ),
          ),
        );

    testWidgets('件数と★いまの並び順だけが出る（★検索ボタンもカメラも無い）',
        (tester) async {
      await pump(
        tester,
        count: 1034,
        order: kDefaultCardSortOrder,
        changed: [],
      );
      expect(find.text('1034 件'), findsOneWidget);
      expect(find.text('カード番号'), findsOneWidget);
      // ★★ 検索ボタン（詳細検索）もカメラも置かない（§3-15 / §3-18 の 6）★★
      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.byIcon(Icons.camera_alt), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('向きが絵で出る', (tester) async {
      await pump(
        tester,
        count: 0,
        order: (axis: CardSortAxis.name, descending: true),
        changed: [],
      );
      expect(
        find.byKey(const ValueKey('cardSortHeader:direction:desc')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cardSortHeader:direction:asc')),
        findsNothing,
      );
      // ★★ 絵そのものも見る（★★鍵だけでは★字面が固定されない★★ / **D-27** の (乙)）★★
      //   ★実測: ★★`Icons.arrow_upward` に固定しても★鍵は `desc` のままで通った★★。
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('★対: 昇順のときは上向きの絵である', (tester) async {
      await pump(
        tester,
        count: 0,
        order: (axis: CardSortAxis.name, descending: false),
        changed: [],
      );
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('4 つの軸が menu に出る', (tester) async {
      await pump(
        tester,
        count: 0,
        order: kDefaultCardSortOrder,
        changed: [],
      );
      await tester.tap(find.byKey(const ValueKey('cardSortHeader:menu')));
      await tester.pumpAndSettle();
      for (final axis in CardSortAxis.values) {
        expect(
          find.byKey(ValueKey('cardSortHeader:axis:${axis.name}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('同じ軸を選ぶと反転が返る', (tester) async {
      final changed = <CardSortOrder>[];
      await pump(
        tester,
        count: 0,
        order: kDefaultCardSortOrder,
        changed: changed,
      );
      await tester.tap(find.byKey(const ValueKey('cardSortHeader:menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cardSortHeader:axis:cardNumber')),
      );
      await tester.pumpAndSettle();
      expect(changed, [(axis: CardSortAxis.cardNumber, descending: true)]);
    });

    testWidgets('別の軸を選ぶと昇順が返る', (tester) async {
      final changed = <CardSortOrder>[];
      await pump(
        tester,
        count: 0,
        order: (axis: CardSortAxis.cardNumber, descending: true),
        changed: changed,
      );
      await tester.tap(find.byKey(const ValueKey('cardSortHeader:menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cardSortHeader:axis:costOrScore')),
      );
      await tester.pumpAndSettle();
      expect(changed, [(axis: CardSortAxis.costOrScore, descending: false)]);
    });
  });
}
