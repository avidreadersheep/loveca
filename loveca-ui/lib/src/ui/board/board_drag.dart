/// 盤面のドラッグの型と写像（決定 D85 / D46 / D47 / 盤面設計メモ §6-5）.
///
/// ★★ ここは Flutter の描画に触れない ★★
/// 「どこから掴んで、どこへ落としたら、どの [GameAction] になるか」だけを持つ。
/// 画面（`board_drop.dart` / `board_layout.dart`）はこの答えを
/// `GameStore.dispatch` へ渡すだけで、**自分で [GameAction] を組まない**。
/// 分けてある理由は、写像を**表として単体テストできる**ようにするため
/// （ウィジェットテストで 4×4 の組み合わせを回すと、落ちたときに
/// 写像の誤りか描画の誤りかを切り分けられない）。
///
/// ★★ [Zone] と [OutOfRuleZone] を 1 つの型に畳んでいない ★★
/// 畳んだのは「掴んだ札の**出どころ**」であって領域そのものではない。
/// [BoardDrag] の各枝は具体型（[Zone] / [OutOfRuleZone] / [MemberAreaSlot]）のまま
/// [GameAction] を組む。3a-1 §4.1 の拘束
/// 「移動関数は [Zone] を受ける。`dynamic` / `Object` / 共通親型を引数に取らない」は
/// **落とす先の側**でも守ってあり、宛先の種類ごとに関数を分けてある
/// （[moveToZone] / [moveToMemberSlot] / [moveToResolution] / [moveToOutOfRule]）。
///
/// ★★ 拒否は必ず理由を持つ（[MoveRefused]）★★
/// `CardDropTarget.accepts` で弾くと乗っている表示すら出ないので
/// 「落ちたのに何も起きない」になる。受け取ってから理由を出す。
/// R3 の `addCardWithFeedback`（`ui/deck/deck_pane.dart`）と同じ形。
library;

import 'package:loveca_core/loveca_core.dart';

import '../common/card_drag.dart';

// ===========================================================================
// 掴む側
// ===========================================================================

/// 盤面で掴んだ 1 枚と、その出どころ。
///
/// ★★ 下に重ねられたカード（`MemberStack.beneath`）と
///     孤児（`MemberArea.orphans`）は掴ませない ★★
///   それらを動かす [GameAction] は [DetachFromMember] しか無く、
///   **落とす先を持たないドラッグ**を作ることになる。剥がすのはメニュー
///   （`board_card_menu.dart`）であり、解消は 10.5.3 / 10.5.4 のルール処理（M-B5）。
sealed class BoardDrag {
  const BoardDrag();

  /// 掴んだ 1 枚。
  CardInstance get card;
}

/// 総合ルール 4 章の領域から掴んだ（4.6 / 4.7 / 4.10 / 4.11 / 4.12 / 4.13）。
///
/// ★4.8 / 4.9 は非公開領域（D77）なので札そのものを描かない。ここには現れない。
final class ZoneCardDrag extends BoardDrag {
  const ZoneCardDrag({
    required this.playerId,
    required this.zone,
    required this.card,
  });

  final String playerId;
  final Zone zone;

  @override
  final CardInstance card;
}

/// 共有の解決領域から掴んだ。総合ルール 4.14.1。
///
/// ★playerId を持たない。4.14.1 により両プレイヤー共有で 1 つだけ存在する。
final class ResolutionCardDrag extends BoardDrag {
  const ResolutionCardDrag({required this.card});

  @override
  final CardInstance card;
}

/// メンバーエリアの**束の一番上のメンバー**を掴んだ。総合ルール 4.5.5.3。
final class MemberCardDrag extends BoardDrag {
  const MemberCardDrag({
    required this.playerId,
    required this.slot,
    required this.card,
  });

  final String playerId;
  final MemberAreaSlot slot;

  @override
  final CardInstance card;
}

/// ルール外の置き場から掴んだ。★総合ルール 4 章の領域ではない。
final class OutOfRuleCardDrag extends BoardDrag {
  const OutOfRuleCardDrag({
    required this.playerId,
    required this.zone,
    required this.card,
  });

  final String playerId;
  final OutOfRuleZone zone;

  @override
  final CardInstance card;
}

// ===========================================================================
// 写像の答え
// ===========================================================================

/// 「ここへ落としたらどうなるか」。
sealed class BoardMove {
  const BoardMove();
}

/// そのまま `GameStore.dispatch` へ渡す。
final class MoveAction extends BoardMove {
  const MoveAction(this.action);

  final GameAction action;
}

/// ★★ どのメンバーの下に置くかを選ばせる（総合ルール 4.5.5 / 5.10.1）★★
///
/// [StackUnderMember] は `memberInstanceId` を要る。
/// メンバーが 2 人以上いるエリア（10.4 待ちの正規の中間状態）では
/// **2 択では足りない**ので、落とした先で選ばせる。
/// ★**黙って末尾のメンバーの下に入れない。**
final class NeedsMemberChoice extends BoardMove {
  const NeedsMemberChoice({
    required this.instanceId,
    required this.playerId,
    required this.from,
    required this.slot,
    required this.candidates,
  });

