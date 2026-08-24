/// 一覧のグリッド（決定 D42 / D48 / `docs/UI設計メモ.md` §6-6）.
///
/// ★★ 寸法の出典の格が 2 つある。混ぜないこと ★★
///
/// | 値 | 出典 | 格 |
/// |---|---|---|
/// | セル幅 120 物理px / thumb 原寸 200×279 | `docs/UI技術検証メモ.md` §3 | **正**（D42 の数値はこの条件で得られた） |
/// | `maxExtent 140` / `spacing 6` / 比 200:279 | `spike/main_grid.dart` | 再現手段。メモには無い |
///
/// ★これらを変えると、セル幅 120 物理px という D42 の前提が動く。
/// `ResizeImage` の効果（予算超え 25 フレーム → 0）もキャッシュの見積り
/// （1 枚 74 KB / 1000 枚）も、すべてこのセル幅で測ったものである。
/// **変えるなら測り直すこと。**
library;

import 'package:flutter/material.dart';

import '../../data/card_image_source.dart';
import '../../data/card_list_row.dart';
import '../common/card_thumb.dart';

class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.rows,
    required this.imageSource,
    this.cellWrapper,
  });

  final List<CardListRow> rows;
  final CardImageSource imageSource;

  /// セルを包む口（M4）。
  ///
  /// ★★ R3（デッキ編集）と R4（カード閲覧）で**同じグリッド**を使う（§2-2）★★
  /// R3 はセルを掴めるようにし「+」を重ねるが、そのためにグリッドを
  /// もう 1 本作らない。ルートを増やして分岐させないのと同じ理由で、
  /// **寸法（決定 D42 の前提）が 2 箇所に分かれるのを避ける。**
  final Widget Function(CardListRow row, Widget cell)? cellWrapper;

  /// セルの最大論理幅（`spike/main_grid.dart:491`）。
  static const double maxCellExtent = 140;

  /// セルの間隔（同 :492）。
  static const double spacing = 6;

  /// thumb の原寸比（同 :522 / `docs/UI技術検証メモ.md` §3）。
  static const double aspectRatio = 200 / 279;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      // ★「絞り込みで 0 件」は失敗ではないので、エラーとは別の見た目にする。
      return const Center(child: Text('条件に合うカードがありません'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / maxCellExtent).ceil().clamp(1, 100);
        // セルの論理幅。物理px への変換は CardThumb が行う（決定 D42）。
        final cellWidth =
            (constraints.maxWidth - spacing * (crossAxisCount + 1)) /
                crossAxisCount;

        // ★決定 D42: GridView.builder の仮想化で足りる。2,527 セルでも
        //   build p50 0.3〜0.4ms（予算 6.9ms）。独自の仮想リストは要らない。
        return GridView.builder(
          padding: const EdgeInsets.all(spacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final cell = _CardCell(
              row: row,
              imageSource: imageSource,
              logicalWidth: cellWidth,
            );
            return cellWrapper?.call(row, cell) ?? cell;
          },
        );
      },
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({
    required this.row,
    required this.imageSource,
    required this.logicalWidth,
  });

  final CardListRow row;
  final CardImageSource imageSource;
  final double logicalWidth;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '${row.name}\n${row.printingId}',
        waitDuration: const Duration(milliseconds: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CardThumb(
            source: imageSource,
            imageHash: row.imageHash,
            logicalWidth: logicalWidth,
          ),
        ),
      );
}
