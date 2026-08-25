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
///   （`board_card_menu.dart`）であり、解消は 10.5.3 / 10.5.4 のルール処理（M-B6）。
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

/// ★★ 2 つ以上の [GameAction] で 1 操作を表す（M-B5 / 決定 D78 / 盤面設計メモ §7-3）★★
///
/// ★★ なぜ要るのか — 条文ではなく型の都合である ★★
/// メンバーエリア / 解決領域 / 盤の外のあいだの移動には、直接動かす [GameAction] が無い。
///
/// - [MoveOutOfRule.from] は [Zone] なので、`Zone.memberArea` を渡せない
///   （`cardsIn(Zone.memberArea)` が例外を投げる）
/// - [PlaceMemberInArea.from] も [Zone] なので、[OutOfRuleZone] や解決領域から置けない
///
/// ★★ 条文はこれらの移動を禁じていない ★★（M-B5 で PDF と突き合わせて確認した）
///
/// | 条 | 内容 | 直接移動を禁じるか |
/// |---|---|---|
/// | 4.5.5.4 | メンバーが**メンバーエリア以外の領域に移動する場合**、そのメンバーカードのみが移動します | ✗ 移動を前提にしている |
/// | 4.14.1 / 4.14.2 | 解決領域は共有・公開領域で、順番は管理されません | ✗ 出入りの経路を定めていない |
/// | 4.5.1 | プレイしたメンバーカードを置く領域です | ✗ 移動元を限定していない |
/// | 4.1.4 | メンバーエリア間・ライブカード置き場間以外の移動では新しいカードとみなされます | ★中継すると 2 回起きるが、効果を自動処理しない（D-A）以上**観測できる差は無い** |
///
/// → **手札を中継して合成する。**★4.1.7 は残す（中継先は必ずオーナー自身の手札）。
///
/// ★★ M-B5 以前は 2 操作だった ★★
/// 「いったん手札などへ戻してから」と拒否し、プレイヤーが自分で 2 回ドラッグしていた。
/// **戻すのにも 2 回の undo が要った。**いまは 1 操作 = 履歴 1 件 = 1 undo である。
final class MoveActions extends BoardMove {
  const MoveActions(this.actions);

  /// ★順に `reduce` へ通す。`GameStore.dispatchAll` が **`record` を 1 回だけ**呼ぶ。
  final List<GameAction> actions;
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
    this.before = const [],
  });

  final String instanceId;
  final String playerId;

  /// ★★ 選ばせる前に通す合成の前半（M-B5 / [MoveActions] と同じ理由）★★
  /// 解決領域 / 盤の外から「下に置く」に落ちたときは、手札への中継が先に要る。
  /// ★空でなければ `dispatchAll` で**まとめて 1 操作**にする。
  final List<GameAction> before;

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
      if (fromPlayerId != playerId) return const MoveRefused(_notOwnMemberArea);
      return _intoMemberSlot(
        card: card,
        playerId: playerId,
        from: zone,
        slot: slot,
        edge: edge,
        area: area,
        before: const [],
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

    // ★★ 手札を中継して合成する（M-B5 / [MoveActions]）★★
    case ResolutionCardDrag(:final card):
      if (card.ownerId != playerId) return const MoveRefused(_notOwnMemberArea);
      return _intoMemberSlot(
        card: card,
        playerId: playerId,
        from: _relayZone,
        slot: slot,
        edge: edge,
        area: area,
        before: [
          MoveFromResolution(
            instanceId: card.instanceId,
            toPlayerId: playerId,
            to: _relayZone,
          ),
        ],
      );

    case OutOfRuleCardDrag(
        playerId: final fromPlayerId,
        zone: final fromZone,
        :final card
      ):
      if (fromPlayerId != playerId) return const MoveRefused(_notOwnMemberArea);
      return _intoMemberSlot(
        card: card,
        playerId: playerId,
        from: _relayZone,
        slot: slot,
        edge: edge,
        area: area,
        before: [
          MoveFromOutOfRule(
            instanceId: card.instanceId,
            playerId: playerId,
            from: fromZone,
            to: _relayZone,
          ),
        ],
      );
  }
}