  final String instanceId;
  final String playerId;

  /// 重ねる前にカードがあった領域。5.10.1 のエネルギーならエネルギー置き場。
  final Zone from;

  final MemberAreaSlot slot;

  /// そのエリアにいるメンバー。★リスト順は配置順（`member_area.dart` の規約）。
  final List<CardInstance> candidates;

  /// 選ばれたメンバーで [StackUnderMember] を組む。
  StackUnderMember withMember(String memberInstanceId) => StackUnderMember(
        instanceId: instanceId,
        playerId: playerId,
        from: from,
        slot: slot,
        memberInstanceId: memberInstanceId,
      );
}

/// 落とせない。★理由を必ず持つ（黙って何も起きない形にしない）。
final class MoveRefused extends BoardMove {
  const MoveRefused(this.reason);

  final String reason;
}

/// 同じ場所へ落とした。★何も起きないのが自明なので理由を出さない。
final class MoveIgnored extends BoardMove {
  const MoveIgnored();
}

// ===========================================================================
// 写像 — ★宛先の種類ごとに関数を分ける
// ===========================================================================

/// 総合ルール 4 章の領域へ落とす。
///
/// ★[to] に [Zone.memberArea] / [Zone.stage] / [Zone.resolution] は渡せない。
///   それぞれ [moveToMemberSlot] /（実体が無い）/ [moveToResolution] が受け持つ。
///
/// ★[edge] が意味を持つのは **`to.isOrdered == true` のときだけ**
///   （4.8.2 メインデッキ置き場 / 4.10.2 成功ライブカード置き場）。
///   4.1.3 により他の領域では順番が管理されないので観測差が出ない。
BoardMove moveToZone(
  BoardDrag from, {
  required String toPlayerId,
  required Zone to,
  required DropEdge edge,
}) {
  assert(
    to != Zone.memberArea && to != Zone.stage && to != Zone.resolution,
    '${to.name} は moveToZone の宛先にならない（専用の関数がある）',
  );

  final position = to.isOrdered == true
      ? (edge == DropEdge.leading ? ZonePosition.top : ZonePosition.bottom)
      : ZonePosition.top;

  switch (from) {
    case ZoneCardDrag(:final playerId, :final zone, :final card):
      if (playerId == toPlayerId && zone == to) return const MoveIgnored();
      final refusal = _ownerRefusal(card, toPlayerId, to);
      if (refusal != null) return MoveRefused(refusal);
      return MoveAction(MoveCard(
        instanceId: card.instanceId,
        fromPlayerId: playerId,
        from: zone,
        toPlayerId: toPlayerId,
        to: to,
        position: position,
      ));

    case ResolutionCardDrag(:final card):
      final refusal = _ownerRefusal(card, toPlayerId, to);
      if (refusal != null) return MoveRefused(refusal);
      return MoveAction(MoveFromResolution(
        instanceId: card.instanceId,
        toPlayerId: toPlayerId,
        to: to,
        position: position,
      ));

    case MemberCardDrag(:final playerId, :final slot, :final card):
      final refusal = _ownerRefusal(card, toPlayerId, to);
      if (refusal != null) return MoveRefused(refusal);
      // ★4.5.5.4: メンバーカードのみが移動し、下のカードはエリアに残る（孤児）。
      return MoveAction(MoveMemberOut(
        instanceId: card.instanceId,
        playerId: playerId,
        slot: slot,
        toPlayerId: toPlayerId,
        to: to,
        position: position,
      ));

    case OutOfRuleCardDrag(:final playerId, :final zone, :final card):
      if (playerId != toPlayerId) return const MoveRefused(_crossPlayerOutOfRule);
      return MoveAction(MoveFromOutOfRule(
        instanceId: card.instanceId,
        playerId: playerId,
        from: zone,
        to: to,
        position: position,
      ));
  }
}

