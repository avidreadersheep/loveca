/// Android の統計（`docs/Android UI 決定.md` §3-11）.
///
/// ★★ 何を固定するか ★★
/// ★**出すのは 4 つで、★★横棒はコストの分布だけ★★** /
/// ★**「所持ハートの色の分布」は 1 行も出ない**（★★利用者が撤回した★★） /
/// ★**コストはメンバーだけを数える**（★`CLAUDE.md` §5-(1)） /
/// ★★**ブレードハートは色だけを数える**★★（★ドロー / スコアは混ぜない / `CLAUDE.md` §6）。
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**実機** ／ ★**呼ぶ側**（★★`lib` に 1 つも無い★★ / **D-20**）／
/// ★**カタログの引き方**（★`Card` を★★呼び出し側から受け取る★★ / U21 の論点 1 に触らない）／
/// ★**横棒の見た目**（★★測っていない★★ / **D-28**）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_core/loveca_core.dart' as core show Card;
import 'package:loveca_ui/src/ui/deck/deck_stats_section.dart';

core.Card _member({
  required String id,
  int? cost,
  Map<HeartColor, int> bladeHearts = const {},
  Map<BladeHeartEffect, int> effects = const {},
  Map<HeartColor, int> hearts = const {},
}) =>
    core.Card(
      cardNumber: id,
      name: id,
      cardType: CardType.member,
      cost: cost,
      bladeHearts: bladeHearts,
      bladeHeartEffects: effects,
      hearts: hearts,
    );

core.Card _live({required String id, int? cost, int? score}) => core.Card(
      cardNumber: id,
      name: id,
      cardType: CardType.live,
      cost: cost,
      score: score,
    );

const _validation = DeckValidationResult(
  issues: [],
  memberCount: 48,
  liveCount: 12,
  energyCount: 12,
  unknownPrintingIds: [],
);

