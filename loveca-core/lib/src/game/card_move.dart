/// 領域間のカード移動.
///
/// 総合ルール 5.4.1「カードを指定領域に'置く'指示がある場合、
/// そのカードをその領域に移動します」
///
/// ★★ 移動関数は [Zone] を受ける ★★
///   `dynamic` / `Object` / [Zone] と [OutOfRuleZone] の共通親型を引数に取らない。
///   ルール外の置き場 (6.2.1.6 の脇置き・フリーエリア) は
///   [OutOfRuleZone] を受ける**別の関数**に分ける。
///   混ぜると 4.1.7 や 4.1.4 をルール外の置き場へ適用してしまう。
///
/// ★★ リストの先頭 (index 0) を「一番上」とする ★★
///   順番が管理されるのはメインデッキ置き場 (4.8.2) と
///   成功ライブカード置き場 (4.10.2) だけ。
///     7.5.2 / 8.3.11 の「一番上のカード」        → index 0
///     10.2.3 の「それらのカードの下に移動」      → 末尾へ追加
///     4.10.2 の「これまでに置かれているカードの上」→ index 0 へ挿入

library;

import 'card_instance.dart';
import 'game_state.dart';
import 'zone.dart';

/// 移動先での置き位置。
///
/// 順番が管理される領域 (4.8.2 メインデッキ置き場 / 4.10.2 成功ライブカード置き場)
/// でのみ意味を持つ。それ以外の領域では順番が管理されない (4.1.3) ため観測差は出ない。
enum ZonePosition {
  /// 一番上 (index 0)。
  top,

  /// 一番下 (末尾)。10.2.3 のリフレッシュが使う。
  bottom,
}

/// [playerId] に属する [zone] のカード。
///
/// ★[Zone.resolution] は受け付けない。
///   4.14.1 により両プレイヤー共有で 1 つだけ存在するため、
///   プレイヤーごとの領域として読むと 8.3.12 (絞らない) と
///   8.3.14 (ownerId で絞る) を取り違える。`GameState.resolution` を直接見ること。
///
/// ★[Zone.memberArea] / [Zone.stage] も受け付けない。
///   メンバーエリアは平坦なリストではなく [MemberArea] の構造を持つ (4.5.5)。
///   ステージ (4.4.1) はその統合ビューで実体を持たない。
List<CardInstance> cardsIn(GameState state, String playerId, Zone zone) {
  final player = state.playerOf(playerId);
  return switch (zone) {
    Zone.hand => player.hand,
    Zone.mainDeck => player.mainDeck,
    Zone.energyDeck => player.energyDeck,
    Zone.energyField => player.energyField,
    Zone.liveStage => player.liveStage,
    Zone.successLive => player.successLive,
    Zone.waitingRoom => player.waitingRoom,
    Zone.exile => player.exile,
    Zone.resolution => throw ArgumentError(
        '解決領域は両プレイヤー共有で 1 つだけ (4.14.1)。GameState.resolution を直接参照する'),
    Zone.memberArea => throw ArgumentError(
        'メンバーエリアは MemberArea の構造を持つ (4.5.5)。PlayerState.memberAreas を使う'),
    Zone.stage => throw ArgumentError(
        'ステージはメンバーエリアの統合ビューで実体を持たない (4.4.1)'),
  };
}

/// [playerId] に属する [zone] のカードを [cards] に差し替える。
GameState replaceZone(
  GameState state,
  String playerId,
  Zone zone,
  List<CardInstance> cards,
) {
  final player = state.playerOf(playerId);
  final updated = switch (zone) {
    Zone.hand => player.copyWith(hand: cards),
    Zone.mainDeck => player.copyWith(mainDeck: cards),
    Zone.energyDeck => player.copyWith(energyDeck: cards),
    Zone.energyField => player.copyWith(energyField: cards),
    Zone.liveStage => player.copyWith(liveStage: cards),
    Zone.successLive => player.copyWith(successLive: cards),
    Zone.waitingRoom => player.copyWith(waitingRoom: cards),
    Zone.exile => player.copyWith(exile: cards),
    Zone.resolution => throw ArgumentError(
        '解決領域は両プレイヤー共有で 1 つだけ (4.14.1)。replaceResolution を使う'),
    Zone.memberArea => throw ArgumentError(
        'メンバーエリアは MemberArea の構造を持つ (4.5.5)'),
    Zone.stage => throw ArgumentError(
        'ステージはメンバーエリアの統合ビューで実体を持たない (4.4.1)'),
  };

  return state.copyWith(
    players: [
      for (final p in state.players) p.playerId == playerId ? updated : p,
    ],
  );
}

/// 共有の解決領域を差し替える。総合ルール 4.14.1。
///
/// ★プレイヤーごとの領域ではないので [replaceZone] とは別の関数にしてある。
GameState replaceResolution(GameState state, List<CardInstance> cards) =>
    state.copyWith(resolution: cards);

