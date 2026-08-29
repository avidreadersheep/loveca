/// 検索結果ヘッダ（`docs/UI設計メモ.md` §2-6 / 決定 D40 / D50）.
///
/// ★★ 縮退を出す場所は設定ではなく検索画面である ★★
/// `truncated` も `likeFallback` も「**その検索語のその瞬間の状態**」であり、
/// 設定に置いても結びつかない（永続する状態は `import_issues` の側で、そちらは R6）。
///
/// ★★ 3 つの縮退を 1 行にまとめない ★★
/// どれも「結果が完全でない」通知だが、**原因も利用者の対処も違う。**
/// 区別がつかないと、どれも同じ「なんか出てる」になって無視される。
/// 1 縮退 = 1 行で、対処まで書く。
///
/// ★★ 内部語彙を出さない ★★
/// 「孤児」「cardNumber」「trigram」「索引」は実装の言葉であって利用者の言葉ではない。
/// 何が起きていて何をすればよいかが伝わる文にする。
///
/// ★★ M4: 1 行の描画は `ui/common/degradation_line.dart` へ移した ★★
/// デッキペインにも縮退（未知の刷り）が出るため、
/// **見た目だけ共有して型は分けた。**理由と振り分け規則は同ファイルの doc。
/// ★2026-08-29 訂正: ここには縮退として「保存されない並び順」も挙げてあったが、
/// **その縮退は撤去済み**である（決定 D99 / `state/deck_edit_degradation.dart`）。
/// ★型は `ルール整合性チェック_v1.06.md` **D-15 (l)**。
library;

import 'package:flutter/material.dart';

import '../../data/search_limit.dart';
import '../../state/card_browse_store.dart';
import '../../state/search_degradation.dart';
import '../../state/store.dart';
import '../common/degradation_line.dart';

class SearchResultHeader extends StatelessWidget {
  const SearchResultHeader({super.key, required this.state});

  final CardBrowseState state;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (state.hasQuery) _SummaryLine(state: state),
      for (final degradation in state.degradations)
        _DegradationLine(degradation: degradation),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// 件数の行。★`Ready` のときだけ件数を言う。
///
/// 検索中に 0 件と書くと「0 件だった」と区別がつかない。
/// 失敗のときはここには何も出さない（`LoadableView` がエラーを出す / 決定 D53）。
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.state});

  final CardBrowseState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (state.visible) {
      Loading() => '「${state.query}」を検索しています…',
      Failed() => '「${state.query}」の検索',
      Ready() => '「${state.query}」の検索結果: '
          '${state.visibleCount} 件 / 全 ${state.totalCount} 件',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

/// 縮退 1 つ = 1 行。
///
/// ★★ `switch` は網羅的でなければならない（`SearchDegradation` は sealed）★★
/// 4 つ目の縮退を足したとき、ここを直し忘れると**コンパイルエラーになる。**
/// 「見せ忘れ」が静かに起きないのは、この網羅性検査のおかげである。
class _DegradationLine extends StatelessWidget {
  const _DegradationLine({required this.degradation});

  final SearchDegradation degradation;

  @override
  Widget build(BuildContext context) {
    // ★原因の格が違うことを見た目で分ける。
    //   打ち切り・経路は「こう引いた」という報告、
    //   表示できないカードは**データ側の不整合**なので警戒色にする。
    final (IconData icon, DegradationSeverity severity, String text) =
        switch (degradation) {
      SearchTruncated(:final shown, :final limit, :final limitOverridden) => (
          Icons.filter_list_off,
          DegradationSeverity.report,
          '該当が多いため上限 $limit 件で打ち切りました（$shown 件を表示）。'
              '検索語を足すと絞り込めます。'
              '${limitOverridden ? ' ※上限は検証用の $searchLimitEnvironmentKey により'
                  '既定から変更されています。' : ''}',
        ),
      SearchLikeFallback() => (
          // ★`Icons.search` にしない。検索欄の prefixIcon と同じになり、
          //   「経路の表示が出ているか」を見た目でも自動でも判別できなくなる。
          Icons.manage_search,
          DegradationSeverity.report,
          '2 文字以下のため、部分一致で検索しました。'
              '3 文字以上にすると別の方法で検索し、並び順も変わります。',
        ),
      SearchMissingCards(:final count) => (
          Icons.report_problem_outlined,
          DegradationSeverity.warning,
          '一致した $count 件のカードを表示できません。'
              'カードデータが古い可能性があります。データを更新してください。',
        ),
    };

    return DegradationLine(icon: icon, severity: severity, text: text);
  }
}
