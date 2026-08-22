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
