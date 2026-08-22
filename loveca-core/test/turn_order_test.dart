import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

GameState _state({String firstPlayerId = 'A'}) => GameState(
      players: const [PlayerState(playerId: 'A'), PlayerState(playerId: 'B')],
      firstPlayerId: firstPlayerId,
      cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
    );

void main() {
  group('手番プレイヤー — 総合ルール 7.3.2.1', () {
    test('先攻通常フェイズ配下の手番は先攻', () {
      final state = _state();
      for (final phase in phaseCycle.where(
          (p) => p.group == PhaseGroup.firstNormal)) {
        expect(turnPlayerOf(state, phase), 'A', reason: phase.name);
      }
    });

    test('後攻通常フェイズ配下の手番は後攻', () {
      final state = _state();
      for (final phase in phaseCycle.where(
          (p) => p.group == PhaseGroup.secondNormal)) {
        expect(turnPlayerOf(state, phase), 'B', reason: phase.name);
      }
    });

    test('パフォーマンスフェイズの手番は先攻 / 後攻 (8.3.2)', () {
      final state = _state();
      expect(turnPlayerOf(state, PhaseId.firstPerformance), 'A');
      expect(turnPlayerOf(state, PhaseId.secondPerformance), 'B');
    });

    test('★手番を指定しない 2 フェイズは null (7.2.1)', () {
      final state = _state();
      expect(turnPlayerOf(state, PhaseId.liveCardSet), isNull);
      expect(turnPlayerOf(state, PhaseId.liveJudgement), isNull);

      // null になるのはこの 2 つだけ。
      expect(
        phaseCycle.where((p) => turnPlayerOf(state, p) == null).toSet(),
        {PhaseId.liveCardSet, PhaseId.liveJudgement},
      );
    });
  });

  group('アクティブプレイヤー — 総合ルール 7.2.1.1 / 7.2.1.2', () {
    test('7.2.1.1 手番を指定するフェイズでは手番プレイヤー', () {
      final state = _state();
      for (final phase in phaseCycle.where((p) => p.hasTurnPlayer)) {
        expect(activePlayerOf(state, phase), turnPlayerOf(state, phase),
            reason: phase.name);
      }
    });

    test('★7.2.1.2 手番を指定しないフェイズでは先攻プレイヤー', () {
      final state = _state();
      expect(activePlayerOf(state, PhaseId.liveCardSet), 'A');
      expect(activePlayerOf(state, PhaseId.liveJudgement), 'A');
    });

    test('非アクティブプレイヤーは相手 (7.2.2)', () {
      final state = _state();
      expect(inactivePlayerOf(state, PhaseId.firstMain), 'B');
      expect(inactivePlayerOf(state, PhaseId.secondMain), 'A');
      expect(inactivePlayerOf(state, PhaseId.liveJudgement), 'B');
    });
  });

  group('★firstPlayerId の入れ替え (8.4.13) が全フェイズに波及する', () {
    test('先攻が B に移ると 12 フェイズすべての手番が入れ替わる', () {
      final before = _state(firstPlayerId: 'A');
      final after = _state(firstPlayerId: 'B');

      for (final phase in phaseCycle) {
        final b = turnPlayerOf(before, phase);
        final a = turnPlayerOf(after, phase);
        if (phase.hasTurnPlayer) {
          expect(a, isNot(b), reason: '${phase.name} の手番が入れ替わっていない');
        } else {
          expect(b, isNull);
          expect(a, isNull);
        }
      }

      // 手番を指定しないフェイズのアクティブプレイヤーも先攻に追随する。
      expect(activePlayerOf(before, PhaseId.liveJudgement), 'A');
      expect(activePlayerOf(after, PhaseId.liveJudgement), 'B');
    });
  });

  group('現在のフェイズに対する解決', () {
    test('cursor のフェイズから解決する', () {
      final state = _state();
      expect(currentTurnPlayer(state), 'A');
      expect(currentActivePlayer(state), 'A');

      final live = state.copyWith(
        cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_1),
      );
      expect(currentTurnPlayer(live), isNull);
      expect(currentActivePlayer(live), 'A');
    });
  });

  group('opponentOf', () {
    test('相手が定まらない場合は例外', () {
      final solo = GameState(
        players: const [PlayerState(playerId: 'A')],
        firstPlayerId: 'A',
        cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
      );
      expect(() => opponentOf(solo, 'A'), throwsArgumentError);
    });
  });
}