Future<void> _pump(
  WidgetTester tester,
  List<DeckStatEntry> entries,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DeckStatsSection(
            entries: entries,
            validation: _validation,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('純粋関数 —— コストの分布', () {
    test('枚数の重みを掛ける', () {
      final stats = deckStatsOf([
        (card: _member(id: 'a', cost: 2), count: 4),
        (card: _member(id: 'b', cost: 2), count: 1),
        (card: _member(id: 'c', cost: 5), count: 2),
      ]);
      expect(stats.costs, {2: 5, 5: 2});
    });

    test('★メンバーだけを数える（★ライブの cost は★★ブレードハートの供給元である★★）', () {
      final stats = deckStatsOf([
        (card: _member(id: 'a', cost: 3), count: 1),
        (card: _live(id: 'b', cost: 9), count: 4),
      ]);
      expect(stats.costs, {3: 1});
    });

    test('cost が null のメンバーは数えない', () {
      final stats = deckStatsOf([
        (card: _member(id: 'a', cost: null), count: 4),
      ]);
      expect(stats.costs, isEmpty);
    });

    test('並びは昇順である（★Map の反復順に任せない）', () {
      expect(deckStatCostOrder({5: 1, 2: 1, 22: 1, 0: 1}), [0, 2, 5, 22]);
    });
  });

  group('純粋関数 —— ブレードハート', () {
    test('色ごとに数え、合計も出す（★枚数の重みつき）', () {
      final stats = deckStatsOf([
        (
          card: _member(
            id: 'a',
            bladeHearts: const {HeartColor.pink: 1, HeartColor.blue: 2},
          ),
          count: 3,
        ),
      ]);
      expect(stats.bladeHearts, {HeartColor.pink: 3, HeartColor.blue: 6});
      expect(stats.bladeHeartTotal, 9);
    });

    test('★ドロー / スコアは混ぜない（`CLAUDE.md` §6 / 8.3.14 と 8.3.12.1 は別）', () {
      final stats = deckStatsOf([
        (
          card: _member(
            id: 'a',
            bladeHearts: const {HeartColor.pink: 1},
            effects: const {BladeHeartEffect.draw: 5},
          ),
          count: 1,
        ),
      ]);
      expect(stats.bladeHeartTotal, 1);
      // ★★ 対 —— ★アイコンだけを持つカードは★数を 1 も動かさない ★★
      final only = deckStatsOf([
        (
          card: _member(
            id: 'b',
            effects: const {BladeHeartEffect.score: 3},
          ),
          count: 4,
        ),
      ]);
      expect(only.bladeHeartTotal, 0);
      expect(only.bladeHearts, isEmpty);
    });

    test('空のデッキでも 0 である', () {
      final stats = deckStatsOf(const []);
      expect(stats.costs, isEmpty);
      expect(stats.bladeHearts, isEmpty);
      expect(stats.bladeHeartTotal, 0);
    });
  });

  group('純粋関数 —— 横棒の割合', () {
    test('最大に対する割合である', () {
      expect(deckStatBarFraction(4, 8), 0.5);
      expect(deckStatBarFraction(8, 8), 1.0);
    });

    test('★最大が 0 のときは割らない（★空のデッキで例外を出さない）', () {
      expect(deckStatBarFraction(0, 0), 0);
      expect(deckStatBarFraction(3, 0), 0);
    });

    test('1 を超えない / 0 を下回らない', () {
      expect(deckStatBarFraction(9, 8), 1.0);
      expect(deckStatBarFraction(-1, 8), 0);
    });
  });

  group('画面', () {
    testWidgets('4 つの見出しが出る（★3 本のカウンタ ＋ 3 つ）', (tester) async {
      await _pump(tester, [
        (card: _member(id: 'a', cost: 2), count: 4),
      ]);
      expect(find.byKey(const ValueKey('deckCounters:oneRow')).evaluate().length +
          find.byKey(const ValueKey('deckCounters:threeRows')).evaluate().length,
          1);
      expect(find.byKey(const ValueKey('deckStats:costs')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('deckStats:bladeHeartColors')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('deckStats:bladeHeartTotal')),
        findsOneWidget,
      );
    });

    testWidgets('★「所持ハートの色の分布」は 1 行も出ない（★利用者が撤回した）',
        (tester) async {
      await _pump(tester, [
        (
          card: _member(
            id: 'a',
            hearts: const {HeartColor.pink: 3},
            cost: 1,
          ),
          count: 4,
        ),
      ]);
      expect(find.text('所持ハートの色の分布'), findsNothing);
      // ★★ 対 —— ★ブレードハートの見出しは出ている（★「何も出ない」と区別できる形）★★
      expect(find.text('ブレードハートの色の分布'), findsOneWidget);
    });

    testWidgets('コストの分布に横棒が出て、★最大の行は目一杯である', (tester) async {
      await _pump(tester, [
        (card: _member(id: 'a', cost: 1), count: 2),
        (card: _member(id: 'b', cost: 3), count: 8),
      ]);
      double factorOf(int cost) => tester
          .widget<FractionallySizedBox>(
            find.byKey(ValueKey('deckStats:costBar:$cost')),
          )
          .widthFactor!;
      expect(factorOf(3), 1.0);
      expect(factorOf(1), 0.25);
    });

    testWidgets('★ブレードハートの色の分布に★横棒は出ない', (tester) async {
      await _pump(tester, [
        (
          card: _member(
            id: 'a',
            cost: 1,
            bladeHearts: const {HeartColor.pink: 2},
          ),
          count: 1,
        ),
      ]);
      // ★★ 横棒はコストの分布だけである（§3-11 の表）★★
      //   ★**コストの行 1 つぶんだけ在る**（★色の行には無い）。
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      expect(
        find.byKey(const ValueKey('deckStats:bladeHeart:pink')),
        findsOneWidget,
      );
    });

    testWidgets('★色の並びは `heartDisplayOrder` である（★Map の反復順に任せない）',
        (tester) async {
      // ★★ 入れる順を★表示の順と★逆にする ★★
      //   ★**`Map` の反復順は★挿入順である**ので、★★任せていれば紫が先に出る★★。
      await _pump(tester, [
        (
          card: _member(
            id: 'a',
            cost: 1,
            bladeHearts: const {
              HeartColor.purple: 1,
              HeartColor.blue: 1,
              HeartColor.pink: 1,
            },
          ),
          count: 1,
        ),
      ]);
      double xOf(HeartColor c) => tester
          .getTopLeft(find.byKey(ValueKey('deckStats:bladeHeart:${c.name}')))
          .dx;
      expect(xOf(HeartColor.pink), lessThan(xOf(HeartColor.blue)));
      expect(xOf(HeartColor.blue), lessThan(xOf(HeartColor.purple)));
    });

    testWidgets('ブレードハートの数が出る', (tester) async {
      await _pump(tester, [
        (
          card: _member(
            id: 'a',
            bladeHearts: const {HeartColor.pink: 1, HeartColor.purple: 1},
          ),
          count: 3,
        ),
      ]);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('deckStats:bladeHeartTotal:value')),
      );
      expect(text.data, '6');
    });

    testWidgets('★空のデッキでも落ちない（★横棒も色も 1 つも出ない）', (tester) async {
      await _pump(tester, const []);
      expect(find.byType(FractionallySizedBox), findsNothing);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('deckStats:bladeHeartTotal:value')),
      );
      expect(text.data, '0');
    });

    testWidgets('★3 本のカウンタは `DeckCountersBand` を通る（★数え直さない）',
        (tester) async {
      await _pump(tester, const []);
      // ★★ デッキが空でも★カウンタは `validation` の値を出す ★★
      //   ★**この節が数え直していたら 0 / 0 / 0 が出る**（★★区別できる形★★）。
      expect(find.text('メンバー 48 / 48'), findsOneWidget);
      expect(find.text('ライブ 12 / 12'), findsOneWidget);
      expect(find.text('エネルギー 12 / 12'), findsOneWidget);
    });
  });
}
