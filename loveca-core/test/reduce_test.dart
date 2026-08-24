// ★このテストだけ dart:io を使う。ソースを読んで seed が混入していないことを
//   固定するため。禁止対象は `loveca-core/lib` であってテストではない
//   （CLAUDE.md §1 の検証コマンドも lib を対象にしている）。
import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type, {int? blade}) => Card(
      cardNumber: number,
      name: number,
      cardType: type,
      bladeCount: blade,
      score: type == CardType.live ? 3 : null,
    );

final _master = <String, Card>{
  'M1': _card('M1', CardType.member, blade: 2),
  'E1': _card('E1', CardType.energy),
  'L1': _card('L1', CardType.live),
};

ReduceContext _ctx([int seed = 42]) =>
    ReduceContext(cards: _master, rng: SeededRng(seed));

var _seq = 0;
CardInstance _on(
  String cardNumber, {
  String ownerId = 'A',
  String? id,
  FaceState face = FaceState.faceUp,
  CardOrientation? orientation,
}) =>
    CardInstance(
      instanceId: id ?? 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
      face: face,
      orientation: orientation,
    );

List<CardInstance> _cards(String n, int count, {String prefix = 'c'}) =>
    [for (var i = 0; i < count; i++) _on(n, id: '$prefix$i')];

String _fingerprint(GameState state) {
  String card(CardInstance c) =>
      '${c.instanceId}|${c.cardNumber}|${c.orientation}|${c.face}';
  final b = StringBuffer('t${state.turnNumber}|${state.cursor}|'
      '${state.firstPlayerId}|res:${state.resolution.map(card).join(",")}');
  for (final p in state.players) {
    for (final zone in Zone.values) {
      if (zone == Zone.resolution ||
          zone == Zone.memberArea ||
          zone == Zone.stage) {
        continue;
      }
      b.write('\n${p.playerId}.${zone.name}:'
          '${cardsIn(state, p.playerId, zone).map(card).join(",")}');
    }
    for (final area in p.memberAreas) {
      b.write('\n${p.playerId}.${area.slot.name}:'
          '${area.stacks.map((s) => "${card(s.member)}[${s.beneath.map(card).join(";")}]").join(",")}'
          '/${area.orphans.map(card).join(",")}');
    }
  }
  return b.toString();
}

