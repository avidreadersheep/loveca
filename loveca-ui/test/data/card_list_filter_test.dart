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

  // ---------------------------------------------------------------------------
  // ★★ 段 B —— ★`Card` から引く軸（§3-6 / ★U21 の論点 1 ＝ ★道 3）★★
  //
  // ★★ 決定の正は `docs/Android UI 決定.md` §27 である ★★
  //   ★**投影の形も SQL も 1 バイト変えない。★`rows` を回しながら
  //   ★★`cards[row.cardNumber]` を引いて判定する★★**（★実測 0.16〜1.4 ms / ★§27-3）。
  // ---------------------------------------------------------------------------

  group('★★ 段 B —— カードから引く軸（§3-6）★★', () {
    Card card({
      String cardNumber = 'X-1',
      CardType cardType = CardType.member,
      List<String> groupNames = const [],
      List<String> unitNames = const [],
      int? bladeCount,
      int? score,
      Map<HeartColor, int> hearts = const {},
      Map<HeartColor, int> requiredHearts = const {},
      Map<HeartColor, int> bladeHearts = const {},
      int heartTotal = 0,
      int requiredHeartTotal = 0,
    }) =>
        Card(
          cardNumber: cardNumber,
          name: 'カード',
          cardType: cardType,
          groupNames: groupNames,
          unitNames: unitNames,
          bladeCount: bladeCount,
          score: score,
          hearts: hearts,
          requiredHearts: requiredHearts,
          bladeHearts: bladeHearts,
          heartTotal: heartTotal,
          requiredHeartTotal: requiredHeartTotal,
        );

    test('★★ 前提: ★段 B が 1 つも立っていなければ needsCard は false ★★', () {
      expect(const CardListFilter().needsCard, isFalse);
      expect(
          const CardListFilter(expansion: 'BP01', maxCost: 2).needsCard, isFalse);
    });

    test('★★ 9 つの軸は★1 つずつ needsCard を立てる ★★', () {
      const on = (min: 1, max: null);
      const filters = <CardListFilter>[
        CardListFilter(groupName: 'Liella!'),
        CardListFilter(unitName: '5yncri5e!'),
        CardListFilter(blade: on),
        CardListFilter(score: on),
        CardListFilter(heartTotal: on),
        CardListFilter(hearts: {HeartColor.pink: on}),
        CardListFilter(requiredHeartTotal: on),
        CardListFilter(requiredHearts: {HeartColor.blue: on}),
        CardListFilter(bladeHearts: {HeartColor.red: on}),
      ];
      expect(filters, hasLength(9));
      for (final f in filters) {
        expect(f.needsCard, isTrue, reason: '★立たない軸が在る');
      }
    });

    test('★★ 段 B が立っていて★カードが無ければ★通さない（★決めた既定値）★★', () {
      const filter = CardListFilter(groupName: 'Liella!');
      expect(filter.matches(_row(printingId: 'a')), isFalse);
    });

    test('★★ 対: ★段 B が立っていなければ★カードを渡さなくても通る ★★', () {
      const filter = CardListFilter(expansion: 'BP01');
      expect(filter.matches(_row(printingId: 'a')), isTrue);
    });

    test('★ 登場作品は★1 つでも一致すれば通す', () {
      const filter = CardListFilter(groupName: 'Liella!');
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(groupNames: const ['hasunosora', 'Liella!'])),
          isTrue);
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(groupNames: const ['Aqours'])),
          isFalse);
    });

    test('★ ユニットも同じ形', () {
      const filter = CardListFilter(unitName: '5yncri5e!');
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(unitNames: const ['5yncri5e!'])),
          isTrue);
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(unitNames: const [])),
          isFalse);
      // ★★ 別のユニットも落ちる（★「空かどうか」では区別できない）★★
      //   ★**2026-09-04 に測った** —— ★★この対が無いと
      //   ★`contains` を `isEmpty` に変えても 0 件だった★★（**D-27** の (a)）。
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(unitNames: const ['QU4RTZ'])),
          isFalse);
    });

    test('★★ 合計ハートと★合計必要ハートは★別の欄である ★★', () {
      // ★★ 総合ルール 2.9（所持）と 2.11（必要）—— ★取り違えると★別のカードが出る ★★
      //   ★**2026-09-04 に測った** —— ★★この対が無いと
      //   ★`heartTotal` を `requiredHeartTotal` に取り違えても 0 件だった★★。
      final c = card(heartTotal: 5, requiredHeartTotal: 0);
      expect(
          const CardListFilter(heartTotal: (min: 5, max: 5))
              .matches(_row(printingId: 'a'), card: c),
          isTrue);
      expect(
          const CardListFilter(requiredHeartTotal: (min: 5, max: 5))
              .matches(_row(printingId: 'a'), card: c),
          isFalse);
    });

    test('★★ 値を持たない行は★範囲を指定したときだけ落ちる ★★', () {
      // ★★ スコアはライブにしか値が無い（総合ルール 2.10）★★
      const withRange = CardListFilter(score: (min: 1, max: null));
      expect(withRange.matches(_row(printingId: 'a'), card: card()), isFalse);
      expect(withRange.matches(_row(printingId: 'a'), card: card(score: 2)),
          isTrue);
      // ★対: ★範囲を外せば★また出る（★★消したのではない★★）
      const off = CardListFilter(expansion: 'BP01');
      expect(off.matches(_row(printingId: 'a'), card: card()), isTrue);
    });

    test('★ 範囲は★下端も上端も効く', () {
      const filter = CardListFilter(blade: (min: 2, max: 4));
      expect(filter.matches(_row(printingId: 'a'), card: card(bladeCount: 1)),
          isFalse);
      expect(filter.matches(_row(printingId: 'a'), card: card(bladeCount: 2)),
          isTrue);
      expect(filter.matches(_row(printingId: 'a'), card: card(bladeCount: 4)),
          isTrue);
      expect(filter.matches(_row(printingId: 'a'), card: card(bladeCount: 5)),
          isFalse);
    });

    test('★★ 持っていない色は★0 として見る（★null で落とさない）★★', () {
      const atLeastZero =
          CardListFilter(hearts: {HeartColor.pink: (min: 0, max: 2)});
      expect(atLeastZero.matches(_row(printingId: 'a'), card: card()), isTrue);
      const atLeastOne =
          CardListFilter(hearts: {HeartColor.pink: (min: 1, max: null)});
      expect(atLeastOne.matches(_row(printingId: 'a'), card: card()), isFalse);
    });

    test('★★ 指定していない色は★見ない ★★', () {
      const filter =
          CardListFilter(hearts: {HeartColor.pink: (min: 1, max: null)});
      expect(
          filter.matches(_row(printingId: 'a'),
              card: card(
                  hearts: const {HeartColor.pink: 1, HeartColor.blue: 9})),
          isTrue);
    });

    test('★★ 3 つのハートは★別々の欄である（★取り違えない）★★', () {
      final c = card(
        hearts: const {HeartColor.pink: 3},
        requiredHearts: const {HeartColor.blue: 3},
        bladeHearts: const {HeartColor.red: 3},
      );
      const one = (min: 3, max: 3);
      expect(
          const CardListFilter(hearts: {HeartColor.pink: one})
              .matches(_row(printingId: 'a'), card: c),
          isTrue);
      expect(
          const CardListFilter(requiredHearts: {HeartColor.pink: one})
              .matches(_row(printingId: 'a'), card: c),
          isFalse);
      expect(
          const CardListFilter(bladeHearts: {HeartColor.blue: one})
              .matches(_row(printingId: 'a'), card: c),
          isFalse);
    });

    test('★★ ブレードハートは★色だけを見る（★ドロー / スコアのアイコンでは絞らない）★★',
        () {
      // ★★ 総合ルール 8.3.14 に合算するのは色だけである（`CLAUDE.md` §6）★★
      const c = Card(
        cardNumber: 'X-1',
        name: 'カード',
        cardType: CardType.live,
        bladeHeartEffects: {BladeHeartEffect.draw: 4},
      );
      const filter =
          CardListFilter(bladeHearts: {HeartColor.red: (min: 1, max: null)});
      expect(filter.matches(_row(printingId: 'a'), card: c), isFalse);
    });

    test('★★ apply は★行ごとに★対応するカードを引く ★★', () {
      final rows = <CardListRow>[
        _row(printingId: 'a', cardNumber: 'A'),
        _row(printingId: 'b', cardNumber: 'B'),
      ];
      final cards = <String, Card>{
        'A': card(cardNumber: 'A', groupNames: const ['Liella!']),
        'B': card(cardNumber: 'B', groupNames: const ['Aqours']),
      };
      const filter = CardListFilter(groupName: 'Liella!');
      final out = filter.apply(rows, cards: cards);
      expect(out.map((r) => r.printingId), <String>['a']);
    });

    test('★★ apply は★カードを渡さなくても呼べる（★Windows の経路）★★', () {
      final rows = <CardListRow>[_row(printingId: 'a', cost: 1)];
      const filter = CardListFilter(maxCost: 2);
      expect(filter.apply(rows).map((r) => r.printingId), <String>['a']);
    });

    test('★ copyWith は★段 B の軸も運ぶ / clear で外せる', () {
      const base = CardListFilter(groupName: 'Liella!', unitName: 'u');
      expect(base.copyWith(unitName: 'v').groupName, 'Liella!');
      expect(base.copyWith(clearGroupName: true).groupName, isNull);
      expect(base.copyWith(clearGroupName: true).unitName, 'u');
      expect(base.copyWith(blade: (min: 1, max: null)).blade.min, 1);
    });

    test('★★ isEmpty は★段 B も見る ★★', () {
      expect(const CardListFilter().isEmpty, isTrue);
      expect(const CardListFilter(groupName: 'Liella!').isEmpty, isFalse);
    });
  });
}
