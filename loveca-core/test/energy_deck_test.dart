/// エネルギーデッキ置き場の無作為抽出（決定 D73 / 整合性チェック B-2 の解消）.
///
/// ★★ 「無作為である」を「先頭を返す実装でも通る」形で書かないこと ★★
///   `deck.first` を返すだけの実装でも「1 枚減って 1 枚増えた」は通る。
///   **index 0 以外が実際に出ることを固定する**（D-10: 出る側だけを見ない）。
///
/// ★★ 「落ちること」を実際に確かめてある（2026-08-24）★★
///   `energy_deck.dart` の `rng.nextInt(deck.length)` を `0` に戻して走らせると、
///   **4 件が落ちる** —— 「index 0 以外が実際に出る」「同じ seed / 違う seed」
///   「DrawEnergy の同 seed / 別 seed」「7.5.2 も無作為」。
///   ★逆に「1 枚ずつ抜く（重複しない）」は先頭固定でも通る。**それ単体では
///   無作為性を何も証明していない**ので、上の 4 件と混同しないこと。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

final _master = <String, Card>{
  'E1': const Card(cardNumber: 'E1', name: 'E1', cardType: CardType.energy),
  'M1': const Card(cardNumber: 'M1', name: 'M1', cardType: CardType.member),
};

/// 1 枚ずつ区別できるエネルギー。★同じ printingId だと並びが観測できない。
List<CardInstance> _energy(int count, {String ownerId = 'A'}) => [
      for (var i = 0; i < count; i++)
        CardInstance(
          instanceId: '$ownerId-e$i',
          printingId: 'E1-R',
          cardNumber: 'E1',
          ownerId: ownerId,
        ),
    ];

