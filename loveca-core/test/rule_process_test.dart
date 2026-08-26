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

/// ★★ 盤面に在るすべての札の instanceId（重複を許す多重集合）★★
///
/// ★★ この走査自体が「見えていない」なら、保存の検査は常に通る ★★
///   0 件は「無い」と「見えていない」の区別がつかない（**D-10**）。
///   → 下の「★陽性対照」がこの走査の判別力を先に確かめる。
///
/// ★領域は [Zone.values] から回す。手で列挙すると落とした項目が検査されない
///   （`loveca-ui/test/state/board_session_test.dart` の `_signature` と同じ回し方）。
List<String> _allInstanceIds(GameState state) {
  final ids = <String>[];
  for (final player in state.players) {
    for (final zone in Zone.values) {
      // ★実体を持たない / 専用の入れ物がある 3 つは `cardsIn` が受け取らない。
      if (zone == Zone.stage ||
          zone == Zone.memberArea ||
          zone == Zone.resolution) {
        continue;
      }
      ids.addAll(cardsIn(state, player.playerId, zone).map((c) => c.instanceId));
    }
    for (final area in player.memberAreas) {
      for (final stack in area.stacks) {
        ids.add(stack.member.instanceId);
        ids.addAll(stack.beneath.map((c) => c.instanceId));
      }
      ids.addAll(area.orphans.map((c) => c.instanceId));
    }
    for (final zone in OutOfRuleZone.values) {
      ids.addAll(
          cardsInOutOfRule(state, player.playerId, zone).map((c) => c.instanceId));
    }
  }
  // ★共有は 1 つだけ（4.14.1）。プレイヤーごとに数えない。
  ids.addAll(state.resolution.map((c) => c.instanceId));
  ids.sort();
  return ids;
}

