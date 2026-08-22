import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// テスト用のカードマスタ
// ---------------------------------------------------------------------------

/// メンバーカードを作る。
Card _member(
  String number, {
  int? bladeCount,
  Map<HeartColor, int> hearts = const {},
}) =>
    Card(
      cardNumber: number,
      name: number,
      cardType: CardType.member,
      cost: 4,
      bladeCount: bladeCount,
      hearts: hearts,
    );

/// 盤面のカード 1 枚。[orientation] を省略すると向きを持たない (4.5.5.2)。
var _seq = 0;
CardInstance _on(
  String cardNumber, {
  CardOrientation? orientation,
  String ownerId = 'A',
}) =>
    CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
      orientation: orientation,
    );

/// メンバー 1 枚だけのエリア。
MemberArea _area(
  MemberAreaSlot slot,
  List<MemberStack> stacks, {
  List<CardInstance> orphans = const [],
}) =>
    MemberArea(slot: slot, stacks: stacks, orphans: orphans);

GameState _state({
  List<MemberArea> aMemberAreas = const [],
  List<MemberArea> bMemberAreas = const [],
}) =>
    GameState(
      players: [
        PlayerState(playerId: 'A', memberAreas: aMemberAreas),
        PlayerState(playerId: 'B', memberAreas: bMemberAreas),
      ],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_10),
    );

void main() {
  // -------------------------------------------------------------------------
  group('8.3.10 ブレード合計', () {
    final aggregator = LiveAggregator(cards: {
      'M-blade2': _member('M-blade2', bladeCount: 2),
      'M-blade3': _member('M-blade3', bladeCount: 3),
      'M-noblade': _member('M-noblade'), // ★bladeCount が null
    });

    test('アクティブ状態のメンバーだけを合計する', () {
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.leftSide, [
          MemberStack(member: _on('M-blade2', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-blade3', orientation: CardOrientation.active)),
        ]),
      ]);

      expect(aggregator.bladeTotal(state, 'A').total, 5);
    });

    test('★ウェイト状態のメンバーは数えない', () {
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.leftSide, [
          MemberStack(member: _on('M-blade2', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-blade3', orientation: CardOrientation.wait)),
        ]),
      ]);

      expect(aggregator.bladeTotal(state, 'A').total, 2);
    });

    test('★下に重ねられたメンバーカードのブレードは数えない (4.5.5.2)', () {
      // 4.5.5.2 により下のカードは向きを示す配置状態を持たないため、
      // アクティブ状態になりえない。
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.center, [
          MemberStack(
            member: _on('M-blade2', orientation: CardOrientation.active),
            beneath: [_on('M-blade3'), _on('M-blade3')],
          ),
        ]),
      ]);

      expect(aggregator.bladeTotal(state, 'A').total, 2,
          reason: '下の M-blade3 × 2 が加算されてはいけない');
    });

    test('★孤児カードのブレードは数えない (4.5.5.4.1)', () {
      final state = _state(aMemberAreas: [
        _area(
          MemberAreaSlot.center,
          [MemberStack(member: _on('M-blade2', orientation: CardOrientation.active))],
          orphans: [_on('M-blade3')],
        ),
      ]);

      expect(aggregator.bladeTotal(state, 'A').total, 2);
    });

    test('★bladeCount が null のメンバーは 0 として扱い、除外に数えない', () {
      // ブレードアイコンを持たないメンバーは配信データに 73 種実在する。
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.leftSide, [
          MemberStack(member: _on('M-noblade', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-blade2', orientation: CardOrientation.active)),
        ]),
      ]);

      final result = aggregator.bladeTotal(state, 'A');
      expect(result.total, 2);
      expect(result.hasExclusions, isFalse, reason: '未知カードではない');
      expect(result.excludedCount, 0);
    });

    test('相手のメンバーは数えない', () {
      final state = _state(
        aMemberAreas: [
          _area(MemberAreaSlot.center, [
            MemberStack(member: _on('M-blade2', orientation: CardOrientation.active)),
          ]),
        ],
        bMemberAreas: [
          _area(MemberAreaSlot.center, [
            MemberStack(
              member: _on('M-blade3',
                  orientation: CardOrientation.active, ownerId: 'B'),
            ),
          ]),
        ],
      );

      expect(aggregator.bladeTotal(state, 'A').total, 2);
      expect(aggregator.bladeTotal(state, 'B').total, 3);
    });

    test('★未知の cardNumber は例外を投げず除外して記録する', () {
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.leftSide, [
          MemberStack(member: _on('M-blade2', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-unknown', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.rightSide, [
          MemberStack(member: _on('M-unknown', orientation: CardOrientation.active)),
        ]),
      ]);

      final result = aggregator.bladeTotal(state, 'A');
      expect(result.total, 2);
      expect(result.hasExclusions, isTrue);
      expect(result.excludedCount, 2, reason: '枚数で数える');
      expect(result.unknownCardNumbers, ['M-unknown'], reason: '重複は排除する');
    });

    test('メンバーが 0 枚なら 0', () {
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.center, const []),
      ]);
      expect(aggregator.bladeTotal(state, 'A').total, 0);
    });

    test('未知の playerId は例外を投げる (呼び出し側のバグ)', () {
      final state = _state();
      expect(() => aggregator.bladeTotal(state, 'Z'), throwsArgumentError);
    });
  });
}
