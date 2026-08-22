import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type) =>
    Card(cardNumber: number, name: number, cardType: type);

final _master = <String, Card>{
  'M1': _card('M1', CardType.member),
  'L1': _card('L1', CardType.live),
};

final _engine = StepEngine(cards: _master, rng: SeededRng(1));

var _seq = 0;
CardInstance _on(String cardNumber, {String ownerId = 'A'}) => CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
    );

GameState _at(
  PhaseId phase,
  StepId step, {
  String firstPlayerId = 'A',
  LiveJudgementRecord? liveJudgement,
  int turnNumber = 1,
  PlayerState? a,
}) =>
    GameState(
      players: [
        a ?? const PlayerState(playerId: 'A'),
        const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: firstPlayerId,
      cursor: StepCursor(phase, step),
      liveJudgement: liveJudgement,
      turnNumber: turnNumber,
    );

/// 1 ステップ進めて履歴に積む。
GameSession _step(GameSession session, {StepTransition? choice}) =>
    session.record(_engine.advance(session.state, choice: choice).state);

void main() {
  group('基本', () {
    test('履歴が空なら戻せない', () {
      final session =
          GameSession(state: _at(PhaseId.firstActive, StepId.s7_4_1));
      expect(session.canUndo, isFalse);
      expect(session.undo(), isNull);
      expect(session.undoStep(), isNull);
    });

    test('1 件戻すと直前の盤面に戻る', () {
      var session =
          GameSession(state: _at(PhaseId.firstActive, StepId.s7_4_1));
      session = _step(session);

      expect(session.state.cursor.step, StepId.s7_4_2);
      expect(session.undo()!.state.cursor.step, StepId.s7_4_1);
    });

    test('深さの上限を超えたら古いものから捨てる', () {
      var session = GameSession(
        state: _at(PhaseId.firstMain, StepId.s7_7_2),
        history: const GameHistory(maxDepth: 3),
      );
      for (var i = 0; i < 10; i++) {
        session = session.record(session.state);
      }
      expect(session.history.depth, 3);
    });
  });

  group('★1 ステップ戻す = カーソルが変わるまで pop', () {
    test('同じステップ内の手動操作をまとめて 1 回で戻す', () {
      var session = GameSession(
        state: _at(PhaseId.firstMain, StepId.s7_7_2,
            a: const PlayerState(playerId: 'A')),
      );
      final start = session.state;

      // 7.7.2 のプレイタイミング内で手動操作を 3 回行う。
      for (var i = 0; i < 3; i++) {
        session = session.record(
          replaceZone(session.state, 'A', Zone.hand,
              [...cardsIn(session.state, 'A', Zone.hand), _on('M1')]),
        );
      }
      expect(cardsIn(session.state, 'A', Zone.hand).length, 3);

      // ★undo は 1 操作ずつ戻る。
      expect(cardsIn(session.undo()!.state, 'A', Zone.hand).length, 2);

      // ★undoStep はステップの入口まで一気に戻る。
      final stepped = session.undoStep()!;
      expect(cardsIn(stepped.state, 'A', Zone.hand), isEmpty);
      expect(stepped.state.cursor, start.cursor);
    });
  });

  group('★★8.4.12 → 8.4.9 のループを 2 周して巻き戻す★★', () {
    test('2 周目の 8.4.9 から戻ると 1 周目の 8.4.12 に着地する', () {
      // 静的グラフ上、8.4.9 の前任は 8.4.8 と 8.4.12 の 2 つある。
      // 2 周目の 8.4.9 から 1 つ戻る先は 1 周目の 8.4.12 であって
      // 8.4.8 ではない。逆辺では決定できないので通過履歴から戻す。
      final predecessors = stepGraph.entries
          .where((e) => e.value.any((t) => t.target == StepId.s8_4_9))
          .map((e) => e.key)
          .toSet();
      expect(predecessors, {StepId.s8_4_8, StepId.s8_4_12},
          reason: '前任が 2 つあることが前提');

      final loop = stepGraph[StepId.s8_4_12]!
          .firstWhere((t) => t.target == StepId.s8_4_9);

      // 8.4.9 から始めて 8.4.12 でループを 1 回選び、2 周目の 8.4.9 まで来る。
      var session =
          GameSession(state: _at(PhaseId.liveJudgement, StepId.s8_4_9));

      session = _step(session); // 8.4.9 -> 8.4.10
      session = _step(session); // 8.4.10 -> 8.4.11
      session = _step(session); // 8.4.11 -> 8.4.12
      session = _step(session, choice: loop); // ★8.4.12 -> 8.4.9 (2 周目)

      expect(session.state.cursor.step, StepId.s8_4_9, reason: '2 周目の 8.4.9');

      // ★ここで 1 ステップ戻す。
      final back = session.undoStep()!;
      expect(back.state.cursor.step, StepId.s8_4_12,
          reason: '★1 周目の 8.4.12 に着地する');
      expect(back.state.cursor.step, isNot(StepId.s8_4_8),
          reason: '★静的グラフの逆辺なら 8.4.8 に着地して誤る');
    });

    test('2 周目を最後まで進めても履歴から順に戻れる', () {
      final loop = stepGraph[StepId.s8_4_12]!
          .firstWhere((t) => t.target == StepId.s8_4_9);
      final exit = stepGraph[StepId.s8_4_12]!
          .firstWhere((t) => t.target == StepId.s8_4_13);

      var session =
          GameSession(state: _at(PhaseId.liveJudgement, StepId.s8_4_9));
      // 1 周目
      session = _step(session);
      session = _step(session);
      session = _step(session);
      session = _step(session, choice: loop);
      // 2 周目
      session = _step(session);
      session = _step(session);
      session = _step(session);
      session = _step(session, choice: exit);

      expect(session.state.cursor.step, StepId.s8_4_13);

      // 戻ると 2 周目の 8.4.12 → 8.4.11 → 8.4.10 → 8.4.9 → 1 周目の 8.4.12 …
      final trail = <StepId>[];
      var back = session.undoStep();
      while (back != null) {
        trail.add(back.state.cursor.step);
        back = back.undoStep();
      }

      expect(trail, [
        StepId.s8_4_12, // 2 周目
        StepId.s8_4_11,
        StepId.s8_4_10,
        StepId.s8_4_9, // 2 周目の入口
        StepId.s8_4_12, // ★1 周目
        StepId.s8_4_11,
        StepId.s8_4_10,
        StepId.s8_4_9, // 1 周目の入口
      ]);
    });
  });

  group('★★ターン境界を跨ぐ巻き戻しで firstPlayerId が復元される★★', () {
    test('8.4.13 が書き換えた先攻が戻る', () {
      // 8.4.13 は firstPlayerId を書き換える唯一のステップ。
      // 逆操作方式ならここに明示的な復元を書く必要があり、書き忘れやすい。
      // スナップショット方式では自動的に復元される。
      var session = GameSession(
        state: _at(
          PhaseId.liveJudgement,
          StepId.s8_4_13,
          firstPlayerId: 'B',
          turnNumber: 5,
          liveJudgement: const LiveJudgementRecord(
            winnerIds: {'A', 'B'},
            movedToSuccessIds: {'A'},
          ),
        ),
      );

      session = _step(session); // 8.4.13 実行 -> 先攻が A になる
      expect(session.state.firstPlayerId, 'A');
      expect(session.state.cursor.step, StepId.s8_4_14);

      session = _step(session); // 8.4.14 -> ターン終了、次ターンの 7.4.1 へ
      expect(session.state.turnNumber, 6);
      expect(session.state.cursor,
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
      expect(session.state.liveJudgement, isNull);

      // ★ターン境界を跨いで 1 ステップ戻す。
      final back = session.undoStep()!;
      expect(back.state.cursor,
          const StepCursor(PhaseId.liveJudgement, StepId.s8_4_14));
      expect(back.state.turnNumber, 5, reason: 'ターン番号が戻る');
      expect(back.state.firstPlayerId, 'A', reason: '8.4.13 実行後の状態');

      // ★もう 1 ステップ戻すと 8.4.13 の実行前。先攻が B に復元される。
      final before = back.undoStep()!;
      expect(before.state.cursor.step, StepId.s8_4_13);
      expect(before.state.firstPlayerId, 'B',
          reason: '★8.4.13 が書き換えた firstPlayerId が復元されている');
      expect(before.state.liveJudgement, isNotNull,
          reason: '8.4.14 が落とした記録も戻る');
      expect(before.state.liveJudgement!.movedToSuccessIds, {'A'});
    });
  });

  group('スナップショットは構造共有される', () {
    test('変更していない領域は同じインスタンスを指す', () {
      // 案 A（逆操作）を採らなかった主な理由がこれ。
      final start = _at(
        PhaseId.firstMain,
        StepId.s7_7_2,
        a: PlayerState(playerId: 'A', mainDeck: [_on('M1'), _on('M1')]),
      );
      var session = GameSession(state: start);

      session = session.record(
        replaceZone(session.state, 'A', Zone.hand, [_on('M1')]),
      );

      final before = session.history.last!.state;
      // 手札だけが変わり、メインデッキのリストは同じインスタンスを共有する。
      expect(
        identical(cardsIn(before, 'A', Zone.mainDeck),
            cardsIn(session.state, 'A', Zone.mainDeck)),
        isTrue,
      );
    });
  });

  group('履歴 1 件が StepCursor を持つ', () {
    test('entry.cursor は state.cursor と一致する', () {
      var session =
          GameSession(state: _at(PhaseId.firstActive, StepId.s7_4_1));
      session = _step(session);

      final entry = session.history.last!;
      expect(entry.cursor, entry.state.cursor);
      expect(entry.cursor,
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
    });
  });
}
