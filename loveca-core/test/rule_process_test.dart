import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type) =>
    Card(cardNumber: number, name: number, cardType: type);

final _master = <String, Card>{
  'M1': _card('M1', CardType.member),
  'M2': _card('M2', CardType.member),
  'M3': _card('M3', CardType.member),
  'E1': _card('E1', CardType.energy),
  'E2': _card('E2', CardType.energy),
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

GameState _state({
  List<MemberArea> areas = const [],
  List<CardInstance> liveStage = const [],
  List<CardInstance> energyField = const [],
  List<CardInstance> successLive = const [],
  List<CardInstance> resolution = const [],
}) =>
    GameState(
      players: [
        PlayerState(
          playerId: 'A',
          memberAreas: areas,
          liveStage: liveStage,
          energyField: energyField,
          successLive: successLive,
        ),
        const PlayerState(playerId: 'B'),
      ],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_1),
      resolution: resolution,
    );

void main() {
  const processor = RuleProcessor(cards: {});
  final full = RuleProcessor(cards: _master);

  group('10.5.3 / 10.5.4 上にメンバーが無いカード', () {
    test('10.5.3 メンバーカードは控え室へ', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('M1')]),
      ]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.orphanMember));
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).length, 1);
      expect(result.state.players.first.memberAreas.first.orphans, isEmpty);
    });

    test('★★10.5.4 エネルギーカードはエネルギーデッキ置き場へ。控え室を経由しない★★', () {
      // 10.5.5 を広義に読む。エネルギーカードは控え室を経由しない閉ループとして
      // 設計されており (4.9 / 4.7 / 5.9.1 / 10.5.4)、ルール処理で控え室へ行く
      // 経路は存在しない。
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('E1')]),
      ]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.orphanEnergy));
      expect(cardsIn(result.state, 'A', Zone.energyDeck).length, 1);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty,
          reason: '★控え室を経由してはいけない');
    });

    test('メンバーとエネルギーが混在すると行き先が分かれる', () {
      final state = _state(areas: [
        MemberArea(
          slot: MemberAreaSlot.center,
          orphans: [_on('M1'), _on('E1'), _on('M2')],
        ),
      ]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'A', Zone.waitingRoom).length, 2);
      expect(cardsIn(result.state, 'A', Zone.energyDeck).length, 1);
    });

    test('★行き先はオーナーの領域 (4.1.7)', () {
      // エリアは A のものだが、カードのオーナーは B。
      final state = _state(areas: [
        MemberArea(
          slot: MemberAreaSlot.center,
          orphans: [_on('M1', ownerId: 'B')],
        ),
      ]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'B', Zone.waitingRoom).length, 1);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
    });
  });

  group('10.4.1 重複メンバー処理', () {
    test('★★残すメンバーの beneath は維持される★★', () {
      // 10.4.1 の字面どおりなら「それ以外のカード」に残すメンバーの下の
      // スタックも含まれるが、4.5.5.3 との整合を優先して維持する。
      final survivorBeneath = [_on('E1'), _on('M3')];
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', orientation: CardOrientation.active),
            beneath: [_on('E2')],
          ),
          // ★リスト末尾 = 最も後から置かれたメンバー
          MemberStack(
            member: _on('M2', orientation: CardOrientation.active),
            beneath: survivorBeneath,
          ),
        ]),
      ]);

      final result = full.tidy(state);
      final area = result.state.players.first.memberAreas.first;

      expect(result.applied, contains(RuleProcessKind.duplicateMember));
      expect(area.stacks.length, 1);
      expect(area.stacks.single.member.cardNumber, 'M2',
          reason: '最も後から置かれたメンバーが残る');
      expect(area.stacks.single.beneath.map((c) => c.cardNumber).toList(),
          ['E1', 'M3'], reason: '★残すメンバーのスタックは剥がさない');
    });

    test('剥がれるのは他のメンバーとその下のカードだけ', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', orientation: CardOrientation.active),
            beneath: [_on('E2')],
          ),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);

      final result = full.tidy(state);

      // M1 は控え室へ、その下の E2 はエネルギーデッキ置き場へ (10.5.5 広義)。
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          ['M1']);
      expect(cardsIn(result.state, 'A', Zone.energyDeck).map((c) => c.cardNumber),
          ['E2']);
    });

    test('メンバーが 1 枚なら何もしない', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(member: _on('M1', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);
      expect(result.applied, isEmpty);
      expect(result.rounds, 0);
    });
  });

  group('10.5.1 / 10.5.2 不正カード処理', () {
    test('10.5.1 ライブカード置き場のライブでない表向きカードは控え室へ', () {
      final state = _state(liveStage: [_on('L1'), _on('M1')]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.invalidLiveStage));
      expect(cardsIn(result.state, 'A', Zone.liveStage).map((c) => c.cardNumber),
          ['L1']);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          ['M1']);
    });

    test('★裏向きのカードは 10.5.1 の対象外 (8.2.2 のブラフは正規戦術)', () {
      final state =
          _state(liveStage: [_on('M1', face: FaceState.faceDown)]);
      final result = full.tidy(state);

      expect(result.applied, isEmpty);
      expect(cardsIn(result.state, 'A', Zone.liveStage).length, 1);
    });

    test('10.5.2 エネルギー置き場のエネルギーでないカードは控え室へ', () {
      // ★10.5.2 の対象は定義上エネルギーではないので 10.5.5 は効かない。
      final state = _state(energyField: [_on('E1'), _on('M1')]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.invalidEnergyField));
      expect(cardsIn(result.state, 'A', Zone.energyField).map((c) => c.cardNumber),
          ['E1']);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          ['M1']);
    });
  });

  group('★自動実行しないルール処理', () {
    test('10.3 勝利処理は警告のみ。盤面を変えない (D10)', () {
      final state = _state(successLive: [_on('L1'), _on('L1'), _on('L1')]);
      final result = full.tidy(state);

      expect(result.warnings, contains(RuleProcessWarningKind.victory));
      expect(cardsIn(result.state, 'A', Zone.successLive).length, 3,
          reason: '★勝敗確定は手動ボタン。盤面を触らない');
      expect(result.applied, isEmpty);
    });

    test('10.6 不正解決領域処理も警告のみ。解決領域を掃除しない (D-A)', () {
      // 「プレイ中 / 解決中」は効果の解決状態であり観測できない。
      // 自動で控え室へ送るとプレイヤーの手動処理を破壊する。
      final state = _state(resolution: [_on('M1')]);
      final result = full.tidy(state);

      expect(result.warnings,
          contains(RuleProcessWarningKind.invalidResolution));
      expect(result.state.resolution.length, 1, reason: '★解決領域を触らない');
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
    });

    test('警告の条番号が 10.3 / 10.6', () {
      expect(RuleProcessWarningKind.victory.ruleRef, '10.3');
      expect(RuleProcessWarningKind.invalidResolution.ruleRef, '10.6');
    });
  });

  group('9.5.3.1 の再判定ループ', () {
    test('該当が無ければラウンド 0 で終わる', () {
      expect(full.tidy(_state()).rounds, 0);
    });

    test('10.4.1 で生じた孤児は同じ整理の中で処理される', () {
      // 剥がされたカードは控え室 / エネルギーデッキへ直接送られるため、
      // 1 ラウンドで収束する。
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
            member: _on('M1', orientation: CardOrientation.active),
            beneath: [_on('E1')],
          ),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      expect(result.rounds, 1);
      expect(result.state.players.first.memberAreas.first.orphans, isEmpty);
      expect(cardsIn(result.state, 'A', Zone.energyDeck).length, 1);
    });
  });

  group('未知カードの扱い', () {
    test('★種別を判定できないカードは処理せず件数を記録する', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('UNKNOWN')]),
      ]);
      final result = processor.tidy(state);

      expect(result.hasExclusions, isTrue);
      expect(result.excludedCount, 1);
      expect(result.unknownCardNumbers, ['UNKNOWN']);
      // 例外は投げない。
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
    });
  });

  group('条番号の対応', () {
    test('RuleProcessKind が 10.4.1 / 10.5.1〜10.5.4 に対応する', () {
      expect(
        RuleProcessKind.values.map((k) => k.ruleRef).toList(),
        ['10.4.1', '10.5.1', '10.5.2', '10.5.3', '10.5.4'],
      );
    });
  });
}
