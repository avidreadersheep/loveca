/// 非公開領域の山（決定 D77）— 総合ルール 4.8 / 4.9.
///
/// ★★ このウィジェットは中身を「描かない」のではなく「受け取らない」★★
///
/// | 条 | 本文（要旨） |
/// |---|---|
/// | 4.8.2 | メインデッキ置き場は**すべてのプレイヤーに対して**非公開領域 |
/// | 4.9.2 | エネルギーデッキ置き場も同じく非公開領域 |
/// | 4.1.2.2 | 公開・非公開にかかわらず**枚数はいつでも全プレイヤーが確認できる** |
///
/// ★★ `redact` に頼らない ★★
/// 一人回しでは `redact` を掛けない（掛けると相手側を操作できなくなる / D77）。
/// しかし 4.8 / 4.9 は**オーナーからも非公開**なので、`GameState` が中身を
/// 持っていても盤面が出してはいけない。**したがってこれは盤面 UI の責務である。**
///
/// ★★ 「たまたま描いていない」では守れないので、構造で守る ★★
/// このウィジェットが受け取るのは [count] だけで、`CardInstance` を 1 つも受け取らない。
/// **中身を出したくても出せる材料が無い。**
/// `test/board/board_secrecy_test.dart` が、中身の入った実 `GameState` に対して
/// (1) 山のカードの printingId がツリーに現れないこと
/// (2) ★**その imageHash で `CardImageSource.provider` が 1 度も呼ばれないこと**
/// を固定し、**対**として枚数が出ること・手札の札は出ることを見る。
///
/// ★★ 「上から見る」の口をエネルギーデッキに作らない ★★
/// 5.7.1 / 5.7.2 / 10.2.2.2 はいずれも**メインデッキ置き場**についての規定であり、
/// エネルギーデッキ置き場を対象にした条は存在しない（決定 D73 / 盤面設計メモ §2-5）。
///
/// ★★ 落とすことはできる（M-B2）★★
/// 中身を**出さない**ことと、そこへ**戻せない**ことは別である。
/// 10.5.4 はエネルギーカードがエネルギーデッキ置き場へ戻ることを定めており、
/// 手で戻す口が無いとサンドボックスとして成立しない。
/// ★4.8 は順番が管理される（4.8.2）ので上下の帯が出る。4.9 は出ない（4.9.2）。
/// **どちらも `board_drag.dart` の写像から自動的に決まる**（`board_drop.dart`）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import 'board_drag.dart';
import 'board_drop.dart';
import 'board_slot.dart';

class HiddenPile extends StatelessWidget {
  const HiddenPile({
    super.key,
    required this.playerId,
    required this.zone,
    required this.title,
    required this.count,
    this.width = kBoardSlotWidth,
  });

  /// この山の持ち主。★落とす先を決めるためだけに要る。
  final String playerId;

  /// [Zone.mainDeck] / [Zone.energyDeck]。★条番号もここから取る。
  final Zone zone;

  /// 「メインデッキ」/「エネルギーデッキ」。
  final String title;

  /// ★★ このウィジェットが受け取る唯一の中身（4.1.2.2）★★
  /// ★[CardInstance] を 1 つも受け取らない。**出したくても材料が無い。**
  final int count;

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BoardDropSlot(
          width: width,
          resolve: (drag, edge) =>
              moveToZone(drag, toPlayerId: playerId, to: zone, edge: edge),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined,
                    size: width * 0.28, color: theme.colorScheme.outline),
                const SizedBox(height: 2),
                // ★4.1.2.2: 枚数は隠さない。★秘匿と混同して消さないこと。
                Text(
                  '$count',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: width,
          child: Text(
            '$title\n${zone.ruleRef}',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
