/// 手番プレイヤーとアクティブプレイヤーの解決.
///
/// 総合ルール 7.2 / 7.3.2 / 8.3.2 に対応。
///
/// ★★ フェイズは実プレイヤー ID を持たない ★★
///   [PhaseId] はロール (先攻 / 後攻 / なし) で定義されており、
///   実プレイヤーは `GameState.firstPlayerId` から**実行時に**解決する。
///   8.4.13 で先攻・後攻が入れ替わるため、フェイズ側に埋めてはいけない。
///
/// このファイルの関数はすべて純関数。状態を変更しない。

library;

import 'game_state.dart';
import 'phase.dart';

/// [playerId] の対戦相手。
///
/// 総合ルール 7.1.1「あるターン中は、いずれかのプレイヤーが先攻プレイヤーとなり、
/// そうでないプレイヤーは後攻プレイヤーとなります」
///
/// ★見つからない場合は例外を投げる。呼び出し側のバグであり、
///   配信データ起因ではない (`GameState.playerOf` と同じ扱い)。
String opponentOf(GameState state, String playerId) {
  final others = state.players
      .map((player) => player.playerId)
      .where((id) => id != playerId)
      .toList();
  if (others.length != 1) {
    throw ArgumentError(
      'opponent is not determined for "$playerId" (players: ${state.players.map((p) => p.playerId).toList()})',
    );
  }
  return others.single;
}

/// [phase] の手番プレイヤー。総合ルール 7.3.2 / 7.3.2.1 / 8.3.2。
///
/// ★手番プレイヤーを**指定しない**フェイズでは null を返す (7.2.1)。
///   該当するのは [PhaseId.liveCardSet] と [PhaseId.liveJudgement] の 2 つだけ。
///   8.2.2 / 8.2.4 も 8.4.2 以降も両プレイヤーを動かすため手番が定まらない。
String? turnPlayerOf(GameState state, PhaseId phase) =>
    switch (phase.turnPlayerRole) {
      // 7.3.2.1: 先攻プレイヤーが手番プレイヤーである「先攻通常フェイズ」
      PhaseRole.first => state.firstPlayerId,
      // 7.3.2.1: 後攻プレイヤーが手番プレイヤーである「後攻通常フェイズ」
      PhaseRole.second => opponentOf(state, state.firstPlayerId),
      PhaseRole.none => null,
    };

/// [phase] のアクティブプレイヤー。総合ルール 7.2.1.1 / 7.2.1.2。
///
/// - 7.2.1.1「手番プレイヤーを指定するフェイズ中は、手番プレイヤーがアクティブプレイヤーです」
/// - 7.2.1.2「手番プレイヤーを指定しないフェイズ中は、**先攻プレイヤー**がアクティブプレイヤーです」
///
/// アクティブプレイヤーを参照する規定:
///   1.3.4 / 1.3.4.2   複数プレイヤーの同時選択はアクティブプレイヤーから先に
///   9.5.3.2 / 9.5.3.3 チェックタイミングでの待機自動能力のプレイ順
///   10.2.4            両者同時リフレッシュは現ターンの先攻が先
String activePlayerOf(GameState state, PhaseId phase) =>
    turnPlayerOf(state, phase) ?? state.firstPlayerId;

/// [phase] の非アクティブプレイヤー。総合ルール 7.2.2。
String inactivePlayerOf(GameState state, PhaseId phase) =>
    opponentOf(state, activePlayerOf(state, phase));

/// 現在のフェイズの手番プレイヤー。手番を指定しないフェイズでは null。
String? currentTurnPlayer(GameState state) =>
    turnPlayerOf(state, state.cursor.phase);

/// 現在のフェイズのアクティブプレイヤー。
String currentActivePlayer(GameState state) =>
    activePlayerOf(state, state.cursor.phase);
