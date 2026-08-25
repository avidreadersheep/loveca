/// ゲーム開始手順 6.2.1（決定 D79 / D80）.
///
/// ★★ 「シャッフルされる」と「シャッフルされない」を必ず対で見る ★★
///   6.2.1.2（メインデッキ）と 6.2.1.3（エネルギーデッキ）は真逆の指示である。
///   片方だけを見ると、**両方シャッフルする実装**でも**両方しない実装**でも
///   どちらかが通ってしまう（D-10）。
///
/// ★★ 対で落ちることを実際に確かめてある（2026-08-24）★★
///   | 実装をこう変えると | 落ちるもの |
///   |---|---|
///   | 6.2.1.2 の `rng.shuffled` を外す | 「メインデッキはシャッフルされる」「seed で並びが変わる」の 2 件 |
///   | 6.2.1.3 に `rng.shuffled` を足す | 「エネルギーデッキはシャッフルされない」の 1 件 |
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type) =>
    Card(cardNumber: number, name: number, cardType: type);

Printing _printing(String id, String number) => Printing(
      printingId: id,
      cardNumber: number,
      expansion: 'bp1',
      rarity: 'R',
      isParallel: false,
    );

/// メンバー 6 種 / ライブ 2 種 / エネルギー 1 種。
///
/// ★6.1 を満たす枚数にはしていない。**検証は呼び出し側の担当**（D28）であり、
///   ここで 60 枚を並べても手順の検査には効かない。
final _cards = <String, Card>{
  for (var i = 1; i <= 6; i++) 'M$i': _card('M$i', CardType.member),
  'L1': _card('L1', CardType.live),
  'L2': _card('L2', CardType.live),
  'E1': _card('E1', CardType.energy),
};

final _printings = <String, Printing>{
  for (var i = 1; i <= 6; i++) 'M$i-R': _printing('M$i-R', 'M$i'),
  'L1-R': _printing('L1-R', 'L1'),
  'L2-R': _printing('L2-R', 'L2'),
  'E1-R': _printing('E1-R', 'E1'),
};

final _epoch = DateTime.utc(2026, 8, 24);

