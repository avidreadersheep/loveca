/// 集計の帯（M-B3 / 決定 D18 / D86 / CLAUDE.md §6 / 盤面設計メモ §10-1）.
///
/// ★★ 参照範囲を必ず画面にも書く ★★
/// 8.3.10（**アクティブ状態のメンバーのみ**）と 8.3.14（**ウェイトを含む全員**）は
/// 同じ「メンバーの合計」に見えて範囲が違う。並べて出す以上、
/// **どこを見た数字なのかを添えないと取り違える**（CLAUDE.md §6）。
///
/// ★★ 8.3.12 はプレイヤーごとに出さない ★★
/// 解決領域は両プレイヤー共有で 1 つだけ（4.14.1）で、8.3.12 は所有者で絞らない。
/// 自分・相手の欄に同じ数を 2 回出すと「別々に数えている」ように見える。
///
/// ★★ 8.4.2 の null は「—」。0 と書かない ★★
/// 8.4.3.2 が「片方だけカードがあるならそちらが大きい」と定めており、
/// 空を 0 で代用すると**スコア 0 のライブと同点になる**（実在する / `aggregation.dart`）。
///
/// ★★ ライブ成功判定は出さない（決定 D18）★★
/// 8.3.15 / 8.3.16 は実装しない。ALL / GRAY も色に変換しない（8.3.15.1.1 は手動）。
///
/// ★★ 畳めるのはここだけ ★★
/// 警告の帯（`board_notice_bar.dart`）は畳めない。畳めると「黙って落とさない」が
/// 崩れる。★既定は**開いた状態**——8.3.10〜8.3.14 は進めながら見る数値なので、
/// 畳んで始めると出ていることに気づかない。
///
/// ★横幅の最小値を増やさないよう `Wrap` で折り返す（決定 D83）。
///
/// ★★ 出す行は**受け取る**（決定 D88 / §14-5）★★
/// ソロでは相手の行が**そもそも無い**。★「相手の行に 0 が並ぶ」ではない。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../state/board_summary.dart';
import '../common/heart_chips.dart';
import 'board_view.dart';

class BoardSummaryPanel extends StatefulWidget {
  const BoardSummaryPanel({
    super.key,
    required this.players,
    this.initiallyExpanded = true,
  });

  /// 集計を出すプレイヤー。★`BoardView.drawnPlayers` を渡す（決定 D88）。
  final List<PlayerState> players;

  /// ★既定は開く（このファイルの doc）。畳んだ状態を試すためだけの口。
  final bool initiallyExpanded;

  @override
  State<BoardSummaryPanel> createState() => _BoardSummaryPanelState();
}

class _BoardSummaryPanelState extends State<BoardSummaryPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('summary-panel'),
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('summary-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                const SizedBox(width: 4),
                Text('集計（8.3.10 / 8.3.12 / 8.3.14 / 8.4.2）',
                    style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 2),
            for (final player in widget.players)
              _PlayerSummary(playerId: player.playerId),
            _SharedDraw(),
            const SizedBox(height: 2),
            Text(
              // ★★ 出していないものを明示する（D18）★★
              '★必要ハートを満たすかの確認（8.3.15）と、満たせなかった場合の処理（8.3.16）は'
              'アプリが行いません。ALL と 無 は色に変換していません（8.3.15.1.1 の色解決は手動です）。',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

/// 1 プレイヤーぶん。★8.3.12 はここに出さない（共有だから）。
class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    final summary =
        BoardSummary.of(view.state, view.catalog.cards, playerId: playerId);
    final score = summary.score.total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Wrap(
        key: ValueKey('summary-$playerId'),
        spacing: 14,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text(view.labelOf(playerId),
                style: theme.textTheme.labelMedium),
          ),
          _Metric(
            key: ValueKey('summary-blade-$playerId'),
            ruleRef: '8.3.10',
            name: 'ブレード合計',
            // ★★ 範囲を必ず書く ★★
            scope: 'アクティブ状態のメンバーのみ',
            value: Text('${summary.blade.total}',
                style: theme.textTheme.titleSmall),
          ),
          _Metric(
            key: ValueKey('summary-hearts-$playerId'),
            ruleRef: '8.3.14',
            name: 'ライブ所有ハート',
            scope: '全メンバー（ウェイトを含む）＋ 解決領域の自分のカード',
            value: summary.hearts.hearts.isEmpty
                ? Text('なし', style: theme.textTheme.labelMedium)
                : HeartChips(hearts: summary.hearts.hearts),
          ),
          _Metric(
            key: ValueKey('summary-score-$playerId'),
            ruleRef: '8.4.2',
            name: 'スコア合計',
            scope: score == null
                // ★★ 0 ではない。空であることを言葉で出す ★★
                ? 'ライブカード置き場が空なので合計がありません'
                : 'ライブカード置き場 ＋ 解決領域の自分のエール（8.4.2.1）',
            value: Text(score == null ? '—' : '$score',
                style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

/// 総合ルール 8.3.12.1 のドロー。★共有なので 1 つだけ出す。
class _SharedDraw extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    // ★playerId は結果に影響しない（8.3.12 は所有者で絞らない）。
    final summary = BoardSummary.of(view.state, view.catalog.cards,
        playerId: view.viewerId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Wrap(
        key: const ValueKey('summary-shared'),
        spacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text('共有', style: theme.textTheme.labelMedium),
          ),
          _Metric(
            key: const ValueKey('summary-draw'),
            ruleRef: '8.3.12',
            name: 'エールのドロー',
            // ★★ ここだけ絞らない。8.3.14 との違いを書く ★★
            scope: '解決領域のすべてのカード（★どちらのカードかで絞りません）',
            value:
                Text('${summary.draw.count}', style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    super.key,
    required this.ruleRef,
    required this.name,
    required this.scope,
    required this.value,
  });

  final String ruleRef;
  final String name;

  /// ★参照範囲。**省かない。**
  final String scope;

  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '$name $ruleRef — $scope',
      // ★★ `Row` にしない ★★
      //   `Wrap` の子は「窓幅」を上限に配られるので、1 項目が窓より広いと
      //   **折り返せずに溢れる**。8.3.14 の行は参照範囲の文言が長く、実測で
      //   843 論理px あった（`board_min_width_test.dart` の内訳）。
      //   ★盤面と違って進行バー・帯・集計は横スクロールしないので、
      //   ここが溢れると窓を狭めた瞬間に黄色い縞が出る。
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$name $ruleRef', style: theme.textTheme.labelSmall),
          value,
          // ★★ ツールチップだけにしない ★★
          //   範囲を隠すと、並んだ 2 つの数字を同じ範囲だと読んでしまう。
          Text('（$scope）',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
