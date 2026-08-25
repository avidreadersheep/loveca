/// 領域に置かれるカードの状態（総合ルール 4.1.2.1）。
///
/// ★★ 走査は `Zone.values` から回す ★★
///   領域名を手で並べると、条文が 11 種と定めている (4.4〜4.14) のに
///   一部だけを見るテストになる。`ルール整合性チェック_v1.06.md` D-15 と同じ型。
///
/// ★★ 「出る側」だけでは何も証明しない ★★
///   `docs/...` D-10 の教訓。**移動する前の札が本当に「移動先の規定と違う表示面」で
///   あること**を先に検査してからでないと、`placedIn` が何もしない実装でも通る。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

Card _card(String number, CardType type) =>
    Card(cardNumber: number, name: number, cardType: type);

final _master = <String, Card>{
  'M1': _card('M1', CardType.member),
  'E1': _card('E1', CardType.energy),
};

ReduceContext _ctx() => ReduceContext(cards: _master, rng: SeededRng(42));

CardInstance _on(
  String id, {
  String cardNumber = 'M1',
  String ownerId = 'A',
  FaceState face = FaceState.faceUp,
  CardOrientation? orientation,
}) =>
    CardInstance(
      instanceId: id,
      printingId: '$cardNumber-R',
      cardNumber: cardNumber,
      ownerId: ownerId,
      face: face,
      orientation: orientation,
    );

GameState _empty() => GameState(
      players: const [PlayerState(playerId: 'A'), PlayerState(playerId: 'B')],
      firstPlayerId: 'A',
      cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_2),
    );

GameState _with(Zone zone, List<CardInstance> cards, {String playerId = 'A'}) =>
    replaceZone(_empty(), playerId, zone, cards);

/// [MoveCard] が受け付ける領域。
///
/// 4.14 解決領域は共有で 1 つだけ (4.14.1)、4.5 メンバーエリアは 4.5.5 の構造を持ち、
/// 4.4 ステージは実体を持たない (4.4.1) ため、いずれも専用のアクションが扱う。
final _movable = Zone.values
    .where((z) =>
        z != Zone.stage && z != Zone.memberArea && z != Zone.resolution)
    .toList();

/// ★★ 条文から直接書き写した期待値。`Zone.visibility` からは導かない ★★
///   実装 (`placedIn`) が `Zone.visibility` から導いているので、
///   テストも同じ源から導くと**両方が一緒に動いて検知できなくなる**。
///   ここは条文の字面をそのまま持ち、下の「突き合わせ」テストで
///   `Zone.visibility` と一致していることを別に見る。
///
/// null = 領域側の条文が 4.1.2.1 の例外を定める。
const _expectedFace = <Zone, FaceState?>{
  // 4.6.2「公開領域ですが、カードが一時的に裏向きに置かれることがあります」
  Zone.liveStage: null,
  // 4.7.2「エネルギー置き場はすべてのプレイヤーに対して公開領域」
  Zone.energyField: FaceState.faceUp,
  // 4.8.2「メインデッキ置き場はすべてのプレイヤーに対して非公開領域」
  Zone.mainDeck: FaceState.faceDown,
  // 4.9.2「エネルギーデッキ置き場はすべてのプレイヤーに対して非公開領域」
  Zone.energyDeck: FaceState.faceDown,
  // 4.10.2「成功ライブカード置き場はすべてのプレイヤーに対して公開領域」
  Zone.successLive: FaceState.faceUp,
  // 4.11.2「手札は非公開領域ですが、自分の手札のカードは自分のみが自由に確認できます」
  Zone.hand: FaceState.faceDown,
  // 4.12.2「控え室は公開領域」
  Zone.waitingRoom: FaceState.faceUp,
  // 4.13.2「特に指示がないかぎり、取り除かれたカードは表向きに置かれます」
  Zone.exile: FaceState.faceUp,
};

/// [from] にある札が持つべき表示面。4.6 は条文が両方を許すので裏で作る
/// （8.2.2 / 8.2.4 が裏向きに置くため、こちらが実際に起こる形）。
FaceState _faceIn(Zone from) =>
    _expectedFace[from] ?? FaceState.faceDown;

GameState _move(GameState state, Zone from, Zone to) => reduce(
      state,
      MoveCard(
        instanceId: 'x',
        fromPlayerId: 'A',
        from: from,
        toPlayerId: 'A',
        to: to,
      ),
      context: _ctx(),
    );