/// カタログに無い札。★`_master` に入れていないことがこの札の定義である。
CardInstance _ghost({String ownerId = 'A'}) => _on('GHOST', ownerId: ownerId);

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
  // ★カタログは 1 つ。「引けない札」は `_master` に無い cardNumber（[_ghost]）で作る。
  //   空のカタログを別に持つと、10.5.1 / 10.5.2 の「選ぶ側で弾く」検査ができない。
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

  // =========================================================================
  // ★★ D-22: 整理で盤面から札が 1 枚も消えない ★★
  // =========================================================================

  group('★★ 走査の判別力（本体より先に確かめる / D-10）★★', () {
    test('★陽性対照: 走査は「在る札」を見つける', () {
      // ★★ これが通らなければ、下の保存の検査は「何をしても通る」検査である ★★
      //   走査が盲目（常に空）でも前後は一致してしまう。
      final ghost = _ghost();
      final member = _on('M1');
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [ghost, member]),
      ]);

      final seen = _allInstanceIds(state);
      expect(seen, contains(ghost.instanceId), reason: '★孤児が走査に入っていない');
      expect(seen, contains(member.instanceId));
      expect(seen.length, 2, reason: '★数えすぎ / 数え落としが無いこと');
    });

    test('★陽性対照: 走査は束の中身（member / beneath）も見つける', () {
      final member = _on('M1', orientation: CardOrientation.active);
      final under = _on('E1');
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(member: member, beneath: [under]),
        ]),
      ]);

      expect(_allInstanceIds(state),
          containsAll([member.instanceId, under.instanceId]));
    });

    test('★陰性対照: 走査は盤面に無い札を見つけない', () {
      // ★「常に含む」実装なら上の 2 件も通ってしまう。
      final elsewhere = _on('M1');
      expect(_allInstanceIds(_state()), isNot(contains(elsewhere.instanceId)));
    });
  });

  group('★★ 整理で札が消えない（D-22 / 決定 D95）★★', () {
    /// 整理の前後で盤面の札が 1 枚も増減しないこと。
    void expectConserved(GameState before, RuleProcessResult result) {
      final ids = _allInstanceIds(before);
      expect(ids, isNotEmpty, reason: '★空の盤面では何も検査していない');
      expect(_allInstanceIds(result.state), ids,
          reason: '★整理で札が消えている / 増えている');
    }

    test('カタログを引けない孤児で整理しても 1 枚も消えない', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_ghost()]),
      ]);
      expectConserved(state, full.tidy(state));
    });

    test('★ライブの孤児（条文に行き先が無い）でも 1 枚も消えない', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('L1')]),
      ]);
      expectConserved(state, full.tidy(state));
    });

    test('★10.4.1 で引けない非 survivor が居ても 1 枚も消えない', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(member: _ghost(), beneath: [_ghost(), _on('E1')]),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      expectConserved(state, full.tidy(state));
    });

    test('★対: 引ける札だけでも 1 枚も消えない（ただし移動はする）', () {
      // ★★ 「動かない実装」でも保存の検査は通る ★★
      //   だから移動が起きていることを対で見る。
      final orphan = _on('M1');
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [orphan]),
      ]);
      final result = full.tidy(state);

      expectConserved(state, result);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).single.instanceId,
          orphan.instanceId, reason: '★控え室へ移っている');
      expect(result.state.players.first.memberAreas.first.orphans, isEmpty);
    });

    test('★オーナーが相手でも消えない (4.1.7)', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_ghost(ownerId: 'B')]),
      ]);
      expectConserved(state, full.tidy(state));
    });
  });

  group('★★ カタログを引けない札は動かさず元の場所に残す ★★', () {
    test('孤児はメンバーエリアに残り、理由が「データの問題」で出る', () {
      final ghost = _ghost();
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [ghost]),
      ]);
      final result = full.tidy(state);

      expect(result.hasUnmovable, isTrue);
      expect(result.unmovable.single.cardNumber, 'GHOST');
      expect(result.unmovable.single.reason, UnmovableReason.unknownCard);
      // ★★ 元の場所に在ること。ここが D-22 そのものである ★★
      expect(
          result.state.players.first.memberAreas.first.orphans.single.instanceId,
          ghost.instanceId);
      // ★どこへも送っていない。
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty);
      expect(cardsIn(result.state, 'A', Zone.energyDeck), isEmpty);
    });

    test('★★ 種別を推測して 10.5.3 を積まない ★★', () {
      // ★以前は `card?.cardType == energy ? … : orphanMember` で
      //   `null` が **メンバーカード扱い**になり、
      //   「上にメンバーが居ないメンバーカード 10.5.3」と報告していた。
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_ghost()]),
      ]);
      final result = full.tidy(state);

      expect(result.applied, isEmpty);
      expect(result.rounds, 0, reason: '★動く札が無いのでループが空回りしない');
    });

    test('★対: 引ける孤児では 10.5.3 が積まれ、エリアから消える', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [_on('M1')]),
      ]);
      final result = full.tidy(state);

      expect(result.applied, [RuleProcessKind.orphanMember]);
      expect(result.unmovable, isEmpty);
    });

    test('引ける札と引けない札が混ざると、引ける札だけが動く', () {
      final ghost = _ghost();
      final state = _state(areas: [
        MemberArea(
          slot: MemberAreaSlot.center,
          orphans: [_on('M1'), ghost, _on('E1')],
        ),
      ]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'A', Zone.waitingRoom).length, 1);
      expect(cardsIn(result.state, 'A', Zone.energyDeck).length, 1);
      expect(
          result.state.players.first.memberAreas.first.orphans.single.instanceId,
          ghost.instanceId);
      expect(result.unmovable.single.reason, UnmovableReason.unknownCard);
    });
  });

  group('★★ ライブの孤児は条文に行き先が無い（決定 D95）★★', () {
    test('動かさず、理由が「条文の問題」で出る', () {
      // ★4.5.5 は下に重ねられるカードをメンバー / エネルギーに限り、
      //   10.5.3 / 10.5.4 もその 2 種別しか定めていない。
      final live = _on('L1');
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [live]),
      ]);
      final result = full.tidy(state);

      expect(result.unmovable.single.reason,
          UnmovableReason.noRuleForCardType);
      expect(
          result.state.players.first.memberAreas.first.orphans.single.instanceId,
          live.instanceId);
      expect(cardsIn(result.state, 'A', Zone.waitingRoom), isEmpty,
          reason: '★控え室は 10.5.3 の行き先であってライブの行き先ではない');
      expect(result.applied, isEmpty);
    });

    test('★対: メンバー / エネルギーの孤児は動く', () {
      for (final entry in {'M1': Zone.waitingRoom, 'E1': Zone.energyDeck}
          .entries) {
        final state = _state(areas: [
          MemberArea(slot: MemberAreaSlot.center, orphans: [_on(entry.key)]),
        ]);
        final result = full.tidy(state);

        expect(result.unmovable, isEmpty, reason: entry.key);
        expect(cardsIn(result.state, 'A', entry.value).length, 1,
            reason: entry.key);
      }
    });

    test('★判定は 1 か所（orphanUnmovableReason）から取れる', () {
      // ★UI が同じ判定を書き直さないための口。整理の実行と同じ答えを返す。
      expect(full.orphanUnmovableReason(_on('M1')), isNull);
      expect(full.orphanUnmovableReason(_on('E1')), isNull);
      expect(full.orphanUnmovableReason(_on('L1')),
          UnmovableReason.noRuleForCardType);
      expect(full.orphanUnmovableReason(_ghost()), UnmovableReason.unknownCard);
    });
  });

  group('★★ 10.4.1 も同じ形だった（D-22 の走査で出た 2 か所目）★★', () {
    test('引けない非 survivor のメンバーは束のままエリアに残る', () {
      final ghost = _ghost();
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(member: ghost),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      final area = result.state.players.first.memberAreas.first;
      expect(area.stacks.length, 2, reason: '★消えていない');
      expect(area.stacks.first.member.instanceId, ghost.instanceId);
      expect(area.stacks.last.member.cardNumber, 'M2',
          reason: '★survivor は末尾のまま（10.4.1 の配置順の規約）');
      expect(result.applied, isEmpty, reason: '★1 枚も動いていない');
      expect(result.rounds, 0, reason: '★空回りしない');
      expect(result.unmovable.single.reason, UnmovableReason.unknownCard);
    });

    test('★対: 引ける非 survivor は控え室へ行く', () {
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(member: _on('M1', orientation: CardOrientation.active)),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.duplicateMember));
      expect(result.state.players.first.memberAreas.first.stacks.length, 1);
    });

    test('★メンバーは動くが下の札を引けないとき、その札は孤児として残る (4.5.5.4)', () {
      final ghost = _ghost();
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
              member: _on('M1', orientation: CardOrientation.active),
              beneath: [ghost, _on('E1')]),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      final area = result.state.players.first.memberAreas.first;
      expect(area.stacks.length, 1, reason: 'M1 は動いた');
      expect(area.orphans.single.instanceId, ghost.instanceId,
          reason: '★引けなかった下の札はエリアに残る');
      expect(result.applied, contains(RuleProcessKind.duplicateMember));
      expect(cardsIn(result.state, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          ['M1']);
      expect(cardsIn(result.state, 'A', Zone.energyDeck).map((c) => c.cardNumber),
          ['E1']);
    });

    test('★★ 10.4.1 はライブカードでも控え室へ送る（10.5.3 とは格が違う）★★', () {
      // 10.4.1「それ以外のそのメンバーエリアの**カード**を…控え室に置きます」は
      // 種別を条件にしていない。10.5.5 が行き先だけを振り替える。
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, stacks: [
          MemberStack(
              member: _on('M1', orientation: CardOrientation.active),
              beneath: [_on('L1')]),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'A', Zone.waitingRoom).map((c) => c.cardNumber),
          containsAll(['M1', 'L1']));
      expect(result.unmovable, isEmpty,
          reason: '★10.4.1 の枝ではライブに行き先がある');
    });
  });

  group('★★ 動かせなかった札の数え方 ★★', () {
    test('同じ札を複数ラウンド走査しても 1 枚と数える', () {
      // ★10.4.1 が 1 ラウンド目で動き、2 ラウンド目でも引けない孤児を走査する。
      final ghost = _ghost();
      final state = _state(areas: [
        MemberArea(slot: MemberAreaSlot.center, orphans: [
          ghost
        ], stacks: [
          MemberStack(
              member: _on('M1', orientation: CardOrientation.active),
              beneath: [_on('E1')]),
          MemberStack(member: _on('M2', orientation: CardOrientation.active)),
        ]),
      ]);
      final result = full.tidy(state);

      expect(result.rounds, greaterThanOrEqualTo(1));
      expect(result.unmovable.length, 1, reason: '★ラウンドごとに数えない');
      expect(result.unmovable.single.instanceId, ghost.instanceId);
    });

    test('別々の札は別々に数える', () {
      final state = _state(areas: [
        MemberArea(
            slot: MemberAreaSlot.center, orphans: [_ghost(), _ghost(), _on('L1')]),
      ]);
      final result = full.tidy(state);

      expect(result.unmovable.length, 3);
      expect(
          result.unmovableFor(UnmovableReason.unknownCard).length, 2);
      expect(
          result.unmovableFor(UnmovableReason.noRuleForCardType).length, 1);
    });

    test('★並びは決定的（同じ入力から同じ報告）', () {
      GameState build() => _state(areas: [
            MemberArea(slot: MemberAreaSlot.center, orphans: [
              CardInstance(
                  instanceId: 'z', printingId: 'G-R', cardNumber: 'G', ownerId: 'A'),
              CardInstance(
                  instanceId: 'a', printingId: 'G-R', cardNumber: 'G', ownerId: 'A'),
            ]),
          ]);
      final ids = full.tidy(build()).unmovable.map((c) => c.instanceId).toList();
      expect(ids, ['a', 'z']);
      expect(full.tidy(build()).unmovable.map((c) => c.instanceId).toList(), ids);
    });
  });

  group('★★ 10.5.1 / 10.5.2 は引けない札を選ばない ★★', () {
    test('引けない札はライブカード置き場に残り、報告にも出ない', () {
      // ★「選ぶ側」で先に弾く形なので、そもそも動かす対象にならない。
      final ghost = _ghost();
      final state = _state(liveStage: [ghost]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'A', Zone.liveStage).single.instanceId,
          ghost.instanceId);
      expect(result.unmovable, isEmpty, reason: '★動かそうとしていない');
      expect(result.applied, isEmpty);
    });

    test('★陽性対照: 引ける非ライブ札は選ばれて控え室へ行く', () {
      // ★これが通らないと、上の検査は「10.5.1 が動いていない」だけを見ている。
      final state = _state(liveStage: [_on('M1')]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.invalidLiveStage));
      expect(cardsIn(result.state, 'A', Zone.liveStage), isEmpty);
    });

    test('引けない札はエネルギー置き場にも残る', () {
      final ghost = _ghost();
      final state = _state(energyField: [ghost]);
      final result = full.tidy(state);

      expect(cardsIn(result.state, 'A', Zone.energyField).single.instanceId,
          ghost.instanceId);
      expect(result.unmovable, isEmpty);
    });

    test('★陽性対照: 引ける非エネルギー札は選ばれて控え室へ行く', () {
      final state = _state(energyField: [_on('M1')]);
      final result = full.tidy(state);

      expect(result.applied, contains(RuleProcessKind.invalidEnergyField));
      expect(cardsIn(result.state, 'A', Zone.energyField), isEmpty);
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
