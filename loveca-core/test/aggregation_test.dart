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
  List<CardInstance> aLiveStage = const [],
  List<CardInstance> bLiveStage = const [],
  List<CardInstance> resolution = const [],
}) =>
    GameState(
      players: [
        PlayerState(
          playerId: 'A',
          memberAreas: aMemberAreas,
          liveStage: aLiveStage,
        ),
        PlayerState(
          playerId: 'B',
          memberAreas: bMemberAreas,
          liveStage: bLiveStage,
        ),
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

  // -------------------------------------------------------------------------
  group('8.3.14 ライブ所有ハート', () {
    final aggregator = LiveAggregator(cards: {
      'M-pink2': _member('M-pink2', bladeCount: 1, hearts: {HeartColor.pink: 2}),
      'M-blue1': _member('M-blue1', bladeCount: 1, hearts: {HeartColor.blue: 1}),
      'M-none': _member('M-none', bladeCount: 1), // ★hearts が空
      'L-bhAll1': _live('L-bhAll1', bladeHearts: {HeartColor.all: 1}),
      'L-bhGray2': _live('L-bhGray2', bladeHearts: {HeartColor.gray: 2}),
      'L-bhPink1': _live('L-bhPink1', bladeHearts: {HeartColor.pink: 1}),
      'L-drawOnly':
          _live('L-drawOnly', bladeHeartEffects: {BladeHeartEffect.draw: 1}),
    });

    test('★ウェイト状態のメンバーのハートも数える (8.3.10 との非対称)', () {
      // 8.3.10 はアクティブ状態のメンバーのみだが、8.3.14 はすべてのメンバー。
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.leftSide, [
          MemberStack(member: _on('M-pink2', orientation: CardOrientation.active)),
        ]),
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-blue1', orientation: CardOrientation.wait)),
        ]),
      ]);

      final result = aggregator.ownedHearts(state, 'A');
      expect(result.hearts, {HeartColor.pink: 2, HeartColor.blue: 1});
      expect(result.total, 3);

      // 同じ盤面で 8.3.10 はアクティブの 1 枚分だけ。
      expect(aggregator.bladeTotal(state, 'A').total, 1);
    });

    test('★下に重ねられたメンバーカードのハートは数えない (4.5.4 / 4.5.5.2)', () {
      // 4.5.4 はメンバーエリアのメンバーカードが向きを持つと定め、
      // 4.5.5.2 は下に重ねられたカードが向きを持たないと定める。
      // 条文は両者を別のものとして扱っている。
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.center, [
          MemberStack(
            member: _on('M-pink2', orientation: CardOrientation.active),
            beneath: [_on('M-blue1'), _on('M-blue1')],
          ),
        ]),
      ]);

      expect(aggregator.ownedHearts(state, 'A').hearts, {HeartColor.pink: 2},
          reason: '下の M-blue1 × 2 の青ハートが入ってはいけない');
    });

    test('★孤児カードのハートは数えない (4.5.5.4.1)', () {
      final state = _state(aMemberAreas: [
        _area(
          MemberAreaSlot.center,
          [MemberStack(member: _on('M-pink2', orientation: CardOrientation.active))],
          orphans: [_on('M-blue1')],
        ),
      ]);

      expect(aggregator.ownedHearts(state, 'A').hearts, {HeartColor.pink: 2});
    });

    test('hearts が空のメンバーは 0 として扱い、除外に数えない', () {
      final state = _state(aMemberAreas: [
        _area(MemberAreaSlot.center, [
          MemberStack(member: _on('M-none', orientation: CardOrientation.active)),
        ]),
      ]);

      final result = aggregator.ownedHearts(state, 'A');
      expect(result.hearts, isEmpty);
      expect(result.hasExclusions, isFalse);
    });

    test('★★解決領域は ownerId で絞る (4.14.1)★★', () {
      // 解決領域は両プレイヤー共有で 1 つだけ。後攻パフォーマンス時には
      // 先攻のエールカードが残ったままなので、絞り込みが必須になる。
      final state = _state(resolution: [
        _on('L-bhPink1', ownerId: 'A'),
        _on('L-bhPink1', ownerId: 'B'),
        _on('L-bhPink1', ownerId: 'B'),
      ]);

      expect(aggregator.ownedHearts(state, 'A').hearts, {HeartColor.pink: 1});
      expect(aggregator.ownedHearts(state, 'B').hearts, {HeartColor.pink: 2});
    });

    test('★★同じ解決領域でも 8.3.12.1 は絞らず 8.3.14 は絞る★★', () {
      // 条文の書き分けをそのまま固定する。
      //   8.3.12  解決領域に置かれている「すべてのカード」
      //   8.3.14  解決領域の「自分の」カード
      final state = _state(resolution: [
        _on('L-drawOnly', ownerId: 'A'),
        _on('L-drawOnly', ownerId: 'B'),
        _on('L-bhPink1', ownerId: 'B'),
      ]);

      // ドローは所有者を問わず 2 枚分。
      expect(aggregator.yellDrawCount(state).count, 2);
      // ハートは自分の分だけ。
      expect(aggregator.ownedHearts(state, 'A').hearts, isEmpty);
      expect(aggregator.ownedHearts(state, 'B').hearts, {HeartColor.pink: 1});
    });

    test('★bladeHeartEffects はハートに合算しない', () {
      final state = _state(resolution: [_on('L-drawOnly', ownerId: 'A')]);
      final result = aggregator.ownedHearts(state, 'A');
      expect(result.hearts, isEmpty);
      expect(result.total, 0);
      // 同じカードがドロー側では数えられる。
      expect(aggregator.yellDrawCount(state).count, 1);
    });

    test('★ALL と GRAY を色に変換せずそのまま保持する (2.1.1.2 / 2.1.1.3)', () {
      // ALL をどの色として扱うかは 8.3.15.1.1 で決まる。
      // その解決は決定 D18 により手動なので、集計側で潰してはいけない。
      final state = _state(resolution: [
        _on('L-bhAll1', ownerId: 'A'),
        _on('L-bhGray2', ownerId: 'A'),
        _on('L-bhPink1', ownerId: 'A'),
      ]);

      final result = aggregator.ownedHearts(state, 'A');
      expect(result.hearts, {
        HeartColor.all: 1,
        HeartColor.gray: 2,
        HeartColor.pink: 1,
      });
      expect(result.total, 4);
    });

    test('メンバーのハートと解決領域のブレードハートを同じ色で合算する', () {
      // 2.1.3: ブレードハートのハートアイコンはブレードアイコンが無いものと
      //        同じハートアイコンを意味する。
      final state = _state(
        aMemberAreas: [
          _area(MemberAreaSlot.center, [
            MemberStack(member: _on('M-pink2', orientation: CardOrientation.active)),
          ]),
        ],
        resolution: [_on('L-bhPink1', ownerId: 'A')],
      );

      expect(aggregator.ownedHearts(state, 'A').hearts, {HeartColor.pink: 3});
    });

    test('★未知の cardNumber は例外を投げず除外して記録する', () {
      final state = _state(
        aMemberAreas: [
          _area(MemberAreaSlot.center, [
            MemberStack(member: _on('M-unknown', orientation: CardOrientation.active)),
          ]),
        ],
        resolution: [_on('L-unknown', ownerId: 'A')],
      );

      final result = aggregator.ownedHearts(state, 'A');
      expect(result.hearts, isEmpty);
      expect(result.excludedCount, 2);
      expect(result.unknownCardNumbers, ['L-unknown', 'M-unknown']);
    });
  });

  // -------------------------------------------------------------------------
  group('8.4.2 スコア合計', () {
    final aggregator = LiveAggregator(cards: {
      'L-score3': _live('L-score3', score: 3),
      'L-score5': _live('L-score5', score: 5),
      'L-score0': _live('L-score0'), // ★スコア 0 のライブ (Cheer Mode 相当)
      'L-icon1':
          _live('L-icon1', bladeHeartEffects: {BladeHeartEffect.score: 1}),
      'L-draw1': _live('L-draw1', bladeHeartEffects: {BladeHeartEffect.draw: 1}),
      'M-plain': _member('M-plain', bladeCount: 1),
    });

    test('ライブカード置き場のスコアを合計する', () {
      final state = _state(aLiveStage: [_on('L-score3'), _on('L-score5')]);
      final result = aggregator.scoreTotal(state, 'A');
      expect(result.total, 8);
      expect(result.hasLiveCards, isTrue);
    });

    test('★★ライブカード置き場が空なら null。0 ではない (8.4.2 / 8.4.3.2)★★', () {
      // 8.4.2 はスコアを合計する対象を「カードがあるプレイヤー」に限る。
      // 8.4.3.2 は片方だけカードがある場合そちらが大と定めるため、
      // 空を 0 で代用すると比較が壊れる。
      final state = _state();
      final result = aggregator.scoreTotal(state, 'A');
      expect(result.total, isNull);
      expect(result.hasLiveCards, isFalse);
    });

    test('★★スコア 0 のライブがあっても null にはならない★★', () {
      // スコア 0 のライブは実在する (PL!N-bp7-030 Cheer Mode)。
      // 「空 = 0」で実装すると、この盤面と空の盤面が区別できなくなり
      // 8.4.3.2 の比較が誤る。
      final state = _state(aLiveStage: [_on('L-score0')]);
      final result = aggregator.scoreTotal(state, 'A');

      expect(result.total, 0);
      expect(result.hasLiveCards, isTrue, reason: '空とは区別されなければならない');

      // 空のプレイヤーとは別物。
      expect(aggregator.scoreTotal(state, 'B').total, isNull);
    });

    test('★8.4.2.1 で自分のスコアアイコン 1 つにつき +1', () {
      final state = _state(
        aLiveStage: [_on('L-score3')],
        resolution: [_on('L-icon1', ownerId: 'A'), _on('L-icon1', ownerId: 'A')],
      );
      expect(aggregator.scoreTotal(state, 'A').total, 5);
    });

    test('★★相手のスコアアイコンは加算しない (8.4.2.1 は自身のエール)★★', () {
      // 8.3.12.1 が解決領域を絞らないのと対照的。
      final state = _state(
        aLiveStage: [_on('L-score3')],
        bLiveStage: [_on('L-score3')],
        resolution: [
          _on('L-icon1', ownerId: 'A'),
          _on('L-icon1', ownerId: 'B'),
          _on('L-icon1', ownerId: 'B'),
        ],
      );

      expect(aggregator.scoreTotal(state, 'A').total, 4);
      expect(aggregator.scoreTotal(state, 'B').total, 5);
    });

    test('★ドローアイコンはスコアに加算しない', () {
      final state = _state(
        aLiveStage: [_on('L-score3')],
        resolution: [_on('L-draw1', ownerId: 'A')],
      );
      expect(aggregator.scoreTotal(state, 'A').total, 3);
      // 同じカードがドロー側では数えられる。
      expect(aggregator.yellDrawCount(state).count, 1);
    });

    test('score が null のカードは 0 として扱う', () {
      // 8.2.2 のブラフで置かれたカードは 8.3.4 で控え室へ送られるため
      // 8.4.2 の時点では残らないが、型としては混ざりうる。
      final state = _state(aLiveStage: [_on('L-score3'), _on('M-plain')]);
      final result = aggregator.scoreTotal(state, 'A');
      expect(result.total, 3);
      expect(result.hasExclusions, isFalse, reason: '未知カードではない');
    });

    test('★未知の cardNumber は例外を投げず除外して記録する', () {
      final state = _state(
        aLiveStage: [_on('L-score3'), _on('L-unknown')],
        resolution: [_on('L-unknown', ownerId: 'A')],
      );

      final result = aggregator.scoreTotal(state, 'A');
      expect(result.total, 3, reason: '読めた分だけ合計する');
      expect(result.hasLiveCards, isTrue, reason: '置き場にカードはある');
      expect(result.excludedCount, 2);
      expect(result.unknownCardNumbers, ['L-unknown']);
    });

    test('★ライブ成功判定は行わない (決定 D18)', () {
      // 8.4.3 の比較手順・8.4.6 の勝者決定・8.4.7 の移動は集計側で行わない。
      // 出すのは数値だけ。
      final state = _state(
        aLiveStage: [_on('L-score5')],
        bLiveStage: [_on('L-score3')],
      );

      expect(aggregator.scoreTotal(state, 'A').total, 5);
      expect(aggregator.scoreTotal(state, 'B').total, 3);
      // 勝敗は LiveJudgementRecord に手動で入る。集計は関与しない。
      expect(state.liveJudgement, isNull);
    });
  });
}