void main() {
  group('★★ 前提の突き合わせ ★★', () {
    test('★期待値の表が MoveCard の受ける領域を 1 つ残らず覆う', () {
      expect(_expectedFace.keys.toSet(), _movable.toSet(),
          reason: '★領域が増減したら期待値の表も直す（4 章の領域は 11 種 / zone.dart）');
    });

    test('★条文から書き写した期待値と Zone.visibility が一致する', () {
      // ★実装は `Zone.visibility` から導く。テストは条文の字面から導く。
      //   **源を 2 つに分けてあるので、片方だけが壊れたら落ちる。**
      for (final zone in _movable) {
        if (zone == Zone.liveStage) continue; // 4.6.2 の例外
        final fromVisibility = switch (zone.visibility!) {
          ZoneVisibility.public => FaceState.faceUp,
          ZoneVisibility.private => FaceState.faceDown,
        };
        expect(_expectedFace[zone], fromVisibility,
            reason: '★${zone.ruleRef} で条文の字面と Zone.visibility が食い違っている');
      }
    });
  });

  group('★★ 4.1.2.1 — 領域に置かれるカードの表示面 ★★', () {
    test('★★ 陽性対照: 「移動前の表示面が移動先の規定と違う」組が実在する ★★', () {
      // ★これが空なら、下の行列テストは**何もしない実装でも通る**。
      final differing = <String>[
        for (final from in _movable)
          for (final to in _movable)
            if (from != to &&
                _expectedFace[to] != null &&
                _faceIn(from) != _expectedFace[to])
              '${from.ruleRef}->${to.ruleRef}',
      ];

      expect(differing, isNotEmpty);
      expect(differing, contains('4.11->4.12'),
          reason: '★報告された経路（手札 → 控え室）がこの検査に入っていること');
      expect(differing, contains('4.12->4.11'),
          reason: '★逆向き（控え室 → 手札）も入っていること');
    });

    test('★★ すべての (移動元, 移動先) で移動先の規定に従う ★★', () {
      for (final from in _movable) {
        for (final to in _movable) {
          if (from == to) continue;

          final start = _with(from, [_on('x', face: _faceIn(from))]);
          final moved = _move(start, from, to);
          final landed = cardsIn(moved, 'A', to).single;

          expect(landed.face, _expectedFace[to] ?? _faceIn(from),
              reason: '★${from.ruleRef} → ${to.ruleRef} '
                  '(移動前 ${_faceIn(from).name} / 期待 '
                  '${(_expectedFace[to] ?? _faceIn(from)).name})');
        }
      }
    });

    test('★報告されたバグそのもの: 手札 (4.11.2) → 控え室 (4.12.2) は表向きになる', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      // ★先に「移動前は裏向き」を確かめる。そうでなければ何も証明しない。
      expect(cardsIn(start, 'A', Zone.hand).single.face, FaceState.faceDown);

      final moved = _move(start, Zone.hand, Zone.waitingRoom);
      expect(cardsIn(moved, 'A', Zone.waitingRoom).single.face,
          FaceState.faceUp);
    });
  });

  group('★★ 対: 4.6.2 の例外を潰していない ★★', () {
    test('★★ 手札 → ライブカード置き場は裏向きのまま（8.2.2 / 8.2.4 のブラフ）★★', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      final moved = _move(start, Zone.hand, Zone.liveStage);

      expect(cardsIn(moved, 'A', Zone.liveStage).single.face,
          FaceState.faceDown,
          reason: '★表向きになったらブラフが成立しない（8.2.2）');
    });

    test('★★ 対の対: 控え室 → ライブカード置き場は表向きのまま ★★', () {
      // ★「常に裏向きにする」実装だとここで落ちる。
      //   4.6.2 は裏向きを**許す**のであって強制しない。
      final start = _with(Zone.waitingRoom, [_on('x')]);
      final moved = _move(start, Zone.waitingRoom, Zone.liveStage);

      expect(
          cardsIn(moved, 'A', Zone.liveStage).single.face, FaceState.faceUp);
    });

    test('★今日踏める経路: 控え室 → 手札 → ライブカード置き場が裏向きになる', () {
      // ★4.11.2 の非公開が復元されないと、ここが表向きのままライブに入る。
      final start = _with(Zone.waitingRoom, [_on('x')]);
      final inHand = _move(start, Zone.waitingRoom, Zone.hand);
      expect(cardsIn(inHand, 'A', Zone.hand).single.face, FaceState.faceDown,
          reason: '★4.11.2 は非公開領域');

      final onStage = _move(inHand, Zone.hand, Zone.liveStage);
      expect(cardsIn(onStage, 'A', Zone.liveStage).single.face,
          FaceState.faceDown);
    });
  });

  group('★★ 4.13.2 除外領域は「特に指示がないかぎり表向き」★★', () {
    test('手札 (裏) から除外しても表向きで置かれる', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      final moved = _move(start, Zone.hand, Zone.exile);

      expect(cardsIn(moved, 'A', Zone.exile).single.face, FaceState.faceUp);
    });

    test('★対: 置いたあとの 5.3.1 は効く（4.1.2.1 は反転を禁じない）', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      final moved = _move(start, Zone.hand, Zone.exile);
      final flipped = reduce(
        moved,
        const FlipCard(
          instanceId: 'x',
          playerId: 'A',
          zone: Zone.exile,
          face: FaceState.faceDown,
        ),
        context: _ctx(),
      );

      expect(cardsIn(flipped, 'A', Zone.exile).single.face,
          FaceState.faceDown,
          reason: '★4.1.2.1 は「置かれる場合」の規定。5.3.1 の明示指示は別');
    });
  });

  group('★★ 4.5 メンバーエリア（4.5.3 公開領域）★★', () {
    GameState placed({required FaceState from}) => reduce(
          _with(Zone.hand, [_on('x', face: from)]),
          const PlaceMemberInArea(
            instanceId: 'x',
            playerId: 'A',
            from: Zone.hand,
            slot: MemberAreaSlot.center,
          ),
          context: _ctx(),
        );

    MemberArea areaOf(GameState s) => s
        .playerOf('A')
        .memberAreas
        .firstWhere((a) => a.slot == MemberAreaSlot.center);

    test('手札 (裏) から置いたメンバーは表向きになる (4.1.2.1 / 4.5.3)', () {
      final s = placed(from: FaceState.faceDown);
      expect(areaOf(s).stacks.single.member.face, FaceState.faceUp);
    });

    test('★★ 下に重ねたカードも表向きになる（4.5.5.2 が奪うのは向きだけ）★★', () {
      var s = placed(from: FaceState.faceUp);
      s = replaceZone(s, 'A', Zone.hand,
          [_on('e', cardNumber: 'E1', face: FaceState.faceDown)]);
      // ★先に「重ねる前は裏向き」を確かめる。
      expect(cardsIn(s, 'A', Zone.hand).single.face, FaceState.faceDown);

      s = reduce(
        s,
        const StackUnderMember(
          instanceId: 'e',
          playerId: 'A',
          from: Zone.hand,
          slot: MemberAreaSlot.center,
          memberInstanceId: 'x',
        ),
        context: _ctx(),
      );

      final beneath = areaOf(s).stacks.single.beneath.single;
      expect(beneath.face, FaceState.faceUp,
          reason: '★4.5.3 は公開領域。redact も隠さないので裏のままだと矛盾する');
      expect(beneath.orientation, isNull, reason: '★4.5.5.2: 向きは持たない');
    });

    test('メンバーを手札へ戻すと裏向きになる (4.11.2)', () {
      final s = placed(from: FaceState.faceUp);
      final out = reduce(
        s,
        const MoveMemberOut(
          instanceId: 'x',
          playerId: 'A',
          slot: MemberAreaSlot.center,
          toPlayerId: 'A',
          to: Zone.hand,
        ),
        context: _ctx(),
      );

      expect(cardsIn(out, 'A', Zone.hand).single.face, FaceState.faceDown);
    });

    test('★★ 対: 4.5.5.3 のエリア間移動は状態を変えない（4.1.4 の除外）★★', () {
      // 4.1.4「カードがメンバーエリアからメンバーエリアあるいはライブカード置き場から
      //   ライブカード置き場のいずれでもない領域間の移動を行う場合、…新しいカードで
      //   あるとみなされます」= 条文自身がこの 2 経路を特別扱いしている。
      // ★11.10 ポジションチェンジで向きがどうなるかは M-B6 の論点。ここでは触らない。
      var s = placed(from: FaceState.faceUp);
      s = reduce(
        s,
        const SetMemberOrientation(
          instanceId: 'x',
          playerId: 'A',
          slot: MemberAreaSlot.center,
          orientation: CardOrientation.wait,
        ),
        context: _ctx(),
      );

      final moved = reduce(
        s,
        const MoveMemberBetweenAreas(
          instanceId: 'x',
          playerId: 'A',
          fromSlot: MemberAreaSlot.center,
          toSlot: MemberAreaSlot.leftSide,
        ),
        context: _ctx(),
      );

      final member = moved
          .playerOf('A')
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.leftSide)
          .stacks
          .single
          .member;
      expect(member.orientation, CardOrientation.wait,
          reason: '★ウェイトのまま移る。アクティブに戻すのは 11.10 の論点（M-B6）');
      expect(member.face, FaceState.faceUp);
    });
  });

  group('★★ 4.14 解決領域 / ルール外の置き場 ★★', () {
    test('解決領域へ入ると表向き (4.14.2)', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      final moved = reduce(
        start,
        const MoveToResolution(
            instanceId: 'x', fromPlayerId: 'A', from: Zone.hand),
        context: _ctx(),
      );

      expect(moved.resolution.single.face, FaceState.faceUp);
    });

    test('解決領域から手札へ戻すと裏向き (4.11.2)', () {
      final start = _with(Zone.hand, [_on('x', face: FaceState.faceDown)]);
      var s = reduce(
        start,
        const MoveToResolution(
            instanceId: 'x', fromPlayerId: 'A', from: Zone.hand),
        context: _ctx(),
      );
      expect(s.resolution.single.face, FaceState.faceUp, reason: '★経由を確認');

      s = reduce(
        s,
        const MoveFromResolution(
            instanceId: 'x', toPlayerId: 'A', to: Zone.hand),
        context: _ctx(),
      );
      expect(cardsIn(s, 'A', Zone.hand).single.face, FaceState.faceDown);
    });

    test('★ルール外の置き場から戻すときも着地先の規定が効く', () {
      // ★出どころは 4 章の領域ではないが、着地先はメインデッキ置き場 (4.8.2 非公開)。
      var s = _with(Zone.waitingRoom, [_on('x')]);
      s = reduce(
        s,
        const MoveOutOfRule(
          instanceId: 'x',
          playerId: 'A',
          from: Zone.waitingRoom,
          to: OutOfRuleZone.freeArea,
        ),
        context: _ctx(),
      );
      expect(
          cardsInOutOfRule(s, 'A', OutOfRuleZone.freeArea).single.face,
          FaceState.faceUp,
          reason: '★ルール外の置き場では 4.1.2.1 が効かない（4 章の領域ではない）');

      s = reduce(
        s,
        const MoveFromOutOfRule(
          instanceId: 'x',
          playerId: 'A',
          from: OutOfRuleZone.freeArea,
          to: Zone.mainDeck,
        ),
        context: _ctx(),
      );
      expect(cardsIn(s, 'A', Zone.mainDeck).single.face, FaceState.faceDown);
    });
  });

  group('★★ 4.3.1 / 4.3.2.3 — 領域に置かれるカードの向き ★★', () {
    // 4.3.1「一部の領域において、カードの配置状態が指定される場合があります」
    // ★向きを持つと条文が定めるのは 4.5.4（メンバーエリアのメンバーカード）と
    //   4.7.3（エネルギー置き場）の 2 つだけ。
    test('★★ 陽性対照: 向きを持つ領域は 4.7 ちょうど 1 つ（MoveCard の範囲で）★★', () {
      // ★これが空なら、下の行列テストは「常に向きを落とす」実装でも通る。
      const oriented = {Zone.energyField};
      expect(oriented.intersection(_movable.toSet()), isNotEmpty);
      for (final zone in _movable) {
        expect(placedIn(_on('x', orientation: CardOrientation.wait), zone)
                .orientation !=
            null,
            oriented.contains(zone),
            reason: '★${zone.ruleRef} の向きの扱いが条文と違う');
      }
    });

    test('★★ すべての (移動元, 移動先) で向きが移動先の規定に従う ★★', () {
      for (final from in _movable) {
        for (final to in _movable) {
          if (from == to) continue;

          // ★出どころで向きを持たせる。4.7 以外では条文上ありえない状態だが、
          //   「引き継いでいないこと」を見るには入力側に付いていないと意味が無い。
          final start =
              _with(from, [_on('x', orientation: CardOrientation.wait)]);
          final landed = cardsIn(_move(start, from, to), 'A', to).single;

          if (to == Zone.energyField) {
            // 4.7.3 / 4.3.2.3: 向きを持つ領域。既定はアクティブ状態。
            expect(landed.orientation, CardOrientation.active,
                reason: '★${from.ruleRef} → 4.7 でウェイトが引き継がれている');
          } else {
            // 4.3.1: 配置状態が指定されるのは一部の領域だけ。
            expect(landed.orientation, isNull,
                reason: '★${from.ruleRef} → ${to.ruleRef} で向きが残っている');
          }
        }
      }
    });

    test('★実害の再現: ウェイトのエネルギーを控え室へ移すと縦向きに戻る', () {
      final start = _with(Zone.energyField,
          [_on('x', cardNumber: 'E1', orientation: CardOrientation.wait)]);
      // ★先に「動かす前は横向き」を確かめる。そうでなければ何も証明しない。
      expect(cardsIn(start, 'A', Zone.energyField).single.orientation,
          CardOrientation.wait);

      final moved = _move(start, Zone.energyField, Zone.waitingRoom);
      expect(cardsIn(moved, 'A', Zone.waitingRoom).single.orientation, isNull,
          reason: '★4.12 に向きの規定は無い（4.3.1）');
    });

    test('★対: 手札から 4.7 へ置くとアクティブ状態が立つ（null のままではない）', () {
      // 4.3.2「どの状態も持たなかったりすることはありません」= 4.7 では null 禁止。
      final start = _with(Zone.hand, [_on('x', cardNumber: 'E1')]);
      expect(cardsIn(start, 'A', Zone.hand).single.orientation, isNull,
          reason: '★4.11 は向きを持たない');

      final moved = _move(start, Zone.hand, Zone.energyField);
      expect(cardsIn(moved, 'A', Zone.energyField).single.orientation,
          CardOrientation.active);
    });

    test('★対: 置いたあとの 5.2.1 は効く（4.3.2.3 は既定であって固定ではない）', () {
      final start = _with(Zone.hand, [_on('x', cardNumber: 'E1')]);
      final moved = _move(start, Zone.hand, Zone.energyField);
      final waited = reduce(
        moved,
        const SetOrientation(
          instanceId: 'x',
          playerId: 'A',
          zone: Zone.energyField,
          orientation: CardOrientation.wait,
        ),
        context: _ctx(),
      );

      expect(cardsIn(waited, 'A', Zone.energyField).single.orientation,
          CardOrientation.wait);
    });
  });

  group('★★ 4.10.2 — 成功ライブカード置き場は置き場所まで定まっている ★★', () {
    // 4.10.2「この領域にカードが置かれる場合、これまでに置かれているカードの
    //   上に置かれます」★Zone.isOrdered が捉えているのは 1 文目だけ。
    test('★★ core が要求を握り潰す（UI を通さなくても一番上に入る）★★', () {
      var s = _with(Zone.successLive, [_on('a'), _on('b')]);
      s = replaceZone(s, 'A', Zone.hand, [_on('x')]);

      final moved = reduce(
        s,
        const MoveCard(
          instanceId: 'x',
          fromPlayerId: 'A',
          from: Zone.hand,
          toPlayerId: 'A',
          to: Zone.successLive,
          // ★呼び出し側が「一番下」を要求しても 4.10.2 が優先する。
          position: ZonePosition.bottom,
        ),
        context: _ctx(),
      );

      expect(
          cardsIn(moved, 'A', Zone.successLive).map((c) => c.instanceId),
          ['x', 'a', 'b'],
          reason: '★4.10.2: これまでに置かれているカードの上');
    });

    test('★対: 4.8 メインデッキでは要求が通る（4.10.2 は 4.10 だけの規定）', () {
      // ★「順番が管理される領域では常に上」という実装だとここで落ちる。
      //   4.8.2 に置き場所の文は無く、5.6.1 と 10.2.3 が処理ごとに定める。
      var s = _with(Zone.mainDeck, [_on('a', face: FaceState.faceDown)]);
      s = replaceZone(s, 'A', Zone.hand, [_on('x', face: FaceState.faceDown)]);

      final moved = reduce(
        s,
        const MoveCard(
          instanceId: 'x',
          fromPlayerId: 'A',
          from: Zone.hand,
          toPlayerId: 'A',
          to: Zone.mainDeck,
          position: ZonePosition.bottom,
        ),
        context: _ctx(),
      );

      expect(cardsIn(moved, 'A', Zone.mainDeck).map((c) => c.instanceId),
          ['a', 'x']);
    });

    test('★取り出すときの規定は無いので、出す側は握り潰さない', () {
      // ★4.10 に取り出しの条文は無い（1.2.1.1 が数え、8.4.7 が入れるだけ）。
      //   出す操作は素通しでよい。
      var s = _with(Zone.successLive, [_on('x'), _on('a')]);
      s = _move(s, Zone.successLive, Zone.waitingRoom);

      expect(cardsIn(s, 'A', Zone.successLive).map((c) => c.instanceId), ['a']);
      expect(cardsIn(s, 'A', Zone.waitingRoom), hasLength(1));
    });
  });

  group('★★ placedIn が受け付けない領域 ★★', () {
    test('メンバーエリアは専用経路が持つ (4.5.4 / 4.5.5.2)', () {
      expect(() => placedIn(_on('x'), Zone.memberArea), throwsArgumentError);
    });

    test('ステージは実体を持たない (4.4.1)', () {
      expect(() => placedIn(_on('x'), Zone.stage), throwsArgumentError);
    });
  });
}
