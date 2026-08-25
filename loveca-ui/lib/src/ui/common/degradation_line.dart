/// 縮退 1 つ = 1 行の描画（`docs/UI設計メモ.md` §3-4(3)）.
///
/// ★★ 共有するのは「描画」だけで、「型」は共有しない ★★
/// 縮退の型（`SearchDegradation` / `DeckEditDegradation`）は **文脈ごとに別の `sealed`** にしてある。
/// 1 つにまとめると、検索側に 4 つ目を足したときデッキ側の `switch` にも
/// 「ここでは起きない」枝が生え、**網羅性検査の意味が薄れる**（決定 D53）。
/// 網羅性は各文脈に閉じたまま、**見た目が 2 系統に分かれるのだけを防ぐ。**
///
/// ★★ 3 つ目の系統が出たときの振り分け規則 ★★
/// **その縮退がどの Store の寿命に属するかで系統を決める。**
///
/// | 寿命 | 系統 | 出る場所 |
/// |---|---|---|
/// | 検索語ごと（`CardBrowseStore`） | `SearchDegradation` | 検索結果ヘッダ |
/// | 編集セッションごと（`DeckEditStore`） | `DeckEditDegradation` | デッキペイン |
/// | どの Store にも属さない（起動時に決まり以降不変） | `BootNotice` | ★**全ルートの `NoticeBar`**（`BootGate` に一本化 / **決定 D89**） |
///
/// ★★ 1 縮退 = 1 行で、対処まで書く ★★
/// 区別がつかないと、どれも同じ「なんか出てる」になって無視される。
/// ★内部語彙（孤児 / cardNumber / trigram / 索引）を出さない。
library;

import 'package:flutter/material.dart';

/// 原因の格。★見た目で分ける。
enum DegradationSeverity {
  /// 「こう引いた / こうなっている」という報告。利用者の操作で変えられる。
  report,

  /// **データ側の不整合**。利用者の操作では直らず、更新などが要る。
  warning,
}

class DegradationLine extends StatelessWidget {
  const DegradationLine({
    super.key,
    required this.icon,
    required this.severity,
    required this.text,
  });

  final IconData icon;
  final DegradationSeverity severity;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (severity) {
      DegradationSeverity.report => theme.colorScheme.onSecondaryContainer,
      DegradationSeverity.warning => theme.colorScheme.error,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
