/// R5 カード詳細の**1 ペインの器**（`docs/UI設計メモ.md` §2-2 / 決定 D66）.
///
/// ★★ ルートになるのは 1 ペインのときだけ ★★
/// 2 ペインでは `PaneScaffold` の secondary に同じ [CardDetailPane] が入る。
/// **どちらに出すかを決めるのは `open_card_detail.dart` の 1 箇所だけ**（§2-1）。
///
/// ★この器が足すのは AppBar（戻る）だけ。中身は 2 ペインと同一である。
/// 中身を分けると「PC では直したがモバイルでは直っていない」が起きる。
library;

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import 'card_detail_pane.dart';

class CardDetailPage extends StatelessWidget {
  const CardDetailPage({super.key, required this.printingId});

  final String printingId;

  @override
  Widget build(BuildContext context) {
    // ★見出しにカード名を出す。引けないときは printingId をそのまま出す
    //   （黙って空欄にしない）。中身側も `_NotFound` を出す。
    final detail = AppScope.of(context).environment.cardDetail.of(printingId);

    return Scaffold(
      appBar: AppBar(title: Text(detail?.card.name ?? printingId)),
      // ★onClose を渡さない。閉じるのは AppBar の戻るが担う。
      body: CardDetailPane(printingId: printingId),
    );
  }
}
