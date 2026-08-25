/// 盤面から導く集計と警告（M-B3 / 決定 D18 / CLAUDE.md §6 / 盤面設計メモ §10）.
///
/// ★★ 計算を 1 行も書かない ★★
/// 集計は `loveca_core` の `LiveAggregator` が持つ。ここはそれを呼び、
/// **参照範囲を取り違えないように 4 つを 1 つの入れ物にまとめる**だけ。
/// UI で `LiveAggregator` を直接組むと、8.3.12（絞らない）に playerId を
/// 渡そうとするような取り違えが画面ごとに起きる。
///
/// ★★ 参照範囲が 4 つとも違う（CLAUDE.md §6）★★
///
/// | 集計 | 対象 | 所有者で絞るか |
/// |---|---|---|
/// | 8.3.10 ブレード | 自分の**アクティブ状態の**メンバー | — |
/// | 8.3.12 ドロー | 解決領域の**すべてのカード** | ★**絞らない**（だから [BoardSummary.draw] は共有） |
/// | 8.3.14 ハート | 自分の**すべての**メンバー + 解決領域 | 解決領域は絞る |
/// | 8.4.2 スコア | 自分のライブカード置き場 + 解決領域 | 解決領域は絞る |
///
/// ★★ ライブ成功判定（8.3.15 / 8.3.16）は出さない（決定 D18）★★
/// 数値を出すところまで。ALL / GRAY も**色に変換しない**（8.3.15.1.1 の色解決は手動）。
///
/// ★Flutter に依存しない。描画は `ui/board/board_summary_panel.dart`。
///
/// ★★ 描くプレイヤーは**受け取る**（決定 D88 / §14-5）★★
/// ソロでは相手側を**そもそも参照しない**ので、この関数は `GameState` から
/// プレイヤーを引き直さない。反復元は `ui/board/board_view.dart` の
/// `drawnPlayers` 1 か所である。★引数を変えたので呼び出し側はコンパイルエラーになる。
///
/// ★設計メモ §14-5 は「引数を `state` + `playerIds` にする」と書いているが、
/// `playerIds` にすると**この層で `GameState` を引き直す**ことになり、
/// 走査テスト（`test/board/board_player_access_test.dart`）に例外が要る。
/// **例外を作らない側を採った。**
library;

import 'package:loveca_core/loveca_core.dart';

import 'board_notice.dart';

/// 1 プレイヤーぶんの集計。★[draw] だけは共有（8.3.12）。
class BoardSummary {
  const BoardSummary._({
    required this.playerId,
    required this.blade,
    required this.draw,
    required this.hearts,
    required this.score,
  });

  factory BoardSummary.of(
    GameState state,
    Map<String, Card> cards, {
    required String playerId,
  }) {
    final aggregator = LiveAggregator(cards: cards);
    return BoardSummary._(
      playerId: playerId,
      blade: aggregator.bladeTotal(state, playerId),
      // ★playerId を渡さない。8.3.12 は解決領域のすべてのカードを見る。
      draw: aggregator.yellDrawCount(state),
      hearts: aggregator.ownedHearts(state, playerId),
      score: aggregator.scoreTotal(state, playerId),
    );
  }

  final String playerId;

  /// 総合ルール 8.3.10。★**アクティブ状態のメンバーのみ。**
  final BladeTotal blade;

  /// 総合ルール 8.3.12.1。★**解決領域のすべてのカード（所有者で絞らない）。**
  /// ★プレイヤーごとに違う値にならない。画面でも 1 つだけ出す。
  final YellDrawCount draw;

  /// 総合ルール 8.3.14。★**全メンバー（ウェイト含む）+ 解決領域の自分のカード。**
  final OwnedHearts hearts;

  /// 総合ルール 8.4.2。★**null は「ライブカード置き場が空」で 0 ではない。**
  final ScoreTotal score;
}

/// 盤面の状態から導く注記（M-B3）。
///
/// ★★ 「起きた出来事」ではなく「いまそうなっていること」だけを入れる ★★
/// だから毎 build 作り直してよい。整理の結果（10.3 / 10.6 の警告など）は
/// 出来事なので `GameStore` の `BoardTidyLog` が持つ。混ぜない。
///
/// [labelOf] は「自分」「相手」を返す。★playerId を画面に出さないため、
/// 対応づけは `BoardView.labelOf` 1 か所に置いて**ここでは持たない**。
///
/// ★★ [historyAtMaxDepth] もここに置く（M-B5）★★
/// 「巻き戻せる履歴が上限に達している」は**出来事ではなく状態**である。
/// 到達した時点から、そうでなくなるまで出続けるのが正しい。
List<BoardNotice> derivedBoardNotices({
  required GameState state,
  required Map<String, Card> cards,
  required List<PlayerState> players,
  required String Function(String playerId) labelOf,
  bool historyAtMaxDepth = false,
  int historyMaxDepth = 0,
}) {
  final notices = <BoardNotice>[
    if (historyAtMaxDepth) HistoryAtMaxDepth(maxDepth: historyMaxDepth),
  ];

  var sharedDrawReported = false;

  // ★★ 並びは呼び出し側が決める（`drawnPlayers` は視点側が先）★★
  //   読む順を決定的にするのは呼び出し側の責務であり、ここで並べ替えない。
  for (final player in players) {
    final playerId = player.playerId;
    final label = labelOf(playerId);
    final summary = BoardSummary.of(state, cards, playerId: playerId);

    // ---- 集計から落ちたもの（黙って落とさない）----
    void excluded(String ruleRef, AggregationResult result) {
      if (!result.hasExclusions) return;
      notices.add(AggregationExcluded(
        scope: label,
        ruleRef: ruleRef,
        count: result.excludedCount,
        cardNumbers: result.unknownCardNumbers,
      ));
    }

    excluded('8.3.10', summary.blade);
    excluded('8.3.14', summary.hearts);
    excluded('8.4.2', summary.score);

    // ★8.3.12 は共有なので 1 回だけ。★プレイヤーごとに 2 回出すと二重に見える。
    if (!sharedDrawReported && summary.draw.hasExclusions) {
      sharedDrawReported = true;
      notices.add(AggregationExcluded(
        scope: '解決領域（共有）',
        ruleRef: '8.3.12',
        count: summary.draw.excludedCount,
        cardNumbers: summary.draw.unknownCardNumbers,
      ));
    }

    // ---- メンバーエリアの中間状態（★エラーではない）----
    final orphanAreas = [
      for (final area in player.memberAreas)
        if (area.orphans.isNotEmpty) area.slot.label,
    ];
    if (orphanAreas.isNotEmpty) {
      notices.add(OrphanCardsPresent(playerLabel: label, areaLabels: orphanAreas));
    }

    final duplicateAreas = [
      for (final area in player.memberAreas)
        if (area.hasDuplicateMembers) area.slot.label,
    ];
    if (duplicateAreas.isNotEmpty) {
      notices.add(
          DuplicateMembersPresent(playerLabel: label, areaLabels: duplicateAreas));
    }
  }

  return notices;
}
