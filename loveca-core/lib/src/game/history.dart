/// 巻き戻し（通過履歴スタック）.
///
/// 決定 D36。詳細は `docs/決定事項一覧.md` と `docs/PhaseEngine設計メモ.md` §6。
///
/// ★★ 静的グラフの逆辺は使えない ★★
///   8.4.12 が 8.4.9 へ戻るループを持つため、`stepGraph` 上で 8.4.9 の前任は
///   8.4.8 と 8.4.12 の 2 つある。2 周目の 8.4.9 から 1 つ戻る先は
///   1 周目の 8.4.12 であって 8.4.8 ではない。静的には決定できない。
///   → 実際に通過した状態の履歴から戻す。
///
/// ★★ 方式はスナップショット（決定 D36 / 案 B）★★
///   [GameState] は完全にイミュータブルで `copyWith` が未変更の領域リストの
///   参照を共有するため、スナップショットは構造共有が効く。
///   1 件の実費は「GameState 1 個 + players リスト 1 個 + 変更された
///   PlayerState 1 個 + 変更された領域リスト 1 個」で、残りは参照を共有する。
///
///   逆操作を記録する案（案 A）を採らなかった理由:
///     1. メモリ論拠が構造共有により成立しない
///     2. 逆操作の網羅が漏れると巻き戻しが静かに壊れる（A-3 と同じ型の失敗）
///     3. 8.4.13 が書き換える `firstPlayerId` の復元を書き忘れやすい
///     4. Phase 6 の権威サーバが持つ `reduce` のアクションログと二重管理になる
///
/// ★★ 1 ステップ戻す = カーソルが変わるまで pop ★★
///   1 件ごとに [StepCursor] を持たせることで、
///   オペレーション単位（[undo]）とステップ単位（[undoStep]）の両方を
///   1 つの機構から取り出せる。

library;

import 'game_state.dart';
import 'step.dart';

/// 履歴 1 件。
class HistoryEntry {
  const HistoryEntry(this.state);

  /// この時点の盤面のスナップショット。
  final GameState state;

  /// この時点の進行位置。★「1 ステップ戻す」の判定に使う。
  StepCursor get cursor => state.cursor;
}

/// 通過履歴スタック。
class GameHistory {
  const GameHistory({this.entries = const [], this.maxDepth = 512});

  /// 古い順。末尾が直前の状態。
  final List<HistoryEntry> entries;

  /// 保持する上限。超えたら古いものから捨てる。
  ///
  /// ★1 ターンは 12 フェイズ・のべ 73 ステップ。手動操作を含めても
  ///   既定値で数ターン分は戻せる。
  final int maxDepth;

  bool get isEmpty => entries.isEmpty;

  bool get canUndo => entries.isNotEmpty;

  int get depth => entries.length;

  /// 直前の状態。無ければ null。
  HistoryEntry? get last => entries.isEmpty ? null : entries.last;

  /// [state] を履歴に積む。
  GameHistory push(GameState state) {
    final next = [...entries, HistoryEntry(state)];
    return GameHistory(
      entries: next.length > maxDepth
          ? next.sublist(next.length - maxDepth)
          : next,
      maxDepth: maxDepth,
    );
  }

  /// 末尾を 1 件取り除く。
  GameHistory pop() => entries.isEmpty
      ? this
      : GameHistory(
          entries: entries.sublist(0, entries.length - 1),
          maxDepth: maxDepth,
        );
}

/// 盤面と履歴の組。
///
/// ★イミュータブル。操作するたびに新しい [GameSession] を返す。
class GameSession {
  const GameSession({required this.state, this.history = const GameHistory()});

  final GameState state;
  final GameHistory history;

  bool get canUndo => history.canUndo;

  /// 現在の状態を履歴に積んで [next] へ進む。
  ///
  /// 進行 (`StepEngine.advance`) でも手動操作でも同じように使う。
  /// ★どちらも同じ機構で戻せるのがスナップショット方式の利点。
  GameSession record(GameState next) => GameSession(
        state: next,
        history: history.push(state),
      );

  /// 1 件戻す。オペレーション単位の巻き戻し。
  ///
  /// 戻せるものが無ければ null。
  GameSession? undo() {
    final previous = history.last;
    if (previous == null) return null;
    return GameSession(state: previous.state, history: history.pop());
  }

  /// ★1 ステップ戻す。カーソルが変わるまで戻す。
  ///
  /// 着地点は 2 通りある。
  ///
  /// 1. **現在のステップ内で手動操作をしていた場合** — そのステップの**入口**へ着地する。
  ///    同じ [StepCursor] の履歴をまとめて 1 回で巻き戻す。
  ///    もう一度呼ぶと前のステップへ移る。
  ///
  /// 2. **ステップに入った直後の場合** — 1 つ前のステップへ着地する。
  ///
  /// ★8.4.12 → 8.4.9 のループがあるため、着地先は静的グラフからは決まらない。
  ///   2 周目の 8.4.9 から戻ると 1 周目の 8.4.12 に着地する（8.4.8 ではない）。
  GameSession? undoStep() {
    final current = state.cursor;
    var session = undo();
    if (session == null) return null;

    // 戻った先も同じステップで、さらに前も同じステップなら戻り続ける。
    // = そのステップの入口で止まる。
    while (session!.state.cursor == current &&
        session.history.last?.cursor == current) {
      session = session.undo();
    }
    return session;
  }
}
