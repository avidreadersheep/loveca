/// カード詳細を開く（決定 D66 / `docs/UI設計メモ.md` §2-1 / §2-2）.
///
/// ★★★ ペインに出すかルートを押すかを決める唯一の場所 ★★★
/// `docs/UI設計メモ.md` §2-1 は「切替の判断点は `PaneScaffold` 1 箇所に閉じる」と
/// 定めている。R3 と R4 がそれぞれ `isTwoPaneOf` を見て分岐すると判断点が 2 つになり、
/// **「R4 では直したが R3 では直っていない」が起きる。**
/// → 両方この関数を呼ぶ。
///
/// ★★ [context] は `PaneScaffold` の**内側**のものでなければならない ★★
/// `_PaneScope` は `PaneScaffold` の内側にしか無いので、外（`Scaffold.appBar` など）
/// から呼ぶと**常に 1 ペイン扱いになる**。M4 で実際に踏んだ不具合と同じ形。
/// 呼び出し元は一覧のセル（= `PaneScaffold` の primary の中）なので満たしている。
library;

import 'package:flutter/material.dart';

import '../layout/pane_scaffold.dart';
import 'card_detail_page.dart';

/// 詳細を出す。
///
/// - **2 ペイン**: [showInPane] を呼ぶ（器が secondary を差し替える / 決定 D66）
/// - **1 ペイン**: R5 ルート（[CardDetailPage]）を push する
///
/// ★どちらでも中身は同じ `CardDetailPane` である。
void openCardDetail(
  BuildContext context,
  String printingId, {
  required ValueChanged<String> showInPane,
}) {
  // ★★ 判断はこの 1 行だけ ★★
  if (PaneScaffold.isTwoPaneOf(context)) {
    showInPane(printingId);
    return;
  }

  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => CardDetailPage(printingId: printingId)),
  );
}