/// メンバーエリアのスロットへ落とす。総合ルール 4.5。
///
/// ★★ [edge] の上下は「順番」ではない ★★
///   4.5.3 はメンバーエリアの順番を管理しないと定める。ここの上下は
///   **4.5.1（置く）と 4.5.5 / 5.10.1（下に置く）の撃ち分け**である。
///   同じ見た目の帯に 2 つの意味があるので、呼び出し側の文言でも区別すること。
///
/// ★[area] はそのスロットの現状。「下に置く」先を数えるために要る。
BoardMove moveToMemberSlot(
  BoardDrag from, {
  required String playerId,
  required MemberAreaSlot slot,
  required DropEdge edge,
  required MemberArea area,
}) {
  switch (from) {
    case ZoneCardDrag(playerId: final fromPlayerId, :final zone, :final card):
      if (fromPlayerId != playerId) {
        return const MoveRefused('メンバーエリアへ置けるのは自分のカードだけです（4.5.1）。');
      }
      final members = [for (final stack in area.stacks) stack.member];

      // ★メンバーが 1 人もいなければ「下に置く」が成立しない。
      //   上半分・下半分とも 4.5.1 の「置く」になる（＝ 帯を出さない）。
      if (edge == DropEdge.leading || members.isEmpty) {
        return MoveAction(PlaceMemberInArea(
          instanceId: card.instanceId,
          playerId: playerId,
          from: zone,
          slot: slot,
        ));
      }

      if (members.length == 1) {
        return MoveAction(StackUnderMember(
          instanceId: card.instanceId,
          playerId: playerId,
          from: zone,
          slot: slot,
          memberInstanceId: members.single.instanceId,
        ));
      }

      // ★2 人以上いるなら選ばせる。★黙って末尾のメンバーの下に入れない。
      return NeedsMemberChoice(
        instanceId: card.instanceId,
        playerId: playerId,
        from: zone,
        slot: slot,
        candidates: members,
      );

    case MemberCardDrag(
        playerId: final fromPlayerId,
        slot: final fromSlot,
        :final card
      ):
      if (fromPlayerId != playerId) {
        return const MoveRefused('メンバーは自分のメンバーエリアの中でだけ動かせます（4.5.5.3）。');
      }
      if (fromSlot == slot) return const MoveIgnored();
      // ★4.5.5.3: 下に重ねられたカードも束のまま同時に移動する。
      // ★意味が 1 つしかないので、呼び出し側は帯を出さない。
      return MoveAction(MoveMemberBetweenAreas(
        instanceId: card.instanceId,
        playerId: playerId,
        fromSlot: fromSlot,
        toSlot: slot,
      ));

    case ResolutionCardDrag():
      return const MoveRefused(
        '解決領域からメンバーエリアへは直接置けません。'
        'いったん手札などへ戻してから置いてください（4.14.1 / 4.5.1）。',
      );

    case OutOfRuleCardDrag():
      return const MoveRefused(
        '盤の外からメンバーエリアへは直接置けません。'
        'いったん手札などへ戻してから置いてください（4.5.1）。',
      );
  }
}

/// 共有の解決領域へ落とす。総合ルール 4.14.1。
///
/// ★順番は管理されない（4.14.2）ので [DropEdge] を取らない。
BoardMove moveToResolution(BoardDrag from) {
  switch (from) {
    case ZoneCardDrag(:final playerId, :final zone, :final card):
      return MoveAction(MoveToResolution(
        instanceId: card.instanceId,
        fromPlayerId: playerId,
        from: zone,
      ));

    case ResolutionCardDrag():
      return const MoveIgnored();

    case MemberCardDrag():
      return const MoveRefused(
        'メンバーエリアから解決領域へは直接移せません。'
        'いったん手札などへ出してから移してください（4.5.5.4 / 4.14.1）。',
      );

    case OutOfRuleCardDrag():
      return const MoveRefused(
        '盤の外から解決領域へは直接移せません。'
        'いったん手札などへ戻してから移してください（4.14.1）。',
      );
  }
}

/// ルール外の置き場へ落とす。★総合ルール 4 章の領域ではない。
///
/// ★[Zone] を受ける [moveToZone] と**別の関数**にしてある（3a-1 §4.1）。
/// 混ぜると 4.1.7 や 4.1.4 をルール外の置き場へ適用してしまう。
BoardMove moveToOutOfRule(
  BoardDrag from, {
  required String playerId,
  required OutOfRuleZone to,
}) {
  switch (from) {
    case ZoneCardDrag(playerId: final fromPlayerId, :final zone, :final card):
      if (fromPlayerId != playerId) return const MoveRefused(_crossPlayerOutOfRule);
      return MoveAction(MoveOutOfRule(
        instanceId: card.instanceId,
        playerId: playerId,
        from: zone,
        to: to,
      ));

    case OutOfRuleCardDrag(playerId: final fromPlayerId, zone: final fromZone):
      if (fromPlayerId == playerId && fromZone == to) return const MoveIgnored();
      return const MoveRefused(
        '盤の外どうしの移動はできません。いったん手札などへ戻してから出してください。',
      );

    case ResolutionCardDrag():
      return const MoveRefused(
        '解決領域から盤の外へは直接移せません。'
        'いったん手札などへ戻してから出してください（4.14.1）。',
      );

    case MemberCardDrag():
      return const MoveRefused(
        'メンバーエリアから盤の外へは直接移せません。'
        'いったん手札などへ出してから移してください（4.5.5.4）。',
      );
  }
}

const String _crossPlayerOutOfRule =
    '盤の外の置き場はプレイヤーごとに分かれています。自分のカードは自分の側へ出してください。';

/// 総合ルール 4.1.7 の確認。
///
/// 「あるカードがメンバーエリアやライブカード置き場**以外**の領域に移動する場合、
///  そのカードのオーナーに属する領域に移動します」
///
/// ★★ これは盤の不変条件であって、効果の中の制約ではない ★★
///   盤面設計メモ §3-4 が「素のドラッグに課すな」と言ったのは
///   11.10.2 / 11.11.2（**その効果の中での制約**）である。混同しないこと。
String? _ownerRefusal(CardInstance card, String toPlayerId, Zone to) {
  if (to == Zone.liveStage) return null;
  if (card.ownerId == toPlayerId) return null;
  return '4.1.7 により、このカードはオーナーの領域へ移動します。相手の${to.ruleRef}へは置けません。';
}