GameState _state({
  List<CardInstance>? energyDeck,
  List<CardInstance> energyField = const [],
  StepCursor cursor = const StepCursor(PhaseId.firstEnergy, StepId.s7_5_2),
}) =>
    GameState(
      players: [
        PlayerState(
          playerId: 'A',
          energyDeck: energyDeck ?? _energy(12),
          energyField: energyField,
        ),
        const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: 'A',
      cursor: cursor,
    );

List<String> _fieldIds(GameState s) =>
    cardsIn(s, 'A', Zone.energyField).map((c) => c.instanceId).toList();

void main() {
  group('drawEnergyRandomly — 4.9.2 / 4.9.3（決定 D73）', () {
    test('1 枚出るとデッキが 1 枚減り、置き場が 1 枚増える', () {
      final after = drawEnergyRandomly(_state(), 'A', 1, SeededRng(1));

      expect(cardsIn(after, 'A', Zone.energyDeck).length, 11);
      expect(cardsIn(after, 'A', Zone.energyField).length, 1);
    });

    test('4.7.3 / 4.3.2.3: 置き場ではアクティブ・表向き', () {
      final card = cardsIn(
        drawEnergyRandomly(_state(), 'A', 1, SeededRng(1)),
        'A',
        Zone.energyField,
      ).single;

      expect(card.orientation, CardOrientation.active);
      expect(card.face, FaceState.faceUp);
    });

    test('★★ index 0 以外が実際に出る（= 先頭を返す実装では通らない）★★', () {
      final deck = _energy(12);
      final top = deck.first.instanceId;

      // ★1 つでも「先頭以外」が出る seed が実在することを固定する。
      //   すべての seed で先頭が出るなら、この実装は無作為ではない。
      final drawn = [
        for (var seed = 1; seed <= 8; seed++)
          _fieldIds(drawEnergyRandomly(
                  _state(energyDeck: deck), 'A', 1, SeededRng(seed)))
              .single,
      ];

      expect(drawn.any((id) => id != top), isTrue,
          reason: '★先頭以外が出ること自体が D73 の要求');
      // ★対: 出た札は必ずデッキに居た 12 枚のいずれか（作り出していない）
      expect(drawn.toSet().difference(deck.map((c) => c.instanceId).toSet()),
          isEmpty);
    });

    test('同じ seed なら同じ札 / ★対 違う seed なら別の札', () {
      final deck = _energy(12);
      String drawWith(int seed) => _fieldIds(
            drawEnergyRandomly(_state(energyDeck: deck), 'A', 1, SeededRng(seed)),
          ).single;

      expect(drawWith(1), drawWith(1), reason: '再現性');
      // ★12 枚あるので、どれか 2 つの seed は必ず違う札を引く。
      final bySeed = {for (var s = 1; s <= 8; s++) drawWith(s)};
      expect(bySeed.length, greaterThan(1), reason: '★seed で結果が変わる');
    });

    test('4.9.3: 複数枚は 1 枚ずつ抜く（重複しない）', () {
      final after = drawEnergyRandomly(_state(), 'A', 3, SeededRng(3));

      expect(cardsIn(after, 'A', Zone.energyDeck).length, 9);
      final ids = _fieldIds(after);
      expect(ids.length, 3);
      expect(ids.toSet().length, 3, reason: '★同じ 1 枚を 3 回選んでいない');
    });

    test('★空なら何も起きない / 途中で尽きたら引けた分で止まる', () {
      final empty = drawEnergyRandomly(
          _state(energyDeck: const []), 'A', 1, SeededRng(1));
      expect(cardsIn(empty, 'A', Zone.energyField), isEmpty);

      // ★エネルギーは閉ループ（10.5.4）でリフレッシュ（10.2）が無い。
      //   例外にすると 7.5.2 が毎ターン走る以上ゲームが止まる。
      final short =
          drawEnergyRandomly(_state(energyDeck: _energy(2)), 'A', 5, SeededRng(1));
      expect(cardsIn(short, 'A', Zone.energyDeck), isEmpty);
      expect(cardsIn(short, 'A', Zone.energyField).length, 2);
    });

    test('★他のプレイヤーの領域に触らない', () {
      final before = _state();
      final after = drawEnergyRandomly(before, 'A', 3, SeededRng(1));

      expect(cardsIn(after, 'B', Zone.energyDeck), isEmpty);
      expect(cardsIn(after, 'B', Zone.energyField), isEmpty);
    });
  });

  group('DrawEnergy アクション（21 個目 / 決定 D73）', () {
    ReduceContext context(int seed) =>
        ReduceContext(cards: _master, rng: SeededRng(seed));

    test('reduce を通って抽出される', () {
      final after = reduce(
        _state(),
        const DrawEnergy(playerId: 'A', count: 2),
        context: context(1),
      );

      expect(cardsIn(after, 'A', Zone.energyDeck).length, 10);
      expect(cardsIn(after, 'A', Zone.energyField).length, 2);
    });

    test('★同じ seed で同じ結果 / ★対 違う seed で別の結果', () {
      final state = _state();
      List<String> run(int seed) => _fieldIds(reduce(
            state,
            const DrawEnergy(playerId: 'A', count: 3),
            context: context(seed),
          ));

      expect(run(5), equals(run(5)));
      expect(run(5), isNot(equals(run(11))));
    });

    test('既定は 1 枚', () {
      final after = reduce(_state(), const DrawEnergy(playerId: 'A'),
          context: context(1));
      expect(cardsIn(after, 'A', Zone.energyField).length, 1);
    });
  });

  group('★7.5.2（AdvanceStep 経由）も無作為である', () {
    test('★同じ盤面に seed だけ変えると出る札が変わる', () {
      final state = _state();
      String run(int seed) => _fieldIds(
            StepEngine(cards: _master, rng: SeededRng(seed)).advance(state).state,
          ).single;

      expect(run(5), run(5));
      final bySeed = {for (var s = 1; s <= 8; s++) run(s)};
      expect(bySeed.length, greaterThan(1),
          reason: '★7.5.2 が index 0 固定なら 1 種類しか出ない');
    });
  });
}
