import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type, {int? blade}) => Card(
      cardNumber: number,
      name: number,
      cardType: type,
      bladeCount: blade,
      score: type == CardType.live ? 1 : null,
    );

final _master = <String, Card>{
  'M1': _card('M1', CardType.member, blade: 1),
  'M2': _card('M2', CardType.member, blade: 2),
  'E1': _card('E1', CardType.energy),
  'L1': _card('L1', CardType.live),
};

var _seq = 0;
CardInstance _on(
  String cardNumber, {
  CardOrientation? orientation,
  FaceState face = FaceState.faceUp,
  String ownerId = 'A',
}) =>
    CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
      orientation: orientation,
      face: face,
    );

List<CardInstance> _cards(String number, int count, {String ownerId = 'A'}) =>
    [for (var i = 0; i < count; i++) _on(number, ownerId: ownerId)];

final _engine = StepEngine(cards: _master, rng: SeededRng(1));

GameState _at(
  PhaseId phase,
  StepId step, {
  PlayerState? a,
  PlayerState? b,
  String firstPlayerId = 'A',
  List<CardInstance> resolution = const [],
  LiveJudgementRecord? liveJudgement,
  int turnNumber = 1,
}) =>
    GameState(
      players: [
        a ?? const PlayerState(playerId: 'A'),
        b ?? const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: firstPlayerId,
      cursor: StepCursor(phase, step),
      resolution: resolution,
      liveJudgement: liveJudgement,
      turnNumber: turnNumber,
    );

void main() {
  group('遷移テーブルが唯一の権威', () {
    test('単一候補のステップはそのまま進む', () {
      final result = _engine.advance(_at(PhaseId.firstActive, StepId.s7_4_1));
      expect(result.executed, StepId.s7_4_1);
      expect(result.state.cursor.step, StepId.s7_4_2);
      expect(result.state.cursor.phase, PhaseId.firstActive);
    });

    test('★フェイズ終了で次フェイズの先頭ステップへ (7.3.3)', () {
      final result = _engine.advance(_at(PhaseId.firstActive, StepId.s7_4_3));
      expect(result.taken.endsPhase, isTrue);
      expect(result.state.cursor,
          const StepCursor(PhaseId.firstEnergy, StepId.s7_5_1));
    });

    test('12 フェイズを巡回して次のターンへ戻る', () {
      // 各フェイズの終端まで一気に飛ばし、フェイズ境界だけを確認する。
      var state = _at(PhaseId.firstActive, StepId.s7_4_1);
      final visited = <PhaseId>[state.cursor.phase];

      for (var i = 0; i < 11; i++) {
        final phase = state.cursor.phase;
        state = state.copyWith(
          cursor: StepCursor(phase, phase.steps.last),
        );
        state = _engine.advance(state).state;
        visited.add(state.cursor.phase);
      }

      expect(visited, phaseCycle);
    });
  });

  group('★7.4 だけ誘発より前にアクティブ化が来る', () {
    test('7.4.1 (アクティブ化) が 7.4.2 (誘発) より先', () {
      // 7.4.1「手番プレイヤーは、自身のエネルギー置き場とメンバーエリアの
      //        ウェイトのカードをすべてアクティブにします」
      // 7.4.2「'ターンの始めに'および'アクティブフェイズの始めに'の誘発条件が発生します」
      //
      // 7.5 / 7.6 / 7.7 はいずれも誘発が先頭。ここを揃えると 7.4 で順序が狂う。
      final steps = PhaseId.firstActive.steps;
      expect(steps.first, StepId.s7_4_1);
      expect(steps[1], StepId.s7_4_2);

      // 他の 3 フェイズは誘発 (X.1) が先頭。
      expect(PhaseId.firstEnergy.steps.first, StepId.s7_5_1);
      expect(PhaseId.firstDraw.steps.first, StepId.s7_6_1);
      expect(PhaseId.firstMain.steps.first, StepId.s7_7_1);

      // ★7.4.1 にはチェックタイミングが無く、7.5.1 / 7.6.1 / 7.7.1 にはある。
      expect(StepId.s7_4_1.checkTiming, isFalse);
      expect(StepId.s7_5_1.checkTiming, isTrue);
      expect(StepId.s7_6_1.checkTiming, isTrue);
      expect(StepId.s7_7_1.checkTiming, isTrue);
    });

    test('7.4.1 でウェイトのカードがアクティブになる', () {
      final state = _at(
        PhaseId.firstActive,
        StepId.s7_4_1,
        a: PlayerState(
          playerId: 'A',
          energyField: [_on('E1', orientation: CardOrientation.wait)],
          memberAreas: [
            MemberArea(slot: MemberAreaSlot.center, stacks: [
              MemberStack(
                member: _on('M1', orientation: CardOrientation.wait),
                beneath: [_on('E1')],
              ),
            ]),
          ],
        ),
      );

      final after = _engine.advance(state).state;
      expect(cardsIn(after, 'A', Zone.energyField).single.orientation,
          CardOrientation.active);

      final stack = after.players.first.memberAreas.first.stacks.single;
      expect(stack.member.orientation, CardOrientation.active);
      // ★下のカードは向きを持たない (4.5.5.2)。触らない。
      expect(stack.beneath.single.orientation, isNull);
    });
  });

  group('★7.7 に終了時チェックタイミングが無い (9.5.4.3 で閉じる)', () {
    test('7.7.3 だけ他の通常フェイズの終端と非対称', () {
      expect(StepId.s7_4_3.checkTiming, isTrue);
      expect(StepId.s7_5_3.checkTiming, isTrue);
      expect(StepId.s7_6_3.checkTiming, isTrue);
      // ★ここに CT を足さないこと。
      expect(StepId.s7_7_3.checkTiming, isFalse);
    });

    test('7.7.3 の advance では整理が走らない', () {
      final result = _engine.advance(_at(PhaseId.firstMain, StepId.s7_7_3));
      expect(result.tidy, isNull, reason: '★CT が無いので整理も走らない');
      expect(result.state.cursor.phase, PhaseId.secondActive);
    });

    test('7.6.3 の advance では整理が走る', () {
      final result = _engine.advance(_at(PhaseId.firstDraw, StepId.s7_6_3));
      expect(result.tidy, isNotNull);
    });
  });

  group('★8.3.6 の早期終了', () {
    test('★★ライブカード置き場が空ならフェイズ終了。8.3.17 の CT を通らない★★', () {
      // 8.3.6 で終了した場合、8.3.7〜8.3.17 を丸ごと飛ばす。
      // 11.5.2.1 により「ライブ開始時」(8.3.8) の事象も発生しない。
      // 8.3.17 へジャンプさせると 8.3.17 の CT が余分に走る。
      final state = _at(PhaseId.firstPerformance, StepId.s8_3_6);
      final result = _engine.advance(state);

      expect(result.taken.endsPhase, isTrue);
      expect(result.taken.target, isNull);
      expect(result.taken.target, isNot(StepId.s8_3_17));

      // 次は後攻パフォーマンスフェイズの先頭 (8.3.3)。
      expect(result.state.cursor,
          const StepCursor(PhaseId.secondPerformance, StepId.s8_3_3));

      // 8.3.6 自身には CT が無いので整理も走らない。
      expect(StepId.s8_3_6.checkTiming, isFalse);
      expect(result.tidy, isNull);
    });

    test('ライブカードがあれば 8.3.7 へ進む', () {
      final state = _at(
        PhaseId.firstPerformance,
        StepId.s8_3_6,
        a: PlayerState(playerId: 'A', liveStage: [_on('L1')]),
      );
      final result = _engine.advance(state);

      expect(result.state.cursor.step, StepId.s8_3_7);
      expect(result.state.cursor.phase, PhaseId.firstPerformance);
    });

    test('★手番プレイヤーのライブカード置き場を見る', () {
      // 後攻パフォーマンスフェイズでは B の置き場を見る。
      final state = _at(
        PhaseId.secondPerformance,
        StepId.s8_3_6,
        a: PlayerState(playerId: 'A', liveStage: [_on('L1')]),
      );
      // B は空なので早期終了する。
      expect(_engine.advance(state).taken.endsPhase, isTrue);
    });

    test('8.3.6 は自動判定なので choice が要らない', () {
      final state = _at(PhaseId.firstPerformance, StepId.s8_3_6);
      expect(_engine.requiresChoice(state), isFalse);
      expect(StepId.s8_3_6.decision, StepDecision.automatic);
    });
  });

  group('★8.4.12 の分岐はプレイヤーが宣言する', () {
    test('choice を渡さないと例外', () {
      final state = _at(PhaseId.liveJudgement, StepId.s8_4_12);
      expect(_engine.requiresChoice(state), isTrue);
      expect(() => _engine.advance(state), throwsArgumentError);
    });

    test('★8.4.9 へ戻るループを選べる', () {
      final state = _at(PhaseId.liveJudgement, StepId.s8_4_12);
      final loop = stepGraph[StepId.s8_4_12]!
          .firstWhere((t) => t.target == StepId.s8_4_9);

      final after = _engine.advance(state, choice: loop).state;
      expect(after.cursor,
          const StepCursor(PhaseId.liveJudgement, StepId.s8_4_9));
    });

    test('8.4.13 へ進むほうも選べる', () {
      final state = _at(PhaseId.liveJudgement, StepId.s8_4_12);
      final exit = stepGraph[StepId.s8_4_12]!
          .firstWhere((t) => t.target == StepId.s8_4_13);

      final after = _engine.advance(state, choice: exit).state;
      expect(after.cursor.step, StepId.s8_4_13);
    });
  });

  group('★8.4.13 先攻入れ替え', () {
    test('★★winnerIds が {A,B} でも movedToSuccessIds が {A} なら A が先攻★★', () {
      // 8.4.7.1 により「両者勝利かつライブ置き場に 2 枚あるプレイヤー」は
      // 移動しない。8.4.13 が参照するのは勝敗ではなく 8.4.7 の移動実績。
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_13,
        firstPlayerId: 'B',
        liveJudgement: const LiveJudgementRecord(
          winnerIds: {'A', 'B'},
          movedToSuccessIds: {'A'},
        ),
      );

      final after = _engine.advance(state).state;
      expect(after.firstPlayerId, 'A',
          reason: '★勝敗で判定すると「勝者が 1 人に定まらない」として据え置きと誤る');
    });

    test('両者が移動していれば現在の先攻が継続する', () {
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_13,
        firstPlayerId: 'B',
        liveJudgement: const LiveJudgementRecord(
          winnerIds: {'A', 'B'},
          movedToSuccessIds: {'A', 'B'},
        ),
      );
      expect(_engine.advance(state).state.firstPlayerId, 'B');
    });

    test('誰も移動していなければ継続する (8.4.6.1)', () {
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_13,
        firstPlayerId: 'A',
        liveJudgement: const LiveJudgementRecord(),
      );
      expect(_engine.advance(state).state.firstPlayerId, 'A');
    });

    test('★入れ替わると次ターンの手番が新しい先攻になる', () {
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_13,
        firstPlayerId: 'B',
        liveJudgement: const LiveJudgementRecord(
          movedToSuccessIds: {'A'},
        ),
      );
      final after = _engine.advance(state).state;

      // 次ターンの先攻通常フェイズの手番は A。
      expect(turnPlayerOf(after, PhaseId.firstActive), 'A');
      expect(turnPlayerOf(after, PhaseId.secondActive), 'B');
    });
  });

  group('8.4.14 ターン終了', () {
    test('turnNumber が進み、次は firstActive の先頭へ戻る', () {
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_14,
        turnNumber: 3,
        liveJudgement: const LiveJudgementRecord(movedToSuccessIds: {'A'}),
      );
      final result = _engine.advance(state);

      expect(result.state.turnNumber, 4);
      expect(result.state.cursor,
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
      expect(result.state.liveJudgement, isNull, reason: 'ターンを跨いで持ち越さない');
    });
  });

  group('★8.3.11 エール', () {
    test('8.3.10 の合計ブレード数だけ解決領域へ移す', () {
      final state = _at(
        PhaseId.firstPerformance,
        StepId.s8_3_11,
        a: PlayerState(
          playerId: 'A',
          mainDeck: _cards('M1', 5),
          memberAreas: [
            MemberArea(slot: MemberAreaSlot.center, stacks: [
              // M2 はブレード 2。
              MemberStack(
                  member: _on('M2', orientation: CardOrientation.active)),
            ]),
          ],
        ),
      );

      final after = _engine.advance(state).state;
      expect(after.resolution.length, 2);
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 3);
      // 4.14.2: 解決領域は公開領域。
      expect(after.resolution.every((c) => c.face == FaceState.faceUp), isTrue);
    });

    test('★★エール途中でデッキが尽きたらリフレッシュして続行する (10.2.1)★★', () {
      // メインデッキ 1 枚 / 控え室 4 枚 でブレード 2 のメンバーがエールする。
      final state = _at(
        PhaseId.firstPerformance,
        StepId.s8_3_11,
        a: PlayerState(
          playerId: 'A',
          mainDeck: _cards('M1', 1),
          waitingRoom: _cards('M1', 4),
          memberAreas: [
            MemberArea(slot: MemberAreaSlot.center, stacks: [
              MemberStack(
                  member: _on('M2', orientation: CardOrientation.active)),
            ]),
          ],
        ),
      );

      final result = _engine.advance(state);

      expect(result.refreshCount, 1, reason: '★途中で 1 回割り込む');
      expect(result.state.resolution.length, 2, reason: '★中断せず 2 枚取り切る');
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
      expect(cardsIn(result.state, 'A', Zone.mainDeck).length, 3);
    });

    test('★アクティブ状態のメンバーだけがブレードを出す (8.3.10)', () {
      final state = _at(
        PhaseId.firstPerformance,
        StepId.s8_3_11,
        a: PlayerState(
          playerId: 'A',
          mainDeck: _cards('M1', 5),
          memberAreas: [
            MemberArea(slot: MemberAreaSlot.center, stacks: [
              MemberStack(member: _on('M2', orientation: CardOrientation.wait)),
            ]),
          ],
        ),
      );
      // ウェイトなのでブレード 0。何も動かない。
      final after = _engine.advance(state).state;
      expect(after.resolution, isEmpty);
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 5);
    });
  });

  group('8.3.12 ドロー', () {
    test('★解決領域の全カードのドローアイコンを数える (所有者で絞らない)', () {
      final master = <String, Card>{
        ..._master,
        'LD': Card(
          cardNumber: 'LD',
          name: 'LD',
          cardType: CardType.live,
          bladeHeartEffects: const {BladeHeartEffect.draw: 1},
        ),
      };
      final engine = StepEngine(cards: master, rng: SeededRng(1));

      final state = _at(
        // ★後攻パフォーマンスフェイズ。解決領域に先攻のエールが残っている。
        PhaseId.secondPerformance,
        StepId.s8_3_12,
        b: PlayerState(playerId: 'B', mainDeck: _cards('M1', 5, ownerId: 'B')),
        resolution: [
          _on('LD', ownerId: 'A'), // 先攻のエール
          _on('LD', ownerId: 'B'), // 後攻のエール
        ],
      );

      final after = engine.advance(state).state;
      expect(cardsIn(after, 'B', Zone.hand).length, 2,
          reason: '★後攻 B は先攻 A のドローアイコン分も引く');
    });
  });

  group('7.5.2 / 7.6.2', () {
    test('7.5.2 エネルギーデッキの一番上をエネルギー置き場へ', () {
      final state = _at(
        PhaseId.firstEnergy,
        StepId.s7_5_2,
        a: PlayerState(playerId: 'A', energyDeck: _cards('E1', 3)),
      );
      final after = _engine.advance(state).state;

      expect(cardsIn(after, 'A', Zone.energyDeck).length, 2);
      // 4.7.3 / 4.3.2.3: 向きを持ち、既定はアクティブ。
      expect(cardsIn(after, 'A', Zone.energyField).single.orientation,
          CardOrientation.active);
    });

    test('7.6.2 カードを 1 枚引く', () {
      final state = _at(
        PhaseId.firstDraw,
        StepId.s7_6_2,
        a: PlayerState(playerId: 'A', mainDeck: _cards('M1', 3)),
      );
      final after = _engine.advance(state).state;

      expect(cardsIn(after, 'A', Zone.hand).length, 1);
      expect(cardsIn(after, 'A', Zone.mainDeck).length, 2);
    });
  });

  group('8.3.4 ライブカード置き場を表向きにする', () {
    test('ライブでないカードは控え室へ', () {
      final state = _at(
        PhaseId.firstPerformance,
        StepId.s8_3_4,
        a: PlayerState(playerId: 'A', liveStage: [
          _on('L1', face: FaceState.faceDown),
          _on('M1', face: FaceState.faceDown), // 8.2.2 のブラフ
        ]),
      );
      final after = _engine.advance(state).state;

      expect(cardsIn(after, 'A', Zone.liveStage).map((c) => c.cardNumber),
          ['L1']);
      expect(cardsIn(after, 'A', Zone.liveStage).single.face,
          FaceState.faceUp);
      expect(cardsIn(after, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          ['M1']);
    });
  });

  group('8.4.8 ライブ後の片付け', () {
    test('ライブ置き場の残りと解決領域をオーナーの控え室へ', () {
      final state = _at(
        PhaseId.liveJudgement,
        StepId.s8_4_8,
        a: PlayerState(playerId: 'A', liveStage: [_on('L1')]),
        b: PlayerState(
            playerId: 'B', liveStage: [_on('L1', ownerId: 'B')]),
        resolution: [_on('M1'), _on('M1', ownerId: 'B')],
      );
      final after = _engine.advance(state).state;

      expect(after.resolution, isEmpty);
      expect(cardsIn(after, 'A', Zone.liveStage), isEmpty);
      // ★解決領域は共有なので ownerId で振り分ける (4.14.1 / 4.1.7)。
      expect(cardsIn(after, 'A', Zone.waitingRoom).length, 2);
      expect(cardsIn(after, 'B', Zone.waitingRoom).length, 2);
    });
  });

  group('素通りするステップは盤面を触らない (D-A)', () {
    test('誘発ステップと手動ステップで領域が変わらない', () {
      final passThrough = [
        (PhaseId.firstActive, StepId.s7_4_2),
        (PhaseId.liveCardSet, StepId.s8_2_2),
        (PhaseId.liveCardSet, StepId.s8_2_4),
        (PhaseId.firstPerformance, StepId.s8_3_7),
        (PhaseId.firstPerformance, StepId.s8_3_8),
        (PhaseId.firstPerformance, StepId.s8_3_15),
        (PhaseId.firstPerformance, StepId.s8_3_16),
        (PhaseId.liveJudgement, StepId.s8_4_2),
        (PhaseId.liveJudgement, StepId.s8_4_6),
        (PhaseId.liveJudgement, StepId.s8_4_7),
      ];

      for (final (phase, step) in passThrough) {
        final before = _at(
          phase,
          step,
          a: PlayerState(
            playerId: 'A',
            hand: _cards('M1', 2),
            mainDeck: _cards('M1', 3),
            liveStage: [_on('L1')],
          ),
        );
        final after = _engine.advance(before).state;

        expect(cardsIn(after, 'A', Zone.hand).length, 2, reason: step.ruleRef);
        expect(cardsIn(after, 'A', Zone.mainDeck).length, 3,
            reason: step.ruleRef);
        expect(cardsIn(after, 'A', Zone.liveStage).length, 1,
            reason: step.ruleRef);
      }
    });
  });

  group('チェックタイミングで整理が走る (9.5.3.1)', () {
    test('CT ステップで孤児カードが片付く', () {
      final state = _at(
        PhaseId.firstActive,
        StepId.s7_4_3, // CT
        a: PlayerState(playerId: 'A', memberAreas: [
          MemberArea(slot: MemberAreaSlot.center, orphans: [_on('E1')]),
        ]),
      );
      final result = _engine.advance(state);

      expect(result.tidy, isNotNull);
      expect(result.tidy!.applied, contains(RuleProcessKind.orphanEnergy));
      // 10.5.4 / 10.5.5: エネルギーデッキ置き場へ。控え室を経由しない。
      expect(cardsIn(result.state, 'A', Zone.energyDeck).length, 1);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
    });
  });
}
