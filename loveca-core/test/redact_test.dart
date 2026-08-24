import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type, {int? blade}) => Card(
      cardNumber: number,
      name: number,
      cardType: type,
      bladeCount: blade,
      hearts: type == CardType.member ? const {HeartColor.pink: 2} : const {},
      score: type == CardType.live ? 3 : null,
    );

final _master = <String, Card>{
  'M1': _card('M1', CardType.member, blade: 2),
  'E1': _card('E1', CardType.energy),
  'L1': _card('L1', CardType.live),
};

var _seq = 0;
CardInstance _on(
  String cardNumber, {
  String ownerId = 'A',
  FaceState face = FaceState.faceUp,
  CardOrientation? orientation,
}) =>
    CardInstance(
      instanceId: 'i${_seq++}',
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
      face: face,
      orientation: orientation,
    );

List<CardInstance> _cards(String n, int count, {String ownerId = 'A'}) =>
    [for (var i = 0; i < count; i++) _on(n, ownerId: ownerId)];

/// 全領域の枚数。4.1.2.2 の検証に使う。
Map<String, int> _counts(GameState state) {
  final out = <String, int>{'resolution': state.resolution.length};
  for (final p in state.players) {
    for (final zone in const [
      Zone.hand,
      Zone.mainDeck,
      Zone.energyDeck,
      Zone.energyField,
      Zone.liveStage,
      Zone.successLive,
      Zone.waitingRoom,
      Zone.exile,
    ]) {
      out['${p.playerId}.${zone.name}'] = cardsIn(state, p.playerId, zone).length;
    }
    for (final zone in OutOfRuleZone.values) {
      out['${p.playerId}.${zone.name}'] =
          cardsInOutOfRule(state, p.playerId, zone).length;
    }
    out['${p.playerId}.memberAreas'] = p.memberAreas.fold(
      0,
      (sum, a) =>
          sum +
          a.orphans.length +
          a.stacks.fold(0, (s, st) => s + 1 + st.beneath.length),
    );
  }
  return out;
}

/// 盤面を比較可能な形に潰す。`GameState` は `==` を持たないため。
String _fingerprint(GameState state) {
  String card(CardInstance c) =>
      '${c.instanceId}|${c.printingId}|${c.cardNumber}|${c.ownerId}'
      '|${c.orientation}|${c.face}|${c.isRedacted}';

  final buffer = StringBuffer('res:${state.resolution.map(card).join(",")}');
  for (final p in state.players) {
    buffer.write('\n${p.playerId}');
    for (final zone in Zone.values) {
      if (zone == Zone.resolution ||
          zone == Zone.memberArea ||
          zone == Zone.stage) {
        continue;
      }
      buffer.write('\n ${zone.name}:'
          '${cardsIn(state, p.playerId, zone).map(card).join(",")}');
    }
    for (final zone in OutOfRuleZone.values) {
      buffer.write('\n ${zone.name}:'
          '${cardsInOutOfRule(state, p.playerId, zone).map(card).join(",")}');
    }
    for (final area in p.memberAreas) {
      buffer.write('\n area${area.slot.name}:'
          '${area.stacks.map((s) => "${card(s.member)}[${s.beneath.map(card).join(";")}]").join(",")}'
          '/${area.orphans.map(card).join(",")}');
    }
  }
  return buffer.toString();
}

GameState _state() => GameState(
      players: [
        PlayerState(
          playerId: 'A',
          hand: _cards('M1', 3),
          mainDeck: _cards('M1', 5),
          energyDeck: _cards('E1', 4),
          energyField: [_on('E1', orientation: CardOrientation.active)],
          liveStage: [
            _on('L1', face: FaceState.faceDown),
            _on('L1'),
          ],
          successLive: [_on('L1')],
          waitingRoom: _cards('M1', 2),
          exile: [_on('M1'), _on('M1', face: FaceState.faceDown)],
          mulliganAside: _cards('M1', 1),
          freeArea: [_on('M1', face: FaceState.faceDown)],
          memberAreas: [
            MemberArea(slot: MemberAreaSlot.center, stacks: [
              MemberStack(
                member: _on('M1', orientation: CardOrientation.active),
                beneath: [_on('E1')],
              ),
            ]),
          ],
        ),
        PlayerState(
          playerId: 'B',
          hand: _cards('M1', 4, ownerId: 'B'),
          mainDeck: _cards('M1', 6, ownerId: 'B'),
          energyDeck: _cards('E1', 3, ownerId: 'B'),
          liveStage: [_on('L1', ownerId: 'B', face: FaceState.faceDown)],
          exile: [_on('M1', ownerId: 'B', face: FaceState.faceDown)],
          mulliganAside: _cards('M1', 2, ownerId: 'B'),
        ),
      ],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_2),
      resolution: [_on('M1'), _on('M1', ownerId: 'B')],
    );

