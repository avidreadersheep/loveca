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
          setup.stateBeforeMulligan.playerOf('A').energyDeck);

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
      // ★一人回しの既定がこれ（決定 D81）。deckId まで同じものを両側に渡す。
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
      expect(setup.stateBeforeMulligan.playerOf('A').energyField, isEmpty);
      expect(setup.stateBeforeMulligan.playerOf('A').hand.length, 6,
          reason: '★6.2.1.5 までは終わっている');
    });
  });
}
