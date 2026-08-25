/// 掴んだ場所 × 落とした場所 → `GameAction` の写像（決定 D85）.
///
/// ★★ ここが写像の正である ★★
/// 画面のテスト（`board_drag_test.dart`）は「掴めること・帯が出ること」を見る。
/// **どの `GameAction` になるか**はここで表として固定する。
/// 混ぜると、落ちたときに写像の誤りか描画の誤りかを切り分けられない。
///
/// ★★ 拒否と無視も固定する ★★
/// 出る側だけを見ると「何でも受け取る実装」でも通る。
/// **拒否には理由があること**、**同じ場所へ落としたら黙って何もしないこと**を対で見る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/ui/board/board_drag.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';

const _self = 'self';
const _opponent = 'opponent';

CardInstance _card(String id, {String owner = _self}) => CardInstance(
      instanceId: id,
      printingId: 'P-$id',
      cardNumber: 'C-$id',
      ownerId: owner,
    );

MemberArea _area({
  MemberAreaSlot slot = MemberAreaSlot.center,
  List<CardInstance> members = const [],
}) =>
    MemberArea(
      slot: slot,
      stacks: [for (final m in members) MemberStack(member: m)],
    );

void main() {
  group('★★ moveToZone — 4 章の領域へ ★★', () {
    test('領域から領域へ = MoveCard', () {
      final move = moveToZone(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        toPlayerId: _self,
        to: Zone.waitingRoom,
        edge: DropEdge.leading,
      );

      final action = (move as MoveAction).action as MoveCard;
      expect(action.instanceId, 'a');
      expect(action.from, Zone.hand);
      expect(action.to, Zone.waitingRoom);
    });

    test('★同じ場所へ落としたら無視（理由も出さない）', () {
      final move = moveToZone(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        toPlayerId: _self,
        to: Zone.hand,
        edge: DropEdge.leading,
      );

      expect(move, isA<MoveIgnored>());
    });

    group('★★ 順番が管理される領域でだけ position が動く（4.1.3 / 4.8.2 / 4.10.2）★★', () {
      /// ★[from] は「落とす先と必ず違う領域」にすること。
      ///   同じにすると `MoveIgnored` になり、position を見る前に落ちる。
      ZonePosition positionOf(Zone to, DropEdge edge, {Zone from = Zone.hand}) {
        final move = moveToZone(
          ZoneCardDrag(playerId: _self, zone: from, card: _card('a')),
          toPlayerId: _self,
          to: to,
          edge: edge,
        );
        return ((move as MoveAction).action as MoveCard).position;
      }

      test('4.8 メインデッキ: 上半分 = top / 下半分 = bottom', () {
        expect(Zone.mainDeck.isOrdered, isTrue, reason: '★前提（4.8.2）');
        expect(positionOf(Zone.mainDeck, DropEdge.leading), ZonePosition.top);
        expect(positionOf(Zone.mainDeck, DropEdge.trailing), ZonePosition.bottom);
      });

      // ★★ ここには「4.10 成功ライブ: 同じ」という試験があった（〜2026-08-25）★★
      //   守っていたのは**このグループ名のとおり 4.1.3**（順番を管理しない領域で
      //   position が動かないこと）であって、4.10.2 の置き場所の規定ではない。
      //   `Zone.isOrdered` から機械的に導いた答えを写しただけだった。
      //   ★4.1.3 のぶんは 4.8 の試験と下の「対」が引き続き守る。
      //   経緯は `docs/決定事項一覧.md` **D91**。
      test('★★ 4.10 成功ライブ: どちらの端でも一番上（4.10.2）★★', () {
        expect(Zone.successLive.isOrdered, isTrue, reason: '★前提（4.10.2 の 1 文目）');
        // 4.10.2「この領域にカードが置かれる場合、これまでに置かれているカードの
        //   上に置かれます」= プレイヤーに選ばせない。
        expect(positionOf(Zone.successLive, DropEdge.leading), ZonePosition.top);
        expect(positionOf(Zone.successLive, DropEdge.trailing), ZonePosition.top,
            reason: '★下半分に落としても一番上（4.10.2）');
      });

      test('★対: 4.8 では要求が握り潰されない（4.10.2 は 4.10 だけの規定）', () {
        // ★「順番が管理される領域では常に上」という実装だとここで落ちる。
        //   4.8.2 に置き場所の文は無く、5.6.1 と 10.2.3 が処理ごとに定める。
        expect(positionIn(Zone.mainDeck, ZonePosition.bottom),
            ZonePosition.bottom);
        expect(positionIn(Zone.successLive, ZonePosition.bottom),
            ZonePosition.top);
      });

      test('★対: 順番を管理しない領域では下半分でも top のまま', () {
        // ★観測差が出ないので値そのものに意味は無いが、
        //   「帯を出していないのに位置が動く」実装になっていないことを見る。
        for (final zone in [
          Zone.hand,
          Zone.waitingRoom,
          Zone.exile,
          Zone.liveStage,
          Zone.energyField,
          Zone.energyDeck,
        ]) {
          expect(zone.isOrdered, isFalse, reason: '★前提（4.1.3）: ${zone.ruleRef}');
          expect(
              // ★4.10 は順番が管理されるので、出どころとして使えば必ず別領域になる。
              positionOf(zone, DropEdge.trailing, from: Zone.successLive),
              ZonePosition.top,
              reason: '★${zone.ruleRef} で位置が動いている');
        }
      });
    });

    test('★4.1.7: オーナー以外の領域へは落とせない（理由が出る）', () {
      final move = moveToZone(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        toPlayerId: _opponent,
        to: Zone.waitingRoom,
        edge: DropEdge.leading,
      );

      expect((move as MoveRefused).reason, contains('4.1.7'));
    });

    test('★対: ライブカード置き場（4.6）だけは相手側へ置ける（4.1.7 の除外）', () {
      final move = moveToZone(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        toPlayerId: _opponent,
        to: Zone.liveStage,
        edge: DropEdge.leading,
      );

      expect(((move as MoveAction).action as MoveCard).toPlayerId, _opponent);
    });

    test('解決領域から領域へ = MoveFromResolution', () {
      final move = moveToZone(
        ResolutionCardDrag(card: _card('a')),
        toPlayerId: _self,
        to: Zone.waitingRoom,
        edge: DropEdge.leading,
      );

      expect(((move as MoveAction).action as MoveFromResolution).instanceId, 'a');
    });

    test('メンバーから領域へ = MoveMemberOut（4.5.5.4）', () {
      final move = moveToZone(
        MemberCardDrag(
          playerId: _self,
          slot: MemberAreaSlot.center,
          card: _card('a'),
        ),
        toPlayerId: _self,
        to: Zone.waitingRoom,
        edge: DropEdge.leading,
      );

      final action = (move as MoveAction).action as MoveMemberOut;
      expect(action.slot, MemberAreaSlot.center);
      expect(action.to, Zone.waitingRoom);
    });

    test('盤の外から領域へ = MoveFromOutOfRule', () {
      final move = moveToZone(
        OutOfRuleCardDrag(
          playerId: _self,
          zone: OutOfRuleZone.freeArea,
          card: _card('a'),
        ),
        toPlayerId: _self,
        to: Zone.hand,
        edge: DropEdge.leading,
      );

      final action = (move as MoveAction).action as MoveFromOutOfRule;
      expect(action.from, OutOfRuleZone.freeArea);
      expect(action.to, Zone.hand);
    });
  });

  group('★★ moveToMemberSlot — 上半分 / 下半分（4.5.1 と 4.5.5）★★', () {
    BoardMove drop(DropEdge edge, {List<CardInstance> members = const []}) =>
        moveToMemberSlot(
          ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
          playerId: _self,
          slot: MemberAreaSlot.center,
          edge: edge,
          area: _area(members: members),
        );

    test('上半分 = PlaceMemberInArea（4.5.1）', () {
      final move = drop(DropEdge.leading, members: [_card('m1')]);
      final action = (move as MoveAction).action as PlaceMemberInArea;
      expect(action.slot, MemberAreaSlot.center);
      expect(action.from, Zone.hand);
    });

    test('下半分 = StackUnderMember（4.5.5 / 5.10.1）', () {
      final move = drop(DropEdge.trailing, members: [_card('m1')]);
      final action = (move as MoveAction).action as StackUnderMember;
      expect(action.memberInstanceId, 'm1');
    });

    test('★★ メンバーが 0 人なら下半分でも「置く」（帯を出す意味が無い）★★', () {
      // ★「下に置く」先が存在しないので 2 通りにならない。
      //   呼び出し側（board_drop.dart）はこの条件で帯を出さない。
      expect((drop(DropEdge.trailing) as MoveAction).action,
          isA<PlaceMemberInArea>());
    });

    test('★★ メンバーが 2 人以上なら選ばせる（黙って末尾に入れない）★★', () {
      final move = drop(DropEdge.trailing, members: [_card('m1'), _card('m2')]);

      final choice = move as NeedsMemberChoice;
      expect([for (final c in choice.candidates) c.instanceId], ['m1', 'm2']);

      // ★選んだメンバーがそのまま memberInstanceId になる。
      expect(choice.withMember('m1').memberInstanceId, 'm1');
      expect(choice.withMember('m2').memberInstanceId, 'm2');
      expect(choice.withMember('m2').from, Zone.hand);
    });

    test('メンバーを別のスロットへ = MoveMemberBetweenAreas（4.5.5.3）', () {
      final move = moveToMemberSlot(
        MemberCardDrag(
          playerId: _self,
          slot: MemberAreaSlot.leftSide,
          card: _card('a'),
        ),
        playerId: _self,
        slot: MemberAreaSlot.center,
        edge: DropEdge.trailing,
        area: _area(members: [_card('m1'), _card('m2')]),
      );

      // ★★ メンバー源では上下で結果が変わらない（意味が 1 つしかない）★★
      //   だから呼び出し側は帯を出さない。
      final action = (move as MoveAction).action as MoveMemberBetweenAreas;
      expect(action.fromSlot, MemberAreaSlot.leftSide);
      expect(action.toSlot, MemberAreaSlot.center);
    });

    test('★同じスロットへ落としたら無視', () {
      final move = moveToMemberSlot(
        MemberCardDrag(
          playerId: _self,
          slot: MemberAreaSlot.center,
          card: _card('a'),
        ),
        playerId: _self,
        slot: MemberAreaSlot.center,
        edge: DropEdge.leading,
        area: _area(),
      );

      expect(move, isA<MoveIgnored>());
    });

    test('★相手のメンバーエリアへは置けない（理由が出る）', () {
      final move = moveToMemberSlot(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        playerId: _opponent,
        slot: MemberAreaSlot.center,
        edge: DropEdge.leading,
        area: _area(),
      );

      expect((move as MoveRefused).reason, contains('4.5.1'));
    });

    // ★★ M-B5 以前は「いったん手札などへ戻してから」と拒否していた ★★
    //   条文は禁じていない（4.5.1 は移動元を限定していない）。**型の都合**だった
    //   （`PlaceMemberInArea.from` が [Zone] なので解決領域 / 盤の外を渡せない）。
    //   → 手札を中継する合成にした。**2 操作が 1 操作 = 1 undo になった。**
    test('★★ 解決領域 / 盤の外からは手札を中継して合成する（M-B5）★★', () {
      final cases = <BoardDrag, Type>{
        ResolutionCardDrag(card: _card('a')): MoveFromResolution,
        OutOfRuleCardDrag(
          playerId: _self,
          zone: OutOfRuleZone.freeArea,
          card: _card('a'),
        ): MoveFromOutOfRule,
      };

      cases.forEach((from, relayType) {
        final move = moveToMemberSlot(
          from,
          playerId: _self,
          slot: MemberAreaSlot.center,
          edge: DropEdge.leading,
          area: _area(),
        );

        final actions = (move as MoveActions).actions;
        expect(actions, hasLength(2), reason: '★中継 1 + 本体 1');
        expect(actions.first.runtimeType, relayType);
        // ★中継先はオーナー自身の手札（4.1.7）。
        expect(_relayTo(actions.first), Zone.hand);
        final place = actions.last as PlaceMemberInArea;
        expect(place.from, Zone.hand);
        expect(place.slot, MemberAreaSlot.center);
      });
    });

    // ★★ 対: オーナーでなければ合成しない（4.5.1）★★
    //   合成で「誰のカードでも置ける」になっていないことを見る。
    test('★対 相手のカードは解決領域 / 盤の外からでも置けない', () {
      for (final from in <BoardDrag>[
        ResolutionCardDrag(card: _card('a', owner: _opponent)),
        OutOfRuleCardDrag(
          playerId: _opponent,
          zone: OutOfRuleZone.freeArea,
          card: _card('a', owner: _opponent),
        ),
      ]) {
        final move = moveToMemberSlot(
          from,
          playerId: _self,
          slot: MemberAreaSlot.center,
          edge: DropEdge.leading,
          area: _area(),
        );
        expect((move as MoveRefused).reason, isNotEmpty);
      }
    });

    // ★★ 中継が要るときも「下に置く」の撃ち分けは同じ（4.5.5 / 5.10.1）★★
    //   撃ち分けを中継の有無で書き分けていないことの検査。
    test('★★ 中継しても下半分は「下に置く」になる ★★', () {
      final single = moveToMemberSlot(
        ResolutionCardDrag(card: _card('a')),
        playerId: _self,
        slot: MemberAreaSlot.center,
        edge: DropEdge.trailing,
        area: _area(members: [_card('m1')]),
      );
      final stack = (single as MoveActions).actions.last as StackUnderMember;
      expect(stack.memberInstanceId, 'm1');
      expect(stack.from, Zone.hand);

      // ★2 人以上なら中継を抱えたまま選ばせる。★黙って末尾に入れない。
      final many = moveToMemberSlot(
        ResolutionCardDrag(card: _card('a')),
        playerId: _self,
        slot: MemberAreaSlot.center,
        edge: DropEdge.trailing,
        area: _area(members: [_card('m1'), _card('m2')]),
      );
      final choice = many as NeedsMemberChoice;
      expect(choice.candidates, hasLength(2));
      expect(choice.before, hasLength(1), reason: '★中継を落とすと札が消える');
      expect(choice.before.single, isA<MoveFromResolution>());
      expect(choice.from, Zone.hand);
    });
  });

  group('★ moveToResolution — 共有 1 本（4.14.1）', () {
    test('領域から = MoveToResolution', () {
      final move = moveToResolution(
        ZoneCardDrag(playerId: _self, zone: Zone.energyField, card: _card('a')),
      );

      final action = (move as MoveAction).action as MoveToResolution;
      expect(action.fromPlayerId, _self);
      expect(action.from, Zone.energyField);
    });

    test('★解決領域から解決領域は無視', () {
      expect(moveToResolution(ResolutionCardDrag(card: _card('a'))),
          isA<MoveIgnored>());
    });

    // ★★ M-B5 以前は拒否だった（「いったん手札などへ出してから」）★★
    //   4.5.5.4 は「メンバーエリア以外の領域に移動する場合」と**移動を前提にしている**。
    //   禁じていたのは条文ではなく型（`MoveToResolution.from` が [Zone]）。
    test('★★ メンバー / 盤の外からは手札を中継して合成する（M-B5）★★', () {
      final cases = <BoardDrag, Type>{
        MemberCardDrag(
                playerId: _self, slot: MemberAreaSlot.center, card: _card('a')):
            MoveMemberOut,
        OutOfRuleCardDrag(
                playerId: _self,
                zone: OutOfRuleZone.freeArea,
                card: _card('a')):
            MoveFromOutOfRule,
      };

      cases.forEach((from, relayType) {
        final actions = (moveToResolution(from) as MoveActions).actions;
        expect(actions, hasLength(2));
        expect(actions.first.runtimeType, relayType);
        expect(_relayTo(actions.first), Zone.hand);
        final into = actions.last as MoveToResolution;
        expect(into.from, Zone.hand);
        expect(into.fromPlayerId, _self);
      });
    });
  });

  group('★ moveToOutOfRule — 4 章の領域ではない置き場', () {
    test('領域から = MoveOutOfRule', () {
      final move = moveToOutOfRule(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        playerId: _self,
        to: OutOfRuleZone.freeArea,
      );

      final action = (move as MoveAction).action as MoveOutOfRule;
      expect(action.from, Zone.hand);
      expect(action.to, OutOfRuleZone.freeArea);
    });

    test('★相手側の置き場へは出せない', () {
      final move = moveToOutOfRule(
        ZoneCardDrag(playerId: _self, zone: Zone.hand, card: _card('a')),
        playerId: _opponent,
        to: OutOfRuleZone.freeArea,
      );

      expect((move as MoveRefused).reason, isNotEmpty);
    });

    test('★同じ置き場なら無視 / ★対 別の置き場どうしは合成（M-B5）', () {
      final drag = OutOfRuleCardDrag(
        playerId: _self,
        zone: OutOfRuleZone.freeArea,
        card: _card('a'),
      );

      expect(
        moveToOutOfRule(drag, playerId: _self, to: OutOfRuleZone.freeArea),
        isA<MoveIgnored>(),
      );

      // ★M-B5 以前は拒否だった。ルール外の置き場を定める条文は無いので、
      //   禁じていたのは型（`MoveOutOfRule.from` が [Zone]）だけである。
      final actions = (moveToOutOfRule(drag,
              playerId: _self, to: OutOfRuleZone.mulliganAside) as MoveActions)
          .actions;
      expect(actions, hasLength(2));
      expect((actions.first as MoveFromOutOfRule).to, Zone.hand);
      final out = actions.last as MoveOutOfRule;
      expect(out.from, Zone.hand);
      expect(out.to, OutOfRuleZone.mulliganAside);
    });

    // ★★ M-B5 で合成にした残り 2 経路（メンバー / 解決領域 → 盤の外）★★
    test('★★ メンバー / 解決領域からは手札を中継して合成する（M-B5）★★', () {
      final cases = <BoardDrag, Type>{
        MemberCardDrag(
                playerId: _self, slot: MemberAreaSlot.center, card: _card('a')):
            MoveMemberOut,
        ResolutionCardDrag(card: _card('a')): MoveFromResolution,
      };

      cases.forEach((from, relayType) {
        final actions = (moveToOutOfRule(from,
                playerId: _self, to: OutOfRuleZone.freeArea) as MoveActions)
            .actions;
        expect(actions, hasLength(2));
        expect(actions.first.runtimeType, relayType);
        expect(_relayTo(actions.first), Zone.hand);
        final out = actions.last as MoveOutOfRule;
        expect(out.from, Zone.hand);
        expect(out.to, OutOfRuleZone.freeArea);
      });
    });

    // ★★ 対: 4.1.7 は合成でも残る ★★
    //   「合成にしたら誰のカードでも盤の外へ出せる」になっていないことを見る。
    test('★対 相手のカードは合成でも自分の盤の外へ出せない', () {
      for (final from in <BoardDrag>[
        MemberCardDrag(
            playerId: _opponent,
            slot: MemberAreaSlot.center,
            card: _card('a', owner: _opponent)),
        ResolutionCardDrag(card: _card('a', owner: _opponent)),
        OutOfRuleCardDrag(
            playerId: _opponent,
            zone: OutOfRuleZone.freeArea,
            card: _card('a', owner: _opponent)),
      ]) {
        final move =
            moveToOutOfRule(from, playerId: _self, to: OutOfRuleZone.freeArea);
        expect((move as MoveRefused).reason, isNotEmpty);
      }
    });
  });
}

/// 合成の前半（中継）が手札へ向いていることを見る。
///
/// ★★ 中継先を型ごとに書き分けない ★★
/// 4 種の中継アクションで `to` の意味は同じなので、1 か所で読む。
Zone? _relayTo(GameAction action) => switch (action) {
      MoveMemberOut(:final to) => to,
      MoveFromResolution(:final to) => to,
      MoveFromOutOfRule(:final to) => to,
      MoveCard(:final to) => to,
      _ => null,
    };