void main() {
  group('★4.1.2.2 枚数は残る', () {
    test('秘匿後も全領域の枚数が一致する', () {
      final state = _state();
      // 4.1.2.2「領域が公開であるか非公開であるかにかかわらず、それぞれの領域に
      //          あるカードの枚数は、すべてのプレイヤーがいつでも確認することが
      //          できます」
      for (final viewer in ['A', 'B']) {
        expect(_counts(redact(state, viewer)), _counts(state), reason: viewer);
      }
    });
  });

  group('4.11.2 手札', () {
    test('★自分の手札は見えるが相手の手札は枚数だけになる', () {
      final view = redact(_state(), 'A');

      final own = cardsIn(view, 'A', Zone.hand);
      expect(own.every((c) => !c.isRedacted), isTrue);
      expect(own.every((c) => c.cardNumber == 'M1'), isTrue);

      final other = cardsIn(view, 'B', Zone.hand);
      expect(other.length, 4, reason: '枚数は残る');
      expect(other.every((c) => c.isRedacted), isTrue);
      expect(other.every((c) => c.cardNumber.isEmpty), isTrue);
      expect(other.every((c) => c.printingId.isEmpty), isTrue);
    });
  });

  group('★4.8.2 / 4.9.2 デッキはオーナーからも見えない', () {
    test('メインデッキ置き場とエネルギーデッキ置き場は全員から隠す', () {
      // 4.8.2 /4.9.2「すべてのプレイヤーに対して非公開領域」
      // 4.11.2 のような所有者の例外が無い。
      final view = redact(_state(), 'A');

      for (final zone in [Zone.mainDeck, Zone.energyDeck]) {
        expect(cardsIn(view, 'A', zone).every((c) => c.isRedacted), isTrue,
            reason: '${zone.name} は自分の分も隠す');
        expect(cardsIn(view, 'B', zone).every((c) => c.isRedacted), isTrue);
      }
    });
  });

  group('★裏向きの扱い（決定 D37）', () {
    test('ライブカード置き場の裏向きは他プレイヤーからのみ隠す (4.6.2 / 8.2.2)', () {
      final view = redact(_state(), 'A');

      // 自分の裏向きは見える。本人が手札から選んで置いた (8.2.2)。
      final own = cardsIn(view, 'A', Zone.liveStage);
      expect(own.every((c) => !c.isRedacted), isTrue);

      // 相手の裏向きは隠す。
      final other = cardsIn(view, 'B', Zone.liveStage);
      expect(other.single.isRedacted, isTrue);
      expect(other.single.face, FaceState.faceDown, reason: '表示面は残る');
    });

    test('表向きのライブカードは相手のものでも隠さない (8.3.4 の後)', () {
      final state = _state();
      final view = redact(state, 'B');
      final faceUp =
          cardsIn(view, 'A', Zone.liveStage).where((c) => c.face == FaceState.faceUp);
      expect(faceUp.every((c) => !c.isRedacted), isTrue);
    });

    test('★除外領域の裏向きは全員から隠す (4.3.3.2 / 4.13.2)', () {
      // ライブカード置き場と非対称。4.13.2 は既定を表向きと定めており、
      // 裏向きは効果由来で誰が知るかを条文が定めていないため 4.3.3.2 に従う。
      final view = redact(_state(), 'A');
      final own = cardsIn(view, 'A', Zone.exile);

      expect(own.length, 2);
      expect(own.where((c) => c.face == FaceState.faceUp).single.isRedacted,
          isFalse);
      expect(own.where((c) => c.face == FaceState.faceDown).single.isRedacted,
          isTrue, reason: '★自分の除外でも裏向きなら隠す');
    });

    test('6.2.1.6 の脇置きは他プレイヤーからのみ隠す', () {
      final view = redact(_state(), 'A');
      expect(
          cardsInOutOfRule(view, 'A', OutOfRuleZone.mulliganAside)
              .every((c) => !c.isRedacted),
          isTrue);
      expect(
          cardsInOutOfRule(view, 'B', OutOfRuleZone.mulliganAside)
              .every((c) => c.isRedacted),
          isTrue);
    });
  });

  group('公開領域は隠さない', () {
    test('4.14 解決領域 / 4.7 / 4.10 / 4.12 / 4.5 はそのまま', () {
      final view = redact(_state(), 'B');

      // 4.14.1 共有・4.14.2 公開。
      expect(view.resolution.every((c) => !c.isRedacted), isTrue);
      expect(view.resolution.map((c) => c.ownerId).toList(), ['A', 'B']);

      for (final zone in [Zone.energyField, Zone.successLive, Zone.waitingRoom]) {
        expect(cardsIn(view, 'A', zone).every((c) => !c.isRedacted), isTrue,
            reason: zone.name);
      }

      // 4.5.3 メンバーエリアは公開領域。下に重ねられたカードも隠さない。
      final stack = view.players.first.memberAreas.first.stacks.single;
      expect(stack.member.isRedacted, isFalse);
      expect(stack.beneath.single.isRedacted, isFalse);
    });
  });

  group('★冪等性', () {
    test('redact(redact(s, v), v) == redact(s, v)', () {
      final state = _state();
      for (final viewer in ['A', 'B']) {
        final once = redact(state, viewer);
        final twice = redact(once, viewer);
        expect(_fingerprint(twice), _fingerprint(once), reason: viewer);
      }
    });
  });

  group('★領域跨ぎの追跡を防ぐ', () {
    test('秘匿されたカードの instanceId は元と一致しない', () {
      final state = _state();
      final view = redact(state, 'A');

      final originals =
          cardsIn(state, 'B', Zone.hand).map((c) => c.instanceId).toSet();
      final redacted =
          cardsIn(view, 'B', Zone.hand).map((c) => c.instanceId).toSet();

      expect(redacted.intersection(originals), isEmpty,
          reason: '★元の id が残ると領域を跨いで追跡できてしまう');
      expect(redacted.length, originals.length, reason: 'id は重複しない');
    });

    test('ownerId は残る (4.14.1 の絞り込みに要る)', () {
      final view = redact(_state(), 'A');
      expect(cardsIn(view, 'B', Zone.hand).every((c) => c.ownerId == 'B'), isTrue);
    });
  });

  group('入力を変更しない', () {
    test('redact は元の GameState を壊さない', () {
      final state = _state();
      final before = _fingerprint(state);
      redact(state, 'A');
      redact(state, 'B');
      expect(_fingerprint(state), before);
    });
  });

  group('★★秘匿した盤面で集計を走らせるとどうなるか★★', () {
    // 報告事項。redact 後の状態で LiveAggregator を呼ぶこと自体が誤りである
    // ことを、挙動として固定しておく。
    final aggregator = LiveAggregator(cards: _master);

    test('秘匿前は正しい数値が出る', () {
      final state = _state();
      final blade = aggregator.bladeTotal(state, 'A');

      expect(blade.total, 2, reason: 'M1 のブレードは 2');
      expect(blade.hasExclusions, isFalse);
    });

    test('★メンバーエリアは公開領域なので秘匿後も 8.3.10 は正しく出る', () {
      // redact はメンバーエリアを隠さない (4.5.3)。
      // したがってブレード合計だけは秘匿後でも一致する。
      final view = redact(_state(), 'B');
      final blade = aggregator.bladeTotal(view, 'A');

      expect(blade.total, 2);
      expect(blade.hasExclusions, isFalse);
    });

    test('★★秘匿された領域を見る集計は全件が除外扱いになる★★', () {
      // 8.4.2 は相手のライブカード置き場を読む。相手視点では裏向きが秘匿され、
      // cardNumber が空なのでカードマスタを引けず、未知カードとして除外される。
      final state = _state();
      final view = redact(state, 'B'); // B から見た盤面

      final before = aggregator.scoreTotal(state, 'A');
      final after = aggregator.scoreTotal(view, 'A');

      expect(before.total, 6, reason: 'L1 が 2 枚でスコア 3 ずつ');
      expect(before.hasExclusions, isFalse);

      // ★秘匿後は裏向きの 1 枚が読めず、スコアが 3 に減って除外が 1 件立つ。
      expect(after.total, 3);
      expect(after.excludedCount, 1);
      expect(after.unknownCardNumbers, [''],
          reason: '★秘匿されたカードは cardNumber が空なので未知カードになる');
    });

    test('★デッキを読む処理は秘匿後に全件が未知になる', () {
      final view = redact(_state(), 'A');
      // メインデッキはオーナーからも隠れる (4.8.2)。
      expect(cardsIn(view, 'A', Zone.mainDeck).every((c) => c.cardNumber.isEmpty),
          isTrue);
    });
  });
}