/// [moveToMemberSlot] の後半（4.5.1「置く」と 4.5.5 / 5.10.1「下に置く」の撃ち分け）。
///
/// ★[before] が空でなければ手札を中継する合成になる（M-B5 / [MoveActions]）。
///   ★**撃ち分けの規則は 1 か所に置く。**中継の有無で分岐を書き分けると必ず食い違う。
BoardMove _intoMemberSlot({
  required CardInstance card,
  required String playerId,
  required Zone from,
  required MemberAreaSlot slot,
  required DropEdge edge,
  required MemberArea area,
  required List<GameAction> before,
}) {
  final members = [for (final stack in area.stacks) stack.member];

  // ★メンバーが 1 人もいなければ「下に置く」が成立しない。
  //   上半分・下半分とも 4.5.1 の「置く」になる（＝ 帯を出さない）。
  if (edge == DropEdge.leading || members.isEmpty) {
    return _composed(
      before,
      PlaceMemberInArea(
        instanceId: card.instanceId,
        playerId: playerId,
        from: from,
        slot: slot,
      ),
    );
  }

  if (members.length == 1) {
    return _composed(
      before,
      StackUnderMember(
        instanceId: card.instanceId,
        playerId: playerId,
        from: from,
        slot: slot,
        memberInstanceId: members.single.instanceId,
      ),
    );
  }

  // ★2 人以上いるなら選ばせる。★黙って末尾のメンバーの下に入れない。
  return NeedsMemberChoice(
    instanceId: card.instanceId,
    playerId: playerId,
    from: from,
    slot: slot,
    candidates: members,
    before: before,
  );
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

    // ★★ 手札を中継して合成する（M-B5 / [MoveActions]）★★
    case MemberCardDrag(:final playerId, :final slot, :final card):
      return MoveActions([
        // ★4.5.5.4: メンバーカードのみが移動し、下のカードはエリアに残る（孤児）。
        MoveMemberOut(
          instanceId: card.instanceId,
          playerId: playerId,
          slot: slot,
          toPlayerId: playerId,
          to: _relayZone,
        ),
        MoveToResolution(
          instanceId: card.instanceId,
          fromPlayerId: playerId,
          from: _relayZone,
        ),
      ]);

    case OutOfRuleCardDrag(:final playerId, :final zone, :final card):
      return MoveActions([
        MoveFromOutOfRule(
          instanceId: card.instanceId,
          playerId: playerId,
          from: zone,
          to: _relayZone,
        ),
        MoveToResolution(
          instanceId: card.instanceId,
          fromPlayerId: playerId,
          from: _relayZone,
        ),
      ]);
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

    // ★★ ここから下は手札を中継して合成する（M-B5 / [MoveActions]）★★
    case OutOfRuleCardDrag(
        playerId: final fromPlayerId,
        zone: final fromZone,
        :final card
      ):
      if (fromPlayerId != playerId) return const MoveRefused(_crossPlayerOutOfRule);
      if (fromZone == to) return const MoveIgnored();
      return MoveActions([
        MoveFromOutOfRule(
          instanceId: card.instanceId,
          playerId: playerId,
          from: fromZone,
          to: _relayZone,
        ),
        MoveOutOfRule(
          instanceId: card.instanceId,
          playerId: playerId,
          from: _relayZone,
          to: to,
        ),
      ]);

    case ResolutionCardDrag(:final card):
      if (card.ownerId != playerId) return const MoveRefused(_crossPlayerOutOfRule);
      return MoveActions([
        MoveFromResolution(
          instanceId: card.instanceId,
          toPlayerId: playerId,
          to: _relayZone,
        ),
        MoveOutOfRule(
          instanceId: card.instanceId,
          playerId: playerId,
          from: _relayZone,
          to: to,
        ),
      ]);

    case MemberCardDrag(playerId: final fromPlayerId, :final slot, :final card):
      if (fromPlayerId != playerId) return const MoveRefused(_crossPlayerOutOfRule);
      return MoveActions([
        // ★4.5.5.4: メンバーカードのみが移動し、下のカードはエリアに残る（孤児）。
        MoveMemberOut(
          instanceId: card.instanceId,
          playerId: playerId,
          slot: slot,
          toPlayerId: playerId,
          to: _relayZone,
        ),
        MoveOutOfRule(
          instanceId: card.instanceId,
          playerId: playerId,
          from: _relayZone,
          to: to,
        ),
      ]);
  }
}

const String _crossPlayerOutOfRule =
    '盤の外の置き場はプレイヤーごとに分かれています。自分のカードは自分の側へ出してください。';

const String _notOwnMemberArea = 'メンバーエリアへ置けるのは自分のカードだけです（4.5.1）。';

/// ★★ 合成で中継する領域（M-B5 / 盤面設計メモ §7-3）★★
///
/// ★4.1.7 により、中継先は**必ずオーナー自身の**手札である。
/// ★4.11.2（手札は自分のみが確認できる）に触れない —— 中間状態は履歴にも画面にも
/// 現れない（`GameStore.dispatchAll` が `record` を 1 回しか呼ばないため）。
const Zone _relayZone = Zone.hand;

/// 合成が要るときだけ [MoveActions] にする。
///
/// ★★ 中継が無いときに [MoveActions] へ包まない ★★
/// 単発のドラッグまで合成の形にすると、`GameStore.dispatch` の 1 件版が
/// 使われなくなり、**「1 操作 = 1 履歴」の検査が合成の検査と混ざる。**
BoardMove _composed(List<GameAction> before, GameAction action) =>
    before.isEmpty ? MoveAction(action) : MoveActions([...before, action]);

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