/// [playerId] に属するルール外の置き場のカード。
///
/// ★総合ルール 4 章の領域ではない。[cardsIn] とは別の関数。
List<CardInstance> cardsInOutOfRule(
  GameState state,
  String playerId,
  OutOfRuleZone zone,
) {
  final player = state.playerOf(playerId);
  return switch (zone) {
    OutOfRuleZone.mulliganAside => player.mulliganAside,
    OutOfRuleZone.freeArea => player.freeArea,
  };
}

/// [playerId] に属するルール外の置き場を差し替える。
GameState replaceOutOfRuleZone(
  GameState state,
  String playerId,
  OutOfRuleZone zone,
  List<CardInstance> cards,
) {
  final player = state.playerOf(playerId);
  final updated = switch (zone) {
    OutOfRuleZone.mulliganAside => player.copyWith(mulliganAside: cards),
    OutOfRuleZone.freeArea => player.copyWith(freeArea: cards),
  };
  return state.copyWith(
    players: [
      for (final p in state.players) p.playerId == playerId ? updated : p,
    ],
  );
}

/// [zone] へ [cards] を [position] の側から加える。
List<CardInstance> insertInto(
  List<CardInstance> zone,
  List<CardInstance> cards,
  ZonePosition position,
) =>
    switch (position) {
      ZonePosition.top => [...cards, ...zone],
      ZonePosition.bottom => [...zone, ...cards],
    };

/// [zone] に置かれるカードの表示面を、その領域の規定に合わせる。総合ルール 4.1.2.1。
///
/// ★★ 4.1.2.1 は「表示面」を直接には定めない。導出は 2 段である ★★
///   4.1.2.1「公開領域にカードが置かれる場合、そのカードは公開状態 (4.2.2) で
///   置かれます。非公開領域にカードが置かれる場合、そのカードは非公開状態 (4.2.3)
///   で置かれます」
///
///     4.2.2 公開状態   = カードの内容や情報をすべてのプレイヤーが見ることのできる状態
///                        → 4.3.3.1 表向き
///     4.2.3 非公開状態 = 一部または全部のプレイヤーが内容や情報を見ることができない状態
///                        → 4.3.3.2 裏向き
///
///   4.2 は「領域の可視状態」、4.3.3 は「表示面」で**別の軸**である。
///   4.3.3.1 / 4.3.3.2 の「**原則として**」という留保が、
///   領域側の条文による例外 ([Zone.liveStage] / 4.6.2) を許している。
///
/// ★★ 4.6 ライブカード置き場だけは表示面を触らない ★★
///   4.6.2「ライブカード置き場はすべてのプレイヤーに対して公開領域ですが、
///   **カードが一時的に裏向きに置かれることがあります**」= 4.1.2.1 の明示的な例外。
///   8.2.2 / 8.2.4 は手札 (4.11.2 非公開領域 = 裏向き) から置くので、
///   **引き継ぐことがそのまま条文の結果になる**。
///   ★「常に裏向きにする」は採らない。8.3.4 で表向きにした札を出し入れすると
///     裏に戻ってしまい、条文が定めていない挙動になる。
///
/// ★★ 4.13 除外領域は 4.1.2.1 と同じ結論をより直接に定める ★★
///   4.13.2「この領域のカードは表示面の状態を持ちます。特に指示がないかぎり、
///   取り除かれたカードは表向きに置かれます」
///   「特に指示」は効果由来であり、本アプリは効果を自動処理しない (CLAUDE.md §1)。
///   既定だけを実装し、違えたいときは 5.3.1 ([FlipCard]) で手動で反転する。
///
/// ★4.1.2.1 は「置かれる**場合**」の規定であって、置いたあとの反転 (5.3.1) を禁じない。
CardInstance placedIn(CardInstance card, Zone zone) => switch (zone) {
      // ★4.5 に表示面の条文は無いが 4.5.3 が公開領域と定めるので表向きになる。
      //   ただし向き (4.5.4) と重ね置き (4.5.5.2) で扱いが割れるため、
      //   メンバーエリアへの配置は `reduce.dart` の専用経路が持つ。
      Zone.memberArea => throw ArgumentError(
          'メンバーエリアは 4.5.4 / 4.5.5.2 で扱いが割れる。reduce の専用経路を使う'),
      Zone.stage => throw ArgumentError(
          'ステージはメンバーエリアの統合ビューで実体を持たない (4.4.1)'),
      // 4.6.2: 公開領域だが一時的に裏向きに置かれることがある。★引き継ぐ。
      Zone.liveStage => card,
      _ => switch (zone.visibility!) {
          // 4.1.2.1 → 4.2.2 → 4.3.3.1
          ZoneVisibility.public => card.copyWith(face: FaceState.faceUp),
          // 4.1.2.1 → 4.2.3 → 4.3.3.2
          ZoneVisibility.private => card.copyWith(face: FaceState.faceDown),
        },
    };