GameState _state({
  List<CardInstance> hand = const [],
  List<CardInstance> mainDeck = const [],
  List<CardInstance> waitingRoom = const [],
  List<CardInstance> energyField = const [],
  List<CardInstance> liveStage = const [],
  List<MemberArea> areas = const [],
  PhaseId phase = PhaseId.firstMain,
  StepId step = StepId.s7_7_2,
}) =>
    GameState(
      players: [
        PlayerState(
          playerId: 'A',
          hand: hand,
          mainDeck: mainDeck,
          waitingRoom: waitingRoom,
          energyField: energyField,
          liveStage: liveStage,
          memberAreas: areas,
        ),
        const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: 'A',
      cursor: StepCursor(phase, step),
    );

void main() {
  group('★イミュータビリティ', () {
    test('reduce は入力の GameState を変更しない', () {
      final state = _state(hand: _cards('M1', 3), mainDeck: _cards('M1', 5));
      final before = _fingerprint(state);

      reduce(
        state,
        const MoveCard(
          instanceId: 'c0',
          fromPlayerId: 'A',
          from: Zone.hand,
          toPlayerId: 'A',
          to: Zone.waitingRoom,
        ),
        context: _ctx(),
      );
      reduce(state, const DrawCards(playerId: 'A', count: 2), context: _ctx());
      reduce(state, const Tidy(), context: _ctx());

      expect(_fingerprint(state), before);
    });

    test('変更していない領域は参照を共有する（構造共有）', () {
      final state = _state(hand: _cards('M1', 2), mainDeck: _cards('M1', 5));
      final next = reduce(
        state,
        const FlipCard(
          instanceId: 'c0',
          playerId: 'A',
          zone: Zone.hand,
          face: FaceState.faceDown,
        ),
        context: _ctx(),
      );

      expect(
        identical(cardsIn(state, 'A', Zone.mainDeck),
            cardsIn(next, 'A', Zone.mainDeck)),
        isTrue,
      );
    });
  });

  group('★★リプレイ再現性★★', () {
    List<GameAction> actions() => const [
          ShuffleZone(playerId: 'A', zone: Zone.mainDeck),
          DrawCards(playerId: 'A', count: 3),
          ShuffleZone(playerId: 'A', zone: Zone.hand),
          DrawCards(playerId: 'A', count: 8), // ★途中でリフレッシュが割り込む
          Tidy(),
          AdvanceStep(),
        ];

    GameState run(int seed) {
      var state = _state(
        mainDeck: _cards('M1', 5, prefix: 'd'),
        waitingRoom: _cards('M1', 6, prefix: 'w'),
      );
      final ctx = _ctx(seed);
      for (final action in actions()) {
        state = reduce(state, action, context: ctx);
      }
      return state;
    }

    test('同一 seed・同一アクション列は同一の GameState に到達する', () {
      expect(_fingerprint(run(42)), _fingerprint(run(42)));
    });

    test('seed が違えば結果が変わる（乱数が実際に効いている）', () {
      expect(_fingerprint(run(1)), isNot(_fingerprint(run(2))));
    });

    test('★参照透過ではない — 同じ rng で 2 回呼ぶと結果が違う', () {
      // これは設計上の必然。乱数を GameAction の外から注入するため。
      // リプレイは SeededRng を張り直すことで再現する。
      final state = _state(mainDeck: _cards('M1', 10, prefix: 'd'));
      final ctx = _ctx(7);
      const shuffle = ShuffleZone(playerId: 'A', zone: Zone.mainDeck);

      final first = reduce(state, shuffle, context: ctx);
      final second = reduce(state, shuffle, context: ctx);
      expect(_fingerprint(first), isNot(_fingerprint(second)));
    });

    test('乱数を消費しないアクションは同じ rng でも同じ結果', () {
      final state = _state(hand: _cards('M1', 2));
      final ctx = _ctx(7);
      const flip = FlipCard(
        instanceId: 'c0',
        playerId: 'A',
        zone: Zone.hand,
        face: FaceState.faceDown,
      );
      expect(
        _fingerprint(reduce(state, flip, context: ctx)),
        _fingerprint(reduce(state, flip, context: ctx)),
      );
    });
  });

  group('★GameState / GameAction に RNG seed が含まれない', () {
    test('ソース上に Rng / seed の識別子が無い', () {
      for (final path in const [
        'lib/src/game/game_state.dart',
        'lib/src/game/game_action.dart',
      ]) {
        final source = File(path).readAsStringSync();
        // doc コメントでは言及してよいので、コメント行を除いて検査する。
        final code = source
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

        expect(code.contains('Rng'), isFalse, reason: '$path に Rng が混入している');
        expect(RegExp(r'\bseed\b').hasMatch(code), isFalse,
            reason: '$path に seed が混入している');
      }
    });

    test('seed を持つのは ReduceContext だけ', () {
      final ctx = _ctx(99);
      expect(ctx.rng, isA<SeededRng>());
      expect((ctx.rng as SeededRng).seed, 99);
    });
  });

  group('物理操作 (D-A)', () {
    test('MoveCard — 領域間の移動 (5.4.1)', () {
      final state = _state(hand: _cards('M1', 2));
      final next = reduce(
        state,
        const MoveCard(
          instanceId: 'c0',
          fromPlayerId: 'A',
          from: Zone.hand,
          toPlayerId: 'A',
          to: Zone.waitingRoom,
        ),
        context: _ctx(),
      );

      expect(cardsIn(next, 'A', Zone.hand).length, 1);
      expect(cardsIn(next, 'A', Zone.waitingRoom).single.instanceId, 'c0');
    });

    test('MoveCard — 存在しない instanceId は例外', () {
      expect(
        () => reduce(
          _state(),
          const MoveCard(
            instanceId: 'nope',
            fromPlayerId: 'A',
            from: Zone.hand,
            toPlayerId: 'A',
            to: Zone.waitingRoom,
          ),
          context: _ctx(),
        ),
        throwsArgumentError,
      );
    });

    test('MoveToResolution / MoveFromResolution (4.14.1)', () {
      final state = _state(hand: _cards('M1', 1));
      var next = reduce(
        state,
        const MoveToResolution(
            instanceId: 'c0', fromPlayerId: 'A', from: Zone.hand),
        context: _ctx(),
      );
      expect(next.resolution.single.instanceId, 'c0');
      expect(next.resolution.single.face, FaceState.faceUp, reason: '4.14.2 公開領域');

      next = reduce(
        next,
        const MoveFromResolution(
            instanceId: 'c0', toPlayerId: 'A', to: Zone.waitingRoom),
        context: _ctx(),
      );
      expect(next.resolution, isEmpty);
      expect(cardsIn(next, 'A', Zone.waitingRoom).length, 1);
    });

    test('★MoveOutOfRule — 6.2.1.6 の脇置きへ、そして戻す', () {
      final state = _state(hand: _cards('M1', 1));
      var next = reduce(
        state,
        const MoveOutOfRule(
          instanceId: 'c0',
          playerId: 'A',
          from: Zone.hand,
          to: OutOfRuleZone.mulliganAside,
        ),
        context: _ctx(),
      );
      expect(cardsInOutOfRule(next, 'A', OutOfRuleZone.mulliganAside).length, 1);
      expect(cardsIn(next, 'A', Zone.hand), isEmpty);

      next = reduce(
        next,
        const MoveFromOutOfRule(
          instanceId: 'c0',
          playerId: 'A',
          from: OutOfRuleZone.mulliganAside,
          to: Zone.mainDeck,
          position: ZonePosition.bottom,
        ),
        context: _ctx(),
      );
      expect(cardsIn(next, 'A', Zone.mainDeck).length, 1);
      expect(cardsInOutOfRule(next, 'A', OutOfRuleZone.mulliganAside), isEmpty);
    });

    test('FlipCard / SetOrientation (5.3.1 / 5.2.1)', () {
      final state = _state(
        hand: _cards('M1', 1),
        energyField: [_on('E1', id: 'e0', orientation: CardOrientation.active)],
      );

      final flipped = reduce(
        state,
        const FlipCard(
            instanceId: 'c0',
            playerId: 'A',
            zone: Zone.hand,
            face: FaceState.faceDown),
        context: _ctx(),
      );
      expect(cardsIn(flipped, 'A', Zone.hand).single.face, FaceState.faceDown);

      // 5.9.1: コストの支払いはウェイトにするだけで領域を移動しない。
      final waited = reduce(
        state,
        const SetOrientation(
          instanceId: 'e0',
          playerId: 'A',
          zone: Zone.energyField,
          orientation: CardOrientation.wait,
        ),
        context: _ctx(),
      );
      expect(cardsIn(waited, 'A', Zone.energyField).single.orientation,
          CardOrientation.wait);
      expect(cardsIn(waited, 'A', Zone.energyField).length, 1);
    });

    test('ShuffleZone — 枚数と要素は保存される (5.5.1)', () {
      final state = _state(mainDeck: _cards('M1', 10, prefix: 'd'));
      final next = reduce(
        state,
        const ShuffleZone(playerId: 'A', zone: Zone.mainDeck),
        context: _ctx(),
      );

      final before =
          cardsIn(state, 'A', Zone.mainDeck).map((c) => c.instanceId).toSet();
      final after =
          cardsIn(next, 'A', Zone.mainDeck).map((c) => c.instanceId).toSet();
      expect(after, before);
    });

    test('★DrawCards — 途中でリフレッシュが割り込む (10.2.1)', () {
      final state = _state(
        mainDeck: _cards('M1', 2, prefix: 'd'),
        waitingRoom: _cards('M1', 4, prefix: 'w'),
      );
      final report = reduceWithReport(
          state, const DrawCards(playerId: 'A', count: 5), context: _ctx());

      expect(cardsIn(report.state, 'A', Zone.hand).length, 5);
      expect(report.refreshCount, 1);
      expect(cardsIn(report.state, 'A', Zone.waitingRoom), isEmpty);
    });

    test('★LookAtTop — 盤面は変わらないが 10.2.2.2 でリフレッシュする', () {
      // 足りているときは何も起きない。
      final enough = _state(mainDeck: _cards('M1', 5, prefix: 'd'));
      final same = reduceWithReport(
          enough, const LookAtTop(playerId: 'A', count: 3), context: _ctx());
      expect(_fingerprint(same.state), _fingerprint(enough));
      expect(same.refreshCount, 0);

      // 足りないときはリフレッシュだけ行う。
      final short = _state(
        mainDeck: _cards('M1', 1, prefix: 'd'),
        waitingRoom: _cards('M1', 4, prefix: 'w'),
      );
      final refreshed = reduceWithReport(
          short, const LookAtTop(playerId: 'A', count: 3), context: _ctx());
      expect(refreshed.refreshCount, 1);
      expect(cardsIn(refreshed.state, 'A', Zone.mainDeck).length, 5);
    });
  });

  group('メンバーエリアの操作', () {
    test('PlaceMemberInArea — 末尾に積む（配置順の規約）', () {
      var state = _state(hand: _cards('M1', 2));
      final ctx = _ctx();

      state = reduce(
        state,
        const PlaceMemberInArea(
            instanceId: 'c0',
            playerId: 'A',
            from: Zone.hand,
            slot: MemberAreaSlot.center),
        context: ctx,
      );
      state = reduce(
        state,
        const PlaceMemberInArea(
            instanceId: 'c1',
            playerId: 'A',
            from: Zone.hand,
            slot: MemberAreaSlot.center),
        context: ctx,
      );

      final area = state.players.first.memberAreas.single;
      expect(area.stacks.map((s) => s.member.instanceId).toList(), ['c0', 'c1']);
      expect(area.stacks.last.member.instanceId, 'c1',
          reason: '★末尾が 10.4.1 の「最も後から置かれたメンバー」');
      // 4.3.2.3: 既定はアクティブ状態。
      expect(area.stacks.first.member.orientation, CardOrientation.active);
    });

    test('★StackUnderMember — 下に重ねると向きを失う (4.5.5.2)', () {
      final state = _state(
        energyField: [_on('E1', id: 'e0', orientation: CardOrientation.active)],
        areas: [
          MemberArea(slot: MemberAreaSlot.center, stacks: [
            MemberStack(
              member: _on('M1', id: 'm0', orientation: CardOrientation.active),
            ),
          ]),
        ],
      );

      final next = reduce(
        state,
        const StackUnderMember(
          instanceId: 'e0',
          playerId: 'A',
          from: Zone.energyField,
          slot: MemberAreaSlot.center,
          memberInstanceId: 'm0',
        ),
        context: _ctx(),
      );

      final stack = next.players.first.memberAreas.single.stacks.single;
      expect(stack.beneath.single.instanceId, 'e0');
      expect(stack.beneath.single.orientation, isNull,
          reason: '★4.5.5.2 下のカードは向きを持たない');
      expect(cardsIn(next, 'A', Zone.energyField), isEmpty);
    });

    test('★★MoveMemberOut — 下のカードは孤児として残る (4.5.5.4)★★', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', id: 'm0', orientation: CardOrientation.active),
            beneath: [_on('E1', id: 'e0'), _on('M1', id: 'm1')],
          ),
        ]),
      ]);

      final next = reduce(
        state,
        const MoveMemberOut(
          instanceId: 'm0',
          playerId: 'A',
          slot: MemberAreaSlot.center,
          toPlayerId: 'A',
          to: Zone.waitingRoom,
        ),
        context: _ctx(),
      );

      final area = next.players.first.memberAreas.single;
      expect(area.stacks, isEmpty);
      // ★ここで控え室へ送ってはいけない。10.1.2 によりそれはチェックタイミング。
      expect(area.orphans.map((c) => c.instanceId).toList(), ['e0', 'm1']);
      expect(cardsIn(next, 'A', Zone.waitingRoom).map((c) => c.instanceId),
          ['m0']);
    });

    test('★MoveMemberBetweenAreas — スタックごと動く (4.5.5.3)', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', id: 'm0', orientation: CardOrientation.active),
            beneath: [_on('E1', id: 'e0')],
          ),
        ]),
      ]);

      final next = reduce(
        state,
        const MoveMemberBetweenAreas(
          instanceId: 'm0',
          playerId: 'A',
          fromSlot: MemberAreaSlot.center,
          toSlot: MemberAreaSlot.leftSide,
        ),
        context: _ctx(),
      );

      final areas = next.players.first.memberAreas;
      final from = areas.firstWhere((a) => a.slot == MemberAreaSlot.center);
      final to = areas.firstWhere((a) => a.slot == MemberAreaSlot.leftSide);

      expect(from.stacks, isEmpty);
      expect(from.orphans, isEmpty, reason: '★解消は起きない');
      expect(to.stacks.single.beneath.single.instanceId, 'e0',
          reason: '★下のカードも重なったまま移動する');
    });

    test('DetachFromMember — 孤児化する', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', id: 'm0', orientation: CardOrientation.active),
            beneath: [_on('E1', id: 'e0')],
          ),
        ]),
      ]);

      final next = reduce(
        state,
        const DetachFromMember(
            instanceId: 'e0', playerId: 'A', slot: MemberAreaSlot.center),
        context: _ctx(),
      );

      final area = next.players.first.memberAreas.single;
      expect(area.stacks.single.beneath, isEmpty);
      expect(area.orphans.single.instanceId, 'e0');
    });
  });

  group('進行・ルール処理', () {
    test('AdvanceStep — step_engine を呼ぶ', () {
      final state = _state(phase: PhaseId.firstActive, step: StepId.s7_4_1);
      final report =
          reduceWithReport(state, const AdvanceStep(), context: _ctx());

      expect(report.state.cursor.step, StepId.s7_4_2);
      expect(report.advance, isNotNull);
      expect(report.advance!.executed, StepId.s7_4_1);
    });

    test('★SetLiveJudgement → AdvanceStep で 8.4.13 の入れ替えが起きる', () {
      // 8.4.13 は独立アクションにしない。firstPlayerId を書き換えるのは
      // 8.4.13 の 1 箇所という不変条件を保つため。
      var state = _state(phase: PhaseId.liveJudgement, step: StepId.s8_4_13)
          .copyWith(firstPlayerId: 'B');

      state = reduce(
        state,
        const SetLiveJudgement(LiveJudgementRecord(
          winnerIds: {'A', 'B'},
          movedToSuccessIds: {'A'},
        )),
        context: _ctx(),
      );
      expect(state.firstPlayerId, 'B', reason: '記録を置くだけでは入れ替わらない');

      state = reduce(state, const AdvanceStep(), context: _ctx());
      expect(state.firstPlayerId, 'A',
          reason: '★8.4.7 の移動実績を見て 8.4.13 が入れ替える');
    });

    test('Tidy — 整理の結果と警告が返る', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('E1', id: 'e0')]),
      ]);
      final report = reduceWithReport(state, const Tidy(), context: _ctx());

      expect(report.tidy, isNotNull);
      expect(report.tidy!.applied, contains(RuleProcessKind.orphanEnergy));
      // 10.5.4 / 10.5.5: エネルギーデッキ置き場へ。控え室を経由しない。
      expect(cardsIn(report.state, 'A', Zone.energyDeck).length, 1);
    });

    test('★reduce だけでは 10.3 / 10.6 の警告が拾えないので reduceWithReport を使う', () {
      final state = _state().copyWith(resolution: [_on('M1', id: 'r0')]);

      // reduce は GameState しか返さない。
      expect(reduce(state, const Tidy(), context: _ctx()).resolution.length, 1);

      // 警告はこちらで拾う。
      final report = reduceWithReport(state, const Tidy(), context: _ctx());
      expect(report.tidy!.warnings,
          contains(RuleProcessWarningKind.invalidResolution));
    });

    test('Refresh — playerId 省略で 10.2.4 の順に全員', () {
      final state = _state(waitingRoom: _cards('M1', 3, prefix: 'w'));
      final next = reduce(state, const Refresh(), context: _ctx());

      expect(cardsIn(next, 'A', Zone.mainDeck).length, 3);
      expect(cardsIn(next, 'A', Zone.waitingRoom), isEmpty);
    });
  });

  group('★GameSession.apply — reduce と履歴の接続', () {
    test('apply したあと undoStep で戻せる', () {
      final session = GameSession(
        state: _state(phase: PhaseId.firstActive, step: StepId.s7_4_1),
      );
      final ctx = _ctx();

      final advanced = session.apply(const AdvanceStep(), context: ctx);
      expect(advanced.state.cursor.step, StepId.s7_4_2);

      final back = advanced.undoStep()!;
      expect(back.state.cursor.step, StepId.s7_4_1);
    });

    test('★undo / undoStep は GameAction ではなく GameSession 層にある', () {
      // 権威サーバでは他プレイヤーの観測を巻き戻せないので undo は成立せず、
      // GameState に履歴を持たせると Phase 6 の負債になる（決定 D36）。
      final session = GameSession(state: _state(hand: _cards('M1', 2)));
      final ctx = _ctx();

      final moved = session.apply(
        const MoveCard(
          instanceId: 'c0',
          fromPlayerId: 'A',
          from: Zone.hand,
          toPlayerId: 'A',
          to: Zone.waitingRoom,
        ),
        context: ctx,
      );
      expect(cardsIn(moved.state, 'A', Zone.hand).length, 1);
      expect(cardsIn(moved.undo()!.state, 'A', Zone.hand).length, 2);
    });
  });
}
