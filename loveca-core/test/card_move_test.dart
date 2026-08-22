import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

var _seq = 0;
CardInstance _on(String cardNumber, {String ownerId = 'A'}) => CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
    );

GameState _state({
  List<CardInstance> hand = const [],
  List<CardInstance> mainDeck = const [],
  List<CardInstance> resolution = const [],
}) =>
    GameState(
      players: [
        PlayerState(playerId: 'A', hand: hand, mainDeck: mainDeck),
        const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
      resolution: resolution,
    );

void main() {
  group('cardsIn / replaceZone — Zone を受ける', () {
    test('プレイヤーに属する 8 領域を読み書きできる', () {
      var state = _state();
      const zones = [
        Zone.hand,
        Zone.mainDeck,
        Zone.energyDeck,
        Zone.energyField,
        Zone.liveStage,
        Zone.successLive,
        Zone.waitingRoom,
        Zone.exile,
      ];

      for (final zone in zones) {
        expect(cardsIn(state, 'A', zone), isEmpty, reason: zone.name);
        state = replaceZone(state, 'A', zone, [_on('C-${zone.name}')]);
        expect(cardsIn(state, 'A', zone).length, 1, reason: zone.name);
        // 相手の同じ領域は影響を受けない。
        expect(cardsIn(state, 'B', zone), isEmpty, reason: zone.name);
      }
    });

    test('★解決領域は受け付けない (4.14.1 共有で 1 つだけ)', () {
      // プレイヤーごとの領域として読むと 8.3.12 (絞らない) と
      // 8.3.14 (ownerId で絞る) を取り違える。
      final state = _state();
      expect(() => cardsIn(state, 'A', Zone.resolution), throwsArgumentError);
      expect(() => replaceZone(state, 'A', Zone.resolution, const []),
          throwsArgumentError);
    });

    test('★メンバーエリアとステージは受け付けない (4.5.5 / 4.4.1)', () {
      final state = _state();
      for (final zone in [Zone.memberArea, Zone.stage]) {
        expect(() => cardsIn(state, 'A', zone), throwsArgumentError,
            reason: zone.name);
        expect(() => replaceZone(state, 'A', zone, const []),
            throwsArgumentError, reason: zone.name);
      }
    });

    test('解決領域は専用の関数で差し替える', () {
      final state = replaceResolution(_state(), [_on('C1')]);
      expect(state.resolution.length, 1);
    });
  });

  group('★ルール外の置き場は別の関数 (OutOfRuleZone)', () {
    test('mulliganAside / freeArea を読み書きできる', () {
      var state = _state();
      for (final zone in OutOfRuleZone.values) {
        expect(cardsInOutOfRule(state, 'A', zone), isEmpty);
        state = replaceOutOfRuleZone(state, 'A', zone, [_on('C-${zone.name}')]);
        expect(cardsInOutOfRule(state, 'A', zone).length, 1);
      }
      // 4 章の領域は影響を受けない。
      expect(cardsIn(state, 'A', Zone.hand), isEmpty);
    });
  });

  group('insertInto — 一番上 / 一番下', () {
    test('★index 0 が一番上 (4.8.2)', () {
      final zone = [_on('X'), _on('Y')];
      final added = _on('NEW');

      final top = insertInto(zone, [added], ZonePosition.top);
      expect(top.first.cardNumber, 'NEW');

      // 10.2.3「メインデッキ置き場にカードがある場合、それらのカードの下に移動」
      final bottom = insertInto(zone, [added], ZonePosition.bottom);
      expect(bottom.last.cardNumber, 'NEW');
    });

    test('元のリストを破壊しない', () {
      final zone = [_on('X')];
      insertInto(zone, [_on('NEW')], ZonePosition.top);
      expect(zone.length, 1);
    });
  });
}