Deck _deck({List<DeckEntry>? entries, String deckId = 'deck-1'}) => Deck(
      deckId: deckId,
      name: 'テスト',
      entries: entries ??
          [
            for (var i = 1; i <= 6; i++)
              DeckEntry(printingId: 'M$i-R', count: 2),
            const DeckEntry(printingId: 'L1-R', count: 2),
            const DeckEntry(printingId: 'L2-R', count: 2),
            // ★エネルギーは 1 種を 6 枚。刷りが同じでも instanceId で区別できる。
            const DeckEntry(printingId: 'E1-R', count: 6),
          ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// [begin] → [dealInitialEnergy] を 1 本の乱数列で通す。
GameState _start({
  int seed = 1,
  Deck? a,
  Deck? b,
  String firstPlayerId = 'A',
  RuleConfig config = RuleConfig.standard,
}) {
  final rng = SeededRng(seed);
  return GameSetup.begin(
    players: [
      PlayerDeck(playerId: 'A', deck: a ?? _deck()),
      PlayerDeck(playerId: 'B', deck: b ?? _deck(deckId: 'deck-2')),
    ],
    cards: _cards,
    printings: _printings,
    rng: rng,
    firstPlayerId: firstPlayerId,
    config: config,
  ).dealInitialEnergy(rng: rng);
}

/// ★6.2.1.6 の途中まで（[GameSetup.mulligan] を呼ぶ側が要る）。
GameSetup _beginWith(
  DeterministicRng rng, {
  Deck? deck,
  String firstPlayerId = 'A',
}) =>
    GameSetup.begin(
      players: [
        PlayerDeck(playerId: 'A', deck: deck ?? _deck()),
        PlayerDeck(playerId: 'B', deck: deck ?? _deck(deckId: 'deck-2')),
      ],
      cards: _cards,
      printings: _printings,
      rng: rng,
      firstPlayerId: firstPlayerId,
    );

/// ★メインデッキが手札より少ないデッキ（メイン 8 枚 → 手札 6 / 山 2）。
///
/// ★★ 6.2.1.6 の「引いてから戻す」順を検査するのに要る ★★
///   山が手札より多いと、順を入れ替えた実装でも**たまたま**旧手札が
///   引き直されないことがある。少なくしておけば**枚数で必ず割れる**。
Deck _smallMainDeck() => Deck(
      deckId: 'small-main',
      name: '山が少ない',
      entries: const [
        DeckEntry(printingId: 'M1-R', count: 4),
        DeckEntry(printingId: 'L1-R', count: 4),
        DeckEntry(printingId: 'E1-R', count: 6),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );

/// ★`nextInt` の回数を数える包み。
///
/// ★★ 「乱数を消費したか」を列挙ではなく実測で見る（決定 D90-1 と同じ手法）★★
///   6.2.1.6 の「1 枚以上移動した場合はシャッフルします」は
///   **0 枚なら乱数を 1 つも消費しない**という観測できる性質を持つ。
class _CountingRng implements DeterministicRng {
  _CountingRng(this._inner);

  final DeterministicRng _inner;

  int count = 0;

  @override
  int nextInt(int max) {
    count++;
    return _inner.nextInt(max);
  }
}

List<String> _ids(List<CardInstance> cards) =>
    cards.map((c) => c.instanceId).toList();

/// 盤面に存在するすべての instanceId（メンバーエリアと解決領域も含む）。
List<String> _allInstanceIds(GameState state) => [
      for (final player in state.players) ...[
        ..._ids(player.hand),
        ..._ids(player.mainDeck),
        ..._ids(player.energyDeck),
        ..._ids(player.energyField),
        ..._ids(player.liveStage),
        ..._ids(player.successLive),
        ..._ids(player.waitingRoom),
        ..._ids(player.exile),
        ..._ids(player.mulliganAside),
        ..._ids(player.freeArea),
        for (final area in player.memberAreas) ...[
          for (final stack in area.stacks) ...[
            stack.member.instanceId,
            ..._ids(stack.beneath),
          ],
          ..._ids(area.orphans),
        ],
      ],
      ..._ids(state.resolution),
    ];

void main() {
  group('6.2.1 の開始手順', () {
    test('6.2.1.5: 手札は RuleConfig.initialHandSize 枚（既定 6）', () {
      final state = _start();

      expect(state.config.initialHandSize, 6, reason: '★前提の確認');
      for (final player in state.players) {
        expect(player.hand.length, 6, reason: player.playerId);
      }
    });

    test('6.2.1.7: エネルギー置き場は initialEnergyOnField 枚（既定 3）', () {
      final state = _start();

      expect(state.config.initialEnergyOnField, 3, reason: '★前提の確認');
      for (final player in state.players) {
        expect(player.energyField.length, 3, reason: player.playerId);
        expect(player.energyDeck.length, 3, reason: '★6 枚から 3 枚出た');
        // 4.7.3 / 4.3.2.3
        expect(
          player.energyField.every(
              (c) => c.orientation == CardOrientation.active),
          isTrue,
        );
      }
    });

    test('★定数にしない: RuleConfig を替えると枚数が追随する（6.1.2）', () {
      final state = _start(
        config: const RuleConfig(initialHandSize: 4, initialEnergyOnField: 1),
      );

      expect(state.playerOf('A').hand.length, 4);
      expect(state.playerOf('A').energyField.length, 1);
    });

    test('6.1.1.1 / 6.1.1.3: 種別で山が分かれる', () {
      final state = _start();
      final a = state.playerOf('A');

      // メンバー 12 + ライブ 4 = 16 のうち 6 枚が手札へ。
      expect(a.hand.length + a.mainDeck.length, 16);
      expect(a.energyDeck.length + a.energyField.length, 6);
      // ★エネルギーはメインデッキに 1 枚も混ざらない。
      expect(
        [...a.hand, ...a.mainDeck].every((c) => c.cardNumber != 'E1'),
        isTrue,
      );
    });

    test('7.1.2 / 7.3.3: 初期カーソルは先攻アクティブフェイズの 7.4.1', () {
      final state = _start();

      expect(state.cursor.phase, PhaseId.firstActive);
      expect(state.cursor.step, StepId.s7_4_1);
      expect(state.turnNumber, 1);
    });

    test('メンバーエリアは 3 つ（4.5.2.1）で、どれも空', () {
      for (final player in _start().players) {
        expect(player.memberAreas.map((a) => a.slot).toList(),
            MemberAreaSlot.values);
        expect(player.memberAreas.every((a) => a.stacks.isEmpty), isTrue);
        expect(player.memberAreas.every((a) => a.orphans.isEmpty), isTrue);
      }
    });

    test('6.2.1.4: firstPlayerId が反映される', () {
      expect(_start(firstPlayerId: 'B').firstPlayerId, 'B');
    });
  });

  group('★★ 6.2.1.2 と 6.2.1.3 — シャッフルする / しない を対で見る ★★', () {
    /// デッキリストに書いた順（= シャッフル前の並び）。
    List<String> listOrder(String playerId, {required bool energy}) => [
          for (final entry in _deck().entries)
            if ((_cards[_printings[entry.printingId]!.cardNumber]!.cardType ==
                    CardType.energy) ==
                energy)
              for (var i = 1; i <= entry.count; i++)
                '$playerId:${entry.printingId}:$i',
        ];

    test('★6.2.1.2: メインデッキはシャッフルされる', () {
      final a = _start().playerOf('A');
      // 手札に 6 枚移っているので、残りと合わせて元の集合になる。
      final drawnAndDeck = [..._ids(a.hand), ..._ids(a.mainDeck)];
      final original = listOrder('A', energy: false);

      expect(drawnAndDeck, isNot(equals(original)),
          reason: '★並びが元のままなら 6.2.1.2 が効いていない');
      expect(drawnAndDeck.toSet(), equals(original.toSet()),
          reason: '★増減はしていない');
    });

    test('★★対 6.2.1.3: エネルギーデッキはシャッフルされない ★★', () {
      // ★6.2.1.7 の抽出（無作為 / D73）が並びを崩すので、
      //   dealInitialEnergy を通す前の状態で見る。
      final rng = SeededRng(1);
      final setup = GameSetup.begin(
        players: [
          PlayerDeck(playerId: 'A', deck: _deck()),
          PlayerDeck(playerId: 'B', deck: _deck(deckId: 'deck-2')),
        ],
        cards: _cards,
        printings: _printings,
        rng: rng,
        firstPlayerId: 'A',
      );

      final energyDeck = _ids(
          setup.pendingState.playerOf('A').energyDeck);

      expect(energyDeck, equals(listOrder('A', energy: true)),
          reason: '★条文に無いシャッフルを足していないこと（決定 D73）');
    });

    test('★seed を変えるとメインデッキの並びが変わる（= 実際に乱数を使っている）', () {
      List<String> order(int seed) =>
          _ids(_start(seed: seed).playerOf('A').mainDeck);

      expect(order(1), equals(order(1)));
      expect(order(1), isNot(equals(order(9))));
    });
  });

  group('★ 同じ seed で同じ初期状態になる（決定 D79）', () {
    test('全領域の instanceId 列が一致する', () {
      expect(_allInstanceIds(_start(seed: 42)),
          equals(_allInstanceIds(_start(seed: 42))));
    });

    test('★対: seed が違えば一致しない', () {
      expect(_allInstanceIds(_start(seed: 42)),
          isNot(equals(_allInstanceIds(_start(seed: 43)))));
    });

    test('★採番に乱数を使っていない: seed が違っても id の集合は同じ', () {
      expect(_allInstanceIds(_start(seed: 42)).toSet(),
          equals(_allInstanceIds(_start(seed: 43)).toSet()));
    });
  });

  group('★ instanceId の決定的採番（決定 D79）', () {
    test('{playerId}:{printingId}:{連番} の形', () {
      final ids = _allInstanceIds(_start()).toSet();

      expect(ids, contains('A:E1-R:1'));
      expect(ids, contains('A:E1-R:6'));
      expect(ids, contains('B:M1-R:2'));
    });

    test('★★ 同じデッキを両側に使っても衝突しない ★★', () {
      // ★ソロの既定がこれ（決定 D81 / D88）。deckId まで同じものを両側に渡す。
      final same = _deck();
      final ids = _allInstanceIds(_start(a: same, b: same));

      expect(ids.length, 22 * 2, reason: '★16 + 6 の 2 人分');
      expect(ids.toSet().length, ids.length, reason: '★重複が 1 つも無い');
    });

    test('★同じ printingId が 2 つの DeckEntry に分かれても連番が続く', () {
      final split = _deck(entries: const [
        DeckEntry(printingId: 'M1-R', count: 2),
        DeckEntry(printingId: 'M1-R', count: 2),
        DeckEntry(printingId: 'E1-R', count: 3),
      ]);
      final ids = _allInstanceIds(_start(a: split, b: split));

      expect(ids.toSet().length, ids.length);
      expect(ids.toSet(), containsAll(['A:M1-R:1', 'A:M1-R:4']));
    });
  });

  group('★ 未知の刷りは投げる（決定 D35 / D80）', () {
    test('printingId がカタログに無ければ GameSetupException', () {
      expect(
        () => _start(
          a: _deck(entries: const [
            DeckEntry(printingId: 'M1-R', count: 8),
            DeckEntry(printingId: 'NOPE-R', count: 1),
          ]),
        ),
        throwsA(isA<GameSetupException>().having(
          (e) => e.unknownPrintingIds,
          'unknownPrintingIds',
          contains('NOPE-R'),
        )),
      );
    });

    test('★2 人分をまとめて出す（1 人目で止めない）', () {
      final broken1 = _deck(entries: const [
        DeckEntry(printingId: 'E1-R', count: 3),
        DeckEntry(printingId: 'GHOST-1', count: 1),
      ]);
      final broken2 = _deck(entries: const [
        DeckEntry(printingId: 'E1-R', count: 3),
        DeckEntry(printingId: 'GHOST-2', count: 1),
      ]);

      expect(
        () => _start(a: broken1, b: broken2),
        throwsA(isA<GameSetupException>().having(
          (e) => e.unknownPrintingIds,
          'unknownPrintingIds',
          containsAll(['GHOST-1', 'GHOST-2']),
        )),
      );
    });

    test('★printing はあるが Card が無い場合も拾う', () {
      expect(
        () => GameSetup.begin(
          players: [
            PlayerDeck(
              playerId: 'A',
              deck: _deck(entries: const [
                DeckEntry(printingId: 'ORPHAN-R', count: 1),
              ]),
            ),
            PlayerDeck(playerId: 'B', deck: _deck()),
          ],
          cards: _cards,
          printings: {
            ..._printings,
            'ORPHAN-R': _printing('ORPHAN-R', 'MISSING'),
          },
          rng: SeededRng(1),
          firstPlayerId: 'A',
        ),
        throwsA(isA<GameSetupException>().having(
          (e) => e.unknownPrintingIds,
          'unknownPrintingIds',
          contains('ORPHAN-R'),
        )),
      );
    });

    test('★6.1 の枚数違反では投げない（検証は呼び出し側 / D28）', () {
      final tiny = _deck(entries: const [
        DeckEntry(printingId: 'M1-R', count: 1),
        DeckEntry(printingId: 'E1-R', count: 1),
      ]);

      final state = _start(a: tiny, b: tiny);

      expect(state.playerOf('A').hand.length, 1, reason: '★あるだけ配る');
      expect(state.playerOf('A').energyField.length, 1);
    });
  });

  group('★ 引数の取り違えは投げる', () {
    test('プレイヤーが 2 人でない', () {
      expect(
        () => GameSetup.begin(
          players: [PlayerDeck(playerId: 'A', deck: _deck())],
          cards: _cards,
          printings: _printings,
          rng: SeededRng(1),
          firstPlayerId: 'A',
        ),
        throwsA(isA<GameSetupException>()),
      );
    });

    test('★playerId が重複している（同じデッキは可・同じ playerId は不可）', () {
      expect(
        () => GameSetup.begin(
          players: [
            PlayerDeck(playerId: 'A', deck: _deck()),
            PlayerDeck(playerId: 'A', deck: _deck()),
          ],
          cards: _cards,
          printings: _printings,
          rng: SeededRng(1),
          firstPlayerId: 'A',
        ),
        throwsA(isA<GameSetupException>()),
      );
    });

    test('firstPlayerId が参加者に居ない', () {
      expect(
        () => _start(firstPlayerId: 'Z'),
        throwsA(isA<GameSetupException>()),
      );
    });
  });

  group('★★ 6.2.1.6 が入る隙間 — 順序は型で守られている（決定 D80）★★', () {
    test('begin の戻り値は GameState ではない', () {
      final setup = GameSetup.begin(
        players: [
          PlayerDeck(playerId: 'A', deck: _deck()),
          PlayerDeck(playerId: 'B', deck: _deck(deckId: 'deck-2')),
        ],
        cards: _cards,
        printings: _printings,
        rng: SeededRng(1),
        firstPlayerId: 'A',
      );

      // ★遊べる GameState を得る道は dealInitialEnergy だけ。
      //   コンストラクタが private なので、GameSetup を他所で作ることもできない。
      expect(setup, isA<GameSetup>());
      expect(setup.dealInitialEnergy(rng: SeededRng(1)), isA<GameState>());
    });

    test('★begin の時点ではエネルギー置き場が空（6.2.1.7 を経ていない）', () {
      final setup = GameSetup.begin(
        players: [
          PlayerDeck(playerId: 'A', deck: _deck()),
          PlayerDeck(playerId: 'B', deck: _deck(deckId: 'deck-2')),
        ],
        cards: _cards,
        printings: _printings,
        rng: SeededRng(1),
        firstPlayerId: 'A',
      );

      // ★この盤面は 6.2.1 のどの時点とも一致しない。盤面に出さないこと。
      expect(setup.pendingState.playerOf('A').energyField, isEmpty);
      expect(setup.pendingState.playerOf('A').hand.length, 6,
          reason: '★6.2.1.5 までは終わっている');
    });
  });

  // =========================================================================
  // ★★ ソロ: 相手側に何を入れると何が変わるか (決定 D88 / §14-5) ★★
  //
  // ソロでも `GameState.players` は 2 人のまま (1.1.1) で、相手側には
  // **自分と同じデッキ**を入れる (D81 の既定)。
  //
  // ★★ 盤面設計メモ §14-5 は「seed が同じなら相手側に何を入れても
  //   自分側は完全に同一」と書いていた。**実測すると誤りである**（新所見 D-17）★★
  //   6.2.1 は**手順ごとに両プレイヤーを回す**（条文どおり）。
  //   `begin` が 6.2.1.2 のシャッフルを**2 人ぶん**終えてから
  //   `dealInitialEnergy` が 6.2.1.7 を回すので、
  //   **相手のデッキ枚数が変わると、そこで消費される乱数の量が変わり、
  //   自分のエネルギー抽出（4.9.3 の無作為）がずれる。**
  //
  // ★★ 「同じはず」で済ませない ★★
  //   D86 で「同じはず」を実際に測って 1 件ずれた前例がある。ここでも 1 件ずれた。
  // =========================================================================
  group('★★ ソロ: 相手デッキが自分側に及ぶ範囲 (決定 D88 / 新所見 D-17) ★★', () {
    /// 6.2.1.2 / 6.2.1.5 の産物（並びまで含める）。
    List<String> mainAndHand(GameState state, String playerId) {
      final player = state.playerOf(playerId);
      return [..._ids(player.hand), ..._ids(player.mainDeck)];
    }

    /// 6.2.1.7 の産物（同上）。
    List<String> energy(GameState state, String playerId) {
      final player = state.playerOf(playerId);
      return [..._ids(player.energyDeck), ..._ids(player.energyField)];
    }

    /// 枚数も種類も違う相手デッキ。
    Deck otherDeck() => _deck(
          deckId: 'deck-other',
          entries: const [
            DeckEntry(printingId: 'M1-R', count: 4),
            DeckEntry(printingId: 'L2-R', count: 1),
            DeckEntry(printingId: 'E1-R', count: 4),
          ],
        );

    GameState sameOpponent() => _start(a: _deck(), b: _deck());
    GameState otherOpponent() => _start(a: _deck(), b: otherDeck());

    test('★ 6.2.1.2 / 6.2.1.5 は相手デッキに依らない（先攻から順に処理される）', () {
      expect(mainAndHand(otherOpponent(), 'A'), mainAndHand(sameOpponent(), 'A'));
      // ★前提: 空リスト同士の比較になっていないこと。
      expect(mainAndHand(sameOpponent(), 'A'), isNotEmpty);
    });

    test('★★ 6.2.1.7 は相手デッキに依る（§14-5 の断定が誤り / D-17）★★', () {
      // ★★ ここが「同じはず」を実際に測って出た 1 件である ★★
      //   `begin` が 2 人ぶんの 6.2.1.2 を終えてから `dealInitialEnergy` が回る。
      //   相手のメインデッキ枚数が変わると `rng.shuffled` の消費量が変わり、
      //   自分の 4.9.3 の無作為抽出がずれる。
      expect(energy(otherOpponent(), 'A'), isNot(energy(sameOpponent(), 'A')));
      expect(energy(sameOpponent(), 'A'), isNotEmpty, reason: '★前提');
    });

    test('★★ だからソロは相手側に同じデッキを入れる（D81 の既定）★★', () {
      // ★同じデッキなら seed が同じで自分側は完全に再現する。
      //   ★空の Deck を採らない理由は別にある（§14-5）——
      //   6.2.1.5 で手札 0 枚という条文に存在しない状態を作り、
      //   7.6.2 が空のメインデッキ + 空の控え室で 10.2.2 を踏む経路が生まれる。
      final same = _deck();
      final a = _start(a: same, b: same);
      final b = _start(a: same, b: same);

      expect(mainAndHand(b, 'A'), mainAndHand(a, 'A'));
      expect(energy(b, 'A'), energy(a, 'A'));
      // ★対: seed が違えば変わる（比較が生きている）。
      final other = _start(seed: 99, a: same, b: same);
      expect(mainAndHand(other, 'A'), isNot(mainAndHand(a, 'A')));
    });

    test('★対: 相手側は当然変わる（比較が生きている）', () {
      expect(mainAndHand(otherOpponent(), 'B'),
          isNot(mainAndHand(sameOpponent(), 'B')));
    });
  });

  // =========================================================================
  // ★★ 6.2.1.6 マリガン（決定 D93 / M-B6）★★
  //
  // > 6.2.1.6 先攻プレイヤーから順に、各プレイヤーは自身の手札のカードを
  // > 任意の枚数選んで裏向きに脇に置き、置いた枚数と同じ枚数のカードを
  // > 自身のメインデッキ置き場の上から自身の手札に移動し、
  // > 脇に置いたカードをメインデッキ置き場に移動し、
  // > 1 枚以上移動した場合はシャッフルします。
  //
  // ★★ 分岐が 3 つある。出る側と出ない側を対で置く（D-10）★★
  //   「0 枚選べる」「N 枚選べる」「1 枚以上戻したらシャッフル」。
  //   ★**シャッフルが起きる側と起きない側を対で固定する。**
  //   0 枚なら乱数を消費しないことは**列挙ではなく実測**で見る（決定 D90-1 と同じ手法）。
  // =========================================================================
  group('★★ 6.2.1.6 マリガン（決定 D93）★★', () {
    test('★★ 0 枚 —— 乱数を 1 つも消費しない ★★', () {
      final rng = _CountingRng(SeededRng(1));
      final setup = _beginWith(rng);
      final before = rng.count;

      final after = setup.mulligan(choices: const [], rng: rng);

      expect(rng.count, before, reason: '★6.2.1.6 は「1 枚以上移動した場合は」と限っている');
      expect(_ids(after.pendingState.playerOf('A').hand),
          _ids(setup.pendingState.playerOf('A').hand));
      expect(_ids(after.pendingState.playerOf('A').mainDeck),
          _ids(setup.pendingState.playerOf('A').mainDeck),
          reason: '★1 枚も動かないのでメインデッキの並びも変わらない');
    });

    test('★★対 1 枚以上 —— 乱数を消費する ★★', () {
      final rng = _CountingRng(SeededRng(1));
      final setup = _beginWith(rng);
      final before = rng.count;

      setup.mulligan(
        choices: [
          MulliganChoice(
            playerId: 'A',
            instanceIds: [setup.pendingState.playerOf('A').hand.first.instanceId],
          ),
        ],
        rng: rng,
      );

      expect(rng.count, greaterThan(before), reason: '★5.5.1 のシャッフルが走る');
    });

    test('★★ 0 枚のマリガンは 6.2.1.7 の結果を 1 枚も動かさない ★★', () {
      // ★D-17 と同じ型の確認 —— 6.2.1 は手順ごとに両プレイヤーを回すので、
      //   どこかで乱数の消費量が変わると自分のエネルギー抽出がずれる。
      final withMulligan = () {
        final rng = SeededRng(7);
        return _beginWith(rng)
            .mulligan(choices: const [], rng: rng)
            .dealInitialEnergy(rng: rng);
      }();
      final without = () {
        final rng = SeededRng(7);
        return _beginWith(rng).dealInitialEnergy(rng: rng);
      }();

      expect(_allInstanceIds(withMulligan), _allInstanceIds(without));
    });

    test('★対: 1 枚以上のマリガンなら 6.2.1.7 の結果はずれる', () {
      final mulliganed = () {
        final rng = SeededRng(7);
        final setup = _beginWith(rng);
        return setup
            .mulligan(
              choices: [
                MulliganChoice(
                  playerId: 'A',
                  instanceIds: [
                    setup.pendingState.playerOf('A').hand.first.instanceId,
                  ],
                ),
              ],
              rng: rng,
            )
            .dealInitialEnergy(rng: rng);
      }();
      final plain = () {
        final rng = SeededRng(7);
        return _beginWith(rng).dealInitialEnergy(rng: rng);
      }();

      expect(_allInstanceIds(mulliganed), isNot(_allInstanceIds(plain)));
    });

    test('★★ 捨てた札は引き直しで戻ってこない（手順 2 と 3 の順）★★', () {
      // ★★ この検査が「メインデッキへ戻す前に引いている」ことの証拠である ★★
      //   メインデッキを手札より少なくしてあるので、順を入れ替えた実装なら
      //   **引ける枚数が増え、旧手札の札が戻ってきうる。**
      final rng = SeededRng(3);
      final setup = _beginWith(rng, deck: _smallMainDeck());
      final oldHand = _ids(setup.pendingState.playerOf('A').hand);
      expect(oldHand.length, 6);
      expect(setup.pendingState.playerOf('A').mainDeck.length, 2,
          reason: '★手札より少ないメインデッキを用意してある');

      final after = setup.mulligan(
        choices: [MulliganChoice(playerId: 'A', instanceIds: oldHand)],
        rng: rng,
      );

      final newHand = _ids(after.pendingState.playerOf('A').hand);
      expect(newHand.length, 2, reason: '★足りなければあるだけ（D28）');
      expect(newHand.toSet().intersection(oldHand.toSet()), isEmpty,
          reason: '★捨てた 6 枚は引き直しの時点でメインデッキに戻っていない');
      expect(after.pendingState.playerOf('A').mainDeck.length, 6,
          reason: '★2 枚引いたあとに 6 枚が戻る');
      expect(after.pendingState.playerOf('A').mulliganAside, isEmpty,
          reason: '★脇置きは 6.2.1.6 の手順内にしか存在しない');
    });

    test('N 枚 —— 手札の枚数は変わらず、選んだ札だけが入れ替わる', () {
      final rng = SeededRng(5);
      final setup = _beginWith(rng);
      final oldHand = _ids(setup.pendingState.playerOf('A').hand);
      final chosen = oldHand.take(2).toList();
      final deckBefore = setup.pendingState.playerOf('A').mainDeck.length;

      final after = setup.mulligan(
        choices: [MulliganChoice(playerId: 'A', instanceIds: chosen)],
        rng: rng,
      );

      final newHand = _ids(after.pendingState.playerOf('A').hand);
      expect(newHand.length, 6);
      expect(newHand.toSet().intersection(chosen.toSet()), isEmpty);
      expect(newHand.toSet().containsAll(oldHand.skip(2)), isTrue,
          reason: '★選ばなかった 4 枚は残る');
      expect(after.pendingState.playerOf('A').mainDeck.length, deckBefore);
    });

    test('★★ 1 枚以上戻したら本当にシャッフルする（移動しただけではない）★★', () {
      final rng = SeededRng(11);
      final setup = _beginWith(rng);
      final deckBefore = _ids(setup.pendingState.playerOf('A').mainDeck);
      final chosen = setup.pendingState.playerOf('A').hand.first.instanceId;

      final after = setup.mulligan(
        choices: [
          MulliganChoice(playerId: 'A', instanceIds: [chosen]),
        ],
        rng: rng,
      );
      final deckAfter = _ids(after.pendingState.playerOf('A').mainDeck);

      // ★シャッフルしなかった場合の並び（上から 1 枚引いて、戻す 1 枚を一番下へ）。
      final unshuffled = [...deckBefore.skip(1), chosen];
      expect(deckAfter.toSet(), unshuffled.toSet(), reason: '★中身は同じ');
      expect(deckAfter, isNot(unshuffled),
          reason: '★★並びが変わっている = 5.5.1 が走った★★');
    });

    test('★★ 脇に置く順は手札のリスト順（選んだ順に依らない）★★', () {
      // ★依らせると 5.5.1 の入力列が変わり、同じ seed でも盤面が再現できない。
      List<String> run(bool reversed) {
        final rng = SeededRng(13);
        final setup = _beginWith(rng);
        final hand =
            _ids(setup.pendingState.playerOf('A').hand).take(3).toList();
        return _ids(setup
            .mulligan(
              choices: [
                MulliganChoice(
                  playerId: 'A',
                  instanceIds: reversed ? hand.reversed.toList() : hand,
                ),
              ],
              rng: rng,
            )
            .pendingState
            .playerOf('A')
            .mainDeck);
      }

      expect(run(true), run(false));
    });

    test('★ choices の並びは結果に影響しない（処理順は先攻から / 6.2.1.6）', () {
      List<String> run(bool reversed) {
        final rng = SeededRng(17);
        final setup = _beginWith(rng);
        final a = MulliganChoice(
          playerId: 'A',
          instanceIds: [setup.pendingState.playerOf('A').hand.first.instanceId],
        );
        final b = MulliganChoice(
          playerId: 'B',
          instanceIds: [setup.pendingState.playerOf('B').hand.first.instanceId],
        );
        return _allInstanceIds(setup
            .mulligan(choices: reversed ? [b, a] : [a, b], rng: rng)
            .pendingState);
      }

      expect(run(true), run(false));
    });

    test('★ handsForMulligan は先攻が先（6.2.1.6「先攻プレイヤーから順に」）', () {
      expect(
          _beginWith(SeededRng(1), firstPlayerId: 'B')
              .handsForMulligan
              .first
              .playerId,
          'B');
      final hands = _beginWith(SeededRng(1)).handsForMulligan;
      expect(hands.first.playerId, 'A');
      expect(hands.length, 2);
      expect(hands.first.hand.length, 6);
    });

    group('★ 取り違えは投げる（黙って落とさない / D35）', () {
      test('この盤面に居ないプレイヤー', () {
        final rng = SeededRng(1);
        expect(
          () => _beginWith(rng).mulligan(
            choices: const [MulliganChoice(playerId: 'Z', instanceIds: [])],
            rng: rng,
          ),
          throwsA(isA<GameSetupException>()),
        );
      });

      test('同じプレイヤーの選択が 2 つ', () {
        final rng = SeededRng(1);
        expect(
          () => _beginWith(rng).mulligan(
            choices: const [
              MulliganChoice(playerId: 'A', instanceIds: []),
              MulliganChoice(playerId: 'A', instanceIds: []),
            ],
            rng: rng,
          ),
          throwsA(isA<GameSetupException>()),
        );
      });

      test('★手札に無いカード（理由に instanceId が載る）', () {
        final rng = SeededRng(1);
        expect(
          () => _beginWith(rng).mulligan(
            choices: const [
              MulliganChoice(playerId: 'A', instanceIds: ['A:ghost:1']),
            ],
            rng: rng,
          ),
          throwsA(isA<GameSetupException>()
              .having((e) => e.toString(), 'message', contains('A:ghost:1'))),
        );
      });

      test('同じカードを 2 回選んでいる', () {
        final rng = SeededRng(1);
        final setup = _beginWith(rng);
        final id = setup.pendingState.playerOf('A').hand.first.instanceId;
        expect(
          () => setup.mulligan(
            choices: [
              MulliganChoice(playerId: 'A', instanceIds: [id, id]),
            ],
            rng: rng,
          ),
          throwsA(isA<GameSetupException>()),
        );
      });

      test('★★ 2 回目の mulligan（6.2.1.6 は 1 回だけ）★★', () {
        final rng = SeededRng(1);
        final once = _beginWith(rng).mulligan(choices: const [], rng: rng);
        expect(
          () => once.mulligan(choices: const [], rng: rng),
          throwsA(isA<GameSetupException>()),
        );
      });
    });
  });
}
