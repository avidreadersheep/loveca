/// 画像出力 —— デッキ名 ＋ カードの格子（`docs/Android UI 決定.md` §3-12）.
///
/// ★★ 何を出すか（★§3-12 の表をそのまま）★★
///
/// | 項目 | 決定 |
/// |---|---|
/// | 中身 | ★**デッキ名 ＋ カードの格子**（★★統計は入れない★★） |
/// | 枚数 | ★**各カードの右下に数字** |
/// | 区切り | ★**種別ごとに塊を分ける。★エネルギーは行を改めて、★別の塊として離す** |
/// | エネルギー 0 枚 | ★★**エネルギーの塊を出さない**★★ |
/// | 行き先 | ★**画面に表示するだけ。★★依存を増やさない★★** |
///
/// ★★ 「画像」と名が付くが★★1 バイトもラスタライズしない★★ ★★
/// ★**`RepaintBoundary` も `toImage` も 1 つも書かない**（★★§3-12 の「画面に表示するだけ」★★）。
/// → ★**保存 / コピーは★★この widget の中に 1 本も無い★★**。
/// ★**Android の標準機能で保存できるかは★測った** —— ★正は `test/ui/deck_image_save_test.dart`（**W-84** の 1）。
///
/// ★★ 呼ぶ側が 1 つも無い（**D-20** を承知で置いた）★★
/// ★**§3-1 の下段タブ「デッキ構築」→ デッキ詳細 → 画像出力★の経路が★1 行も無い**（★走査した / 2026-09-03）。
/// ★★**いつ呼ばれる予定か**★★ —— ★**§3-10 のデッキ詳細画面が入ったとき**である
/// （★§3-10 が「画像出力」を★★その画面の口として挙げている★★）。
/// → ★**その日が来たら★★呼ばれることを見る対を置く★★**（★今日は置けない —— ★呼ぶ側が無い）。
///
/// ★★ Windows には載せない ★★
/// ★**Windows は★★共有形式の書き出しを持っている★★**（`deck_share_export_dialog.dart` / **D69**）。
/// ★**§2 の穴 4 が「★Android では共有形式を書き出せない」と述べており、★★画像出力はその代わりである★★。**
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import '../../data/card_image_source.dart';
import '../../data/card_list_row.dart';
import '../common/card_thumb.dart';

/// 出す塊 1 つ。★[entries] は★★1 枚も無い塊を作らない★★（下の [deckImageBlocksOf]）。
typedef DeckImageBlock = ({String key, List<DeckEntry> entries});

/// 塊の並び。★★メンバー → ライブ → エネルギー → ★マスタに無い刷り★★。
///
/// ★★ ここが唯一の並びの正である ★★
/// ★画面も試験もここを読む（★★書き写さない★★ / ★先例は `kCardTypeTabs`）。
const List<String> kDeckImageBlockOrder = ['member', 'live', 'energy', 'unknown'];

/// [sections] を★出す塊に畳む。★★純粋関数にしてある★★（★対を置くため）。
///
/// ★★ 空の塊は作らない ★★
/// ★**§3-12 が名指ししているのは★★エネルギー 0 枚だけである★★。**
/// ★**ここは「★★1 枚も無い塊は出さない★★」という★一般の規則にしてある** ——
/// ★**理由**: ★★中身が 1 枚も無い塊は★描くものが 1 つも無い★★。
/// ★**§3-12 のエネルギーの行は★この規則の帰結として満たされる**（★対で固定した）。
/// ★★**差し替え点はこの関数 1 つである**★★ ——
/// ★メンバー / ライブの空の塊を★★出したい★★なら、★ここで `isNotEmpty` を外す。
///
/// ★★ マスタに無い刷りを黙って捨てない（決定 **D35**）★★
/// ★**塊として最後に出す。**★★捨てると「出したはずのカードが 1 枚も出ていない」ことに気づけない★★。
List<DeckImageBlock> deckImageBlocksOf(DeckSections sections) {
  final byKey = <String, List<DeckEntry>>{
    'member': sections.members,
    'live': sections.lives,
    'energy': sections.energies,
    'unknown': sections.unknown,
  };
  return [
    for (final key in kDeckImageBlockOrder)
      if ((byKey[key] ?? const <DeckEntry>[]).isNotEmpty)
        (key: key, entries: byKey[key]!),
  ];
}

/// デッキ 1 つを★画面に出す（★★保存はしない★★）。
class DeckImageSheet extends StatelessWidget {
  const DeckImageSheet({
    super.key,
    required this.deckName,
    required this.sections,
    required this.imageSource,
    required this.rowOf,
    this.cardWidth = 72,
  });

  final String deckName;
  final DeckSections sections;
  final CardImageSource imageSource;

  /// 刷り → 一覧の投影行。★★絵と種別はここから引く★★（★`DeckEntry` は持っていない）。
  final CardListRow? Function(String printingId) rowOf;

  /// 1 枚の論理幅。
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = deckImageBlocksOf(sections);
    return SingleChildScrollView(
      key: const ValueKey('deckImageSheet'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★★ デッキ名（§3-12 の「中身」）★★
          Text(
            deckName,
            key: const ValueKey('deckImageSheet:name'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final block in blocks) ...[
            // ★★ 塊は「行を改めて」離す（§3-12）★★
            //   ★塊ごとに `Wrap` を分けるので、★★前の塊の途中に混ざることが構造上できない★★。
            Padding(
              key: ValueKey('deckImageBlock:${block.key}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in block.entries)
                    _Card(
                      entry: entry,
                      row: rowOf(entry.printingId),
                      imageSource: imageSource,
                      width: cardWidth,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.entry,
    required this.row,
    required this.imageSource,
    required this.width,
  });

  final DeckEntry entry;
  final CardListRow? row;
  final CardImageSource imageSource;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardType = row?.cardType ?? CardType.member;
    return SizedBox(
      width: width,
      height: width / cardAspectRatioOf(cardType),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (row == null)
            // ★★ 絵が出せないことを黙って空白にしない（★`_EntryRow` と同じ向き / **D35**）★★
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.help_outline,
                  size: 16, color: theme.disabledColor),
            )
          else
            CardArt(
              source: imageSource,
              imageHash: row!.imageHash,
              cardType: row!.cardType,
              logicalWidth: width,
            ),
          // ★★ 枚数は右下（§3-12）★★
          Positioned(
            right: 2,
            bottom: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '${entry.count}',
                  key: ValueKey('deckImageCount:${entry.printingId}'),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
