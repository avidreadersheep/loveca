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

      test('4.10 成功ライブ: 同じ', () {
        expect(Zone.successLive.isOrdered, isTrue, reason: '★前提（4.10.2）');
        expect(positionOf(Zone.successLive, DropEdge.leading), ZonePosition.top);
        expect(
            positionOf(Zone.successLive, DropEdge.trailing), ZonePosition.bottom);
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

    test('★解決領域 / 盤の外からは直接置けない（2 段になるため）', () {
      for (final from in <BoardDrag>[
        ResolutionCardDrag(card: _card('a')),
        OutOfRuleCardDrag(
          playerId: _self,
          zone: OutOfRuleZone.freeArea,
          card: _card('a'),
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

    test('★メンバー / 盤の外からは拒否（理由が出る）', () {
      for (final from in <BoardDrag>[
        MemberCardDrag(
            playerId: _self, slot: MemberAreaSlot.center, card: _card('a')),
        OutOfRuleCardDrag(
            playerId: _self, zone: OutOfRuleZone.freeArea, card: _card('a')),
      ]) {
        expect((moveToResolution(from) as MoveRefused).reason, isNotEmpty);
      }
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

    test('★同じ置き場なら無視 / ★対 別の置き場どうしは拒否', () {
      final drag = OutOfRuleCardDrag(
        playerId: _self,
        zone: OutOfRuleZone.freeArea,
        card: _card('a'),
      );

      expect(
        moveToOutOfRule(drag, playerId: _self, to: OutOfRuleZone.freeArea),
        isA<MoveIgnored>(),
      );
      expect(
        moveToOutOfRule(drag, playerId: _self, to: OutOfRuleZone.mulliganAside),
        isA<MoveRefused>(),
      );
    });
  });
}
