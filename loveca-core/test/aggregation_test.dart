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

/// ライブカードを作る。
Card _live(
  String number, {
  int score = 0,
  Map<HeartColor, int> bladeHearts = const {},
  Map<BladeHeartEffect, int> bladeHeartEffects = const {},
}) =>
    Card(
      cardNumber: number,
      name: number,
      cardType: CardType.live,
      score: score,
      bladeHearts: bladeHearts,
      bladeHeartEffects: bladeHeartEffects,
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
  List<CardInstance> resolution = const [],
}) =>
    GameState(
      players: [
        PlayerState(playerId: 'A', memberAreas: aMemberAreas),
        PlayerState(playerId: 'B', memberAreas: bMemberAreas),
      ],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_10),
      resolution: resolution,
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

  // -------------------------------------------------------------------------
  group('8.3.12.1 ドロー枚数', () {
    final aggregator = LiveAggregator(cards: {
      'L-draw1': _live('L-draw1', bladeHeartEffects: {BladeHeartEffect.draw: 1}),
      'L-draw2': _live('L-draw2', bladeHeartEffects: {BladeHeartEffect.draw: 2}),
      'L-score1': _live('L-score1', bladeHeartEffects: {BladeHeartEffect.score: 1}),
      'M-plain': _member('M-plain', bladeCount: 1),
    });

    test('解決領域のドローアイコンを合計する', () {
      final state = _state(resolution: [
        _on('L-draw1'),
        _on('L-draw2'),
      ]);
      expect(aggregator.yellDrawCount(state).count, 3);
    });

    test('★スコアアイコンは数えない (8.4.2.1 で別に数える)', () {
      final state = _state(resolution: [
        _on('L-draw1'),
        _on('L-score1'),
      ]);
      expect(aggregator.yellDrawCount(state).count, 1);
    });

    test('ブレードハート効果を持たないカードは 0', () {
      final state = _state(resolution: [_on('M-plain'), _on('M-plain')]);
      expect(aggregator.yellDrawCount(state).count, 0);
    });

    test('解決領域が空なら 0', () {
      expect(aggregator.yellDrawCount(_state()).count, 0);
    });

    test('★★後攻パフォーマンス時、後攻は先攻のドローアイコン分も引く★★', () {
      // 総合ルール 4.14.1 により解決領域は両プレイヤー共有で 1 つだけ存在し、
      // 8.4.8 まで片付かない。したがって先攻パフォーマンスフェイズ (8.3.11) で
      // 先攻が置いたエールカードは、後攻パフォーマンスフェイズに入っても
      // 解決領域に残ったままである。
      //
      // 8.3.12 は「解決領域に置かれている**すべてのカード**」と書き、
      // 8.3.14 の「解決領域の**自分の**カード」と明確に書き分けられている。
      // よって後攻は先攻のドローアイコンの分も引く。
      //
      // ★今回いちばん直感に反する挙動。ここを固定する。
      final state = _state(resolution: [
        // 先攻 A が 8.3.11 のエールで置いたカード (まだ残っている)
        _on('L-draw2', ownerId: 'A'),
        // 後攻 B が自分のパフォーマンスフェイズで置いたカード
        _on('L-draw1', ownerId: 'B'),
      ]);

      // 手番が後攻 B であっても、解決領域の全カードを数える。
      expect(aggregator.yellDrawCount(state).count, 3,
          reason: '後攻 B は自分の 1 枚 + 先攻 A の 2 枚 = 3 枚引く');

      // ★対比: 8.3.14 のハート集計は ownerId で絞るため、
      //   同じ解決領域でも参照範囲が違う。この非対称が条文どおり。
    });

    test('★yellDrawCount は playerId を受け取らない (型で絞り込みを封じている)', () {
      // 引数が GameState 1 つだけであることを、呼び出しの形で固定する。
      // 絞り込みフラグを足すと 8.3.14 と取り違える。
      final state = _state(resolution: [
        _on('L-draw1', ownerId: 'A'),
        _on('L-draw1', ownerId: 'B'),
      ]);
      final YellDrawCount result = aggregator.yellDrawCount(state);
      expect(result.count, 2);
    });

    test('★未知の cardNumber は例外を投げず除外して記録する', () {
      final state = _state(resolution: [
        _on('L-draw1'),
        _on('L-unknown'),
      ]);
      final result = aggregator.yellDrawCount(state);
      expect(result.count, 1);
      expect(result.excludedCount, 1);
      expect(result.unknownCardNumbers, ['L-unknown']);
    });
  });
}
