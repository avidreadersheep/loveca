/// 一覧の絞り込み（決定 D48 / `docs/UI設計メモ.md` §4-2）.
///
/// ★★ 2026-09-03: コスト絞り込みは**種別に依らず常に効く** ★★
/// `docs/Android UI 決定.md` §1-4（★**§4-2 の案 (a) を覆す** / ★Windows も）。
///
/// ★以前はこう書いてあった ——
/// 「★★ コスト絞り込みがメンバー限定であることを固定する ★★
///   `normalize.py:362-363` は `card.cost` を `KIND_MEMBER` の分岐でしか設定しない。
///   ライブは `cost` フィールドを**ブレードハートの供給元として使う**
///   （CLAUDE.md §5-(1)「API のフィールド名を信用しない」）。
///   素朴に絞ると**ライブとエネルギーが全部消える。**」
///
/// ★★ 上の事実は 1 つも動いていない ★★
/// ★**いま固定するのは「★消えること」そのものである**（★申し送り §2 の穴 1 ＝
/// ★利用者が承知のうえで受け入れた）。
/// → ★★**「消えないこと」を期待に書かない。★消えることを対で固定する**★★。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';

CardListRow _row({
  required String printingId,
  String cardNumber = 'X-1',
  CardType cardType = CardType.member,
  String expansion = 'BP01',
  bool isParallel = false,
  String imageHash = 'deadbeef',
  int? cost,
}) =>
    CardListRow(
      printingId: printingId,
      cardNumber: cardNumber,
      name: 'カード $printingId',
      cardType: cardType,
      expansion: expansion,
      rarity: 'R',
      isParallel: isParallel,
      imageHash: imageHash,
      cost: cost,
    );

void main() {
  final member1 = _row(printingId: 'm1', cost: 1);
  final member3 = _row(printingId: 'm3', cost: 3);
  // ★ライブとエネルギーは cost が null。
  final live = _row(printingId: 'l1', cardType: CardType.live);
  final energy = _row(printingId: 'e1', cardType: CardType.energy);
  final parallel = _row(printingId: 'p1', cost: 1, isParallel: true);
  final other = _row(printingId: 'o1', expansion: 'BP02', cost: 2);

  final all = [member1, member3, live, energy, parallel, other];

  test('既定では何も落とさない', () {
    expect(const CardListFilter().isEmpty, isTrue);
    expect(const CardListFilter().apply(all), same(all));
  });

  test('商品で絞る', () {
    final result = const CardListFilter(expansion: 'BP02').apply(all);
    expect(result.map((r) => r.printingId), ['o1']);
  });

  test('種別で絞る', () {
    final result = const CardListFilter(cardType: CardType.live).apply(all);
    expect(result.map((r) => r.printingId), ['l1']);
  });

  group('★パラレル表示 OFF（CLAUDE.md §5-(4)）', () {
    test('isParallel == false の刷りを「すべて」残す', () {
      final result = const CardListFilter(showParallel: false).apply(all);

      // ★cardNumber ごとに 1 枚へ畳まない。
      //   m1 / m3 / l1 / e1 / o1 はすべて同じ cardNumber 'X-1' だが全部残る。
      expect(
        result.map((r) => r.printingId),
        ['m1', 'm3', 'l1', 'e1', 'o1'],
      );
      expect(result.any((r) => r.isParallel), isFalse);
    });
  });

  group('★★ コスト絞り込みは種別に依らず常に効く（`Android UI 決定` §1-4）★★', () {
    test('種別を指定しなくてもコストが効く', () {
      const filter = CardListFilter(maxCost: 1);

      expect(filter.appliesCost, isTrue);
      // ★★ここが要点。cost が null のライブ・エネルギーは★消える★★
      //   （★以前はここが「黙って消さない」だった / ★申し送り §2 の穴 1）。
      expect(filter.apply(all).map((r) => r.printingId), ['m1', 'p1']);
    });

    test('★★受け入れた穴 —— ★ライブとエネルギーが黙って消える★★', () {
      const filter = CardListFilter(maxCost: 5);

      // ★★対: 種別を絞っていないのに、★cost を持つ行しか残らない★★。
      final left = filter.apply(all).map((r) => r.printingId).toList();
      expect(left, ['m1', 'm3', 'p1', 'o1']);
      expect(left, isNot(contains('l1')));
      expect(left, isNot(contains('e1')));

      // ★★警告も注記も出さない。★型に 1 ビットも現れない★★
      //   （★申し送りは出すと書いていない。★出すのは別の決定である）。
      expect(filter.isEmpty, isFalse);
    });

    test('種別がライブでもコストが効く（★★全部消える★★）', () {
      const filter = CardListFilter(cardType: CardType.live, maxCost: 1);

      expect(filter.appliesCost, isTrue);
      // ★★ライブは cost が null なので★1 件も残らない★★。
      expect(filter.apply(all), isEmpty);
    });

    test('種別がメンバーでもコストが効く', () {
      const filter = CardListFilter(cardType: CardType.member, maxCost: 1);

      expect(filter.appliesCost, isTrue);
      expect(filter.apply(all).map((r) => r.printingId), ['m1', 'p1']);
    });

    test('メンバーでも cost が null なら落ちる', () {
      final noCost = _row(printingId: 'm0');
      const filter = CardListFilter(cardType: CardType.member, maxCost: 5);

      expect(filter.apply([noCost, member1]).map((r) => r.printingId), ['m1']);
    });

    test('★対: コストを指定しなければ 1 件も落ちない', () {
      const filter = CardListFilter();

      expect(filter.appliesCost, isFalse);
      expect(filter.apply(all).length, all.length);
    });
  });

  test('複数条件は AND', () {
    const filter = CardListFilter(
      expansion: 'BP01',
      cardType: CardType.member,
      maxCost: 1,
      showParallel: false,
    );

    expect(filter.apply(all).map((r) => r.printingId), ['m1']);
  });

  group('copyWith', () {
    test('個別に上書きできる', () {
      const base = CardListFilter(expansion: 'BP01', showParallel: false);
      final next = base.copyWith(expansion: 'BP02');

      expect(next.expansion, 'BP02');
      expect(next.showParallel, isFalse);
    });

    test('clear で明示的に外せる', () {
      const base = CardListFilter(
        expansion: 'BP01',
        cardType: CardType.member,
        maxCost: 2,
      );

      final next = base.copyWith(clearCardType: true, clearMaxCost: true);

      expect(next.cardType, isNull);
      expect(next.maxCost, isNull);
      expect(next.expansion, 'BP01');
    });
  });
}
