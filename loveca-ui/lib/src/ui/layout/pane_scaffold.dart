/// 1 ペイン / 2 ペインの器（決定 D61 / `docs/UI設計メモ.md` §2-1）.
///
/// Release 1 は PC とモバイルを同時に要求するため、同じ機能が違う器に入る。
/// **同じ Widget を器だけ替えて置き、ルートを増やして分岐させない。**
///
/// ★★ しきい値を判定する場所はここ 1 箇所だけ ★★
/// 呼び出し側が `MediaQuery` の幅を見て自分で判定すると判断点が 2 つになり、
/// 「PC では直したがモバイルでは直っていない」が起きる。
/// 判定結果は [isTwoPaneOf] で下へ配る。
///
/// ★★ M4: [header] を足した ★★
/// 判定結果は `_PaneScope` の**内側**でしか読めない。M3 までは器の外
/// （`Scaffold.appBar`）から [isTwoPaneOf] を呼んでいた箇所があり、
/// **常に false になって「1 ペインのときだけ出す」が効いていなかった**
/// （`test/layout/pane_scaffold_test.dart` の「PaneScaffold の外では false」が
/// まさにその性質を固定している）。
/// 器に依らず常に同じ場所へ出したいもの（検索欄・結果ヘッダ・ペインを開くボタン）は
/// [header] に置く。**全幅で両ペインの上に載り、かつ判定結果が読める。**
library;

import 'package:flutter/material.dart';

class PaneScaffold extends StatelessWidget {
  const PaneScaffold({
    super.key,
    required this.primary,
    required this.secondary,
    this.header,
    this.secondaryWidth = 320,
  });

  /// 2 ペインにする最小の論理幅（決定 D61）。
  ///
  /// ★★ M4 で検算した（未決 U8）★★
  /// 根拠は 2 つあり、**格が違う。**
  ///
  /// | # | 根拠 | 格 |
  /// |---|---|---|
  /// | (a) | Material 3 の window size class の expanded 境界が 840dp | 外部の標準。確か |
  /// | (b) | 一覧 3 列（3 × 140 + 間隔 6 × 4 = 444）+ デッキペイン + 余白 | ★M4 までは**見積り**（320）だった |
  ///
  /// (b) の「デッキペイン」は M4 で**実測**に置き換わった。
  /// 実測値と手順は `docs/UI設計メモ.md` §9-6 / `test/ui/deck_pane_width_test.dart`。
  ///
  /// ★3 つ目のペイン（検証パネル）にしきい値を増やさない。
  /// しきい値が 2 つになると組み合わせが 4 通りになり、判断点もテストも倍になる。
  /// 検証パネルはデッキペインの内側に縦に積む。
  ///
  /// ★Phase 5（実機のタブレット）での見直しは残っている。
  static const double twoPaneMinWidth = 840;

  final Widget primary;

  /// 2 ペインのときだけ横に並ぶ。1 ペインのときは**描かれない**。
  /// 狭いときにこれを見せるかは呼び出し側が [isTwoPaneOf] を見て決める
  /// （例: [header] のボタンからモーダルで同じ Widget を出す）。
  final Widget secondary;

  /// 両ペインの上に**全幅**で載る帯。★[isTwoPaneOf] が読める位置にある。
  final Widget? header;

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
          final panes = isTwoPane
              ? Row(
                  children: [
                    Expanded(child: primary),
                    const VerticalDivider(width: 1),
                    SizedBox(width: secondaryWidth, child: secondary),
                  ],
                )
              : primary;
          return _PaneScope(
            isTwoPane: isTwoPane,
            child: header == null
                ? panes
                : Column(
                    children: [header!, Expanded(child: panes)],
                  ),
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
