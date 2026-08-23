/// 1 ペイン / 2 ペインの器（決定 D61 / `docs/UI設計メモ.md` §2-1）.
///
/// Release 1 は PC とモバイルを同時に要求するため、同じ機能が違う器に入る。
/// **同じ Widget を器だけ替えて置き、ルートを増やして分岐させない。**
///
/// ★★ しきい値を判定する場所はここ 1 箇所だけ ★★
/// 呼び出し側が `MediaQuery` の幅を見て自分で判定すると判断点が 2 つになり、
/// 「PC では直したがモバイルでは直っていない」が起きる。
/// 判定結果は [isTwoPaneOf] で下へ配る。
library;

import 'package:flutter/material.dart';

class PaneScaffold extends StatelessWidget {
  const PaneScaffold({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 320,
  });

  /// 2 ペインにする最小の論理幅（決定 D61）。
  ///
  /// ★★ 暫定値である ★★
  /// 根拠は 2 つあり、片方は見積りにすぎない。
  ///
  /// | # | 根拠 | 格 |
  /// |---|---|---|
  /// | (a) | Material 3 の window size class の expanded 境界が 840dp | 外部の標準。確か |
  /// | (b) | 一覧 3 列（3 × 140 + 間隔 ≈ 450）+ デッキペイン（≈ 320）+ 余白 ≈ 800 | ★見積り。実測ではない |
  ///
  /// (b) のデッキペイン 320 は実測値ではない（本実装のデッキ行の寸法が
  /// まだ決まっていないため）。**M4（R3 の実装時）と Phase 5（実機）で見直す。**
  /// `docs/UI設計メモ.md` §10 の U8 に未決として登録してある。
  ///
  /// ★3 つ目のペイン（検証パネル）にしきい値を増やさない。
  /// しきい値が 2 つになると組み合わせが 4 通りになり、判断点もテストも倍になる。
  /// 検証パネルはデッキペインの内側に縦に積む。
  static const double twoPaneMinWidth = 840;

  final Widget primary;

  /// 2 ペインのときだけ横に並ぶ。1 ペインのときは**描かれない**。
  /// 狭いときにこれを見せるかは呼び出し側が [isTwoPaneOf] を見て決める
  /// （例: AppBar のボタンからモーダルで同じ Widget を出す）。
  final Widget secondary;

  final double secondaryWidth;

  /// 直近の [PaneScaffold] が 2 ペインで描かれているか。
  ///
  /// ★呼び出し側は幅を自分で見ないこと。判断点はこのクラスの中だけ。
  static bool isTwoPaneOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PaneScope>()?.isTwoPane ??
      false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // ★しきい値の判定はこの 1 行だけ。
          final isTwoPane = constraints.maxWidth >= twoPaneMinWidth;
          return _PaneScope(
            isTwoPane: isTwoPane,
            child: isTwoPane
                ? Row(
                    children: [
                      Expanded(child: primary),
                      const VerticalDivider(width: 1),
                      SizedBox(width: secondaryWidth, child: secondary),
                    ],
                  )
                : primary,
          );
        },
      );
}

class _PaneScope extends InheritedWidget {
  const _PaneScope({required this.isTwoPane, required super.child});

  final bool isTwoPane;

  @override
  bool updateShouldNotify(_PaneScope oldWidget) =>
      oldWidget.isTwoPane != isTwoPane;
}
