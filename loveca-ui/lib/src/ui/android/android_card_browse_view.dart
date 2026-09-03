/// ★★ Android のカード検索 —— ★★縦の積み方★★（`docs/Android UI 決定.md` §3-3 / ★**W-100**）★★
///
/// ★★ この節が★初めて★既に置いた widget を★実際に繋ぐ ★★
/// ★**§3-2 / §3-4 / §3-5 / §3-15 は★★どれも「呼ぶ側 0」で置いてあった★★**（**D-20**）。
/// ★**ここが★★4 つの呼び出し側になる★★。**
///
/// | ★§3 | ★何を呼ぶか |
/// |---|---|
/// | **3-15** | `CardSortHeader`（★件数 / 並び順） |
/// | **3-2** | `CardListTile`（★1 行） |
/// | **3-5** | `CardTypeTabs`（★カテゴリタブ） |
/// | **3-4** | `DeckCountersBand`（★3 本のカウンタ） |
///
/// ★★ 積む順は §3-3 の絵そのものである ★★
/// ★**上から: ★件数 / 並び順 → ★縦リスト → ★カテゴリタブ → ★絞り込みチップ → ★カウンタ。**
/// ★★**WS と同じ積み方である**★★（★チップとカテゴリタブは★★画面の下★★）。
///
/// ★★ 絞り込みチップ（★§3-6）は★差し込み口だけ置く ★★
/// ★**あれは★★U21 の論点 1 に当たる★★**（★段 B の軸が 5 つ / **W-85**）。
/// → ★**受け取る形にして★★この層では 1 つも作らない★★**（★運転指示【2】—— ★UI は差し込み口まで）。
///
/// ★★ 下段タブは★ここに置かない ★★
/// ★**§3-1 の入れ物（`AndroidHomePage`）が持つ**（★★同じものを 2 か所で描かない★★ / **D-15** の規約 3）。
///
/// ★★ この層が★決めないもの ★★
/// ★**1)** ★★絞り込みの軸★★ —— ★**U21 の論点 1 を 1 ミリも動かさない**（★上）。
/// ★**2)** ★**行を押したときに何が出るか** —— ★★呼び出し側が渡す★★（★§3-14 は 1 行も無い）。
/// ★**3)** ★**`Card` / `Printing` の引き方** —— ★★`MasterCatalog` から引く★★。
///   ★★**これは★表示の話であって★絞り込みの話ではない**★★（★`card_list_tile.dart` の doc と同じ線）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../data/card_image_source.dart';
import '../../data/card_list_row.dart';
import '../../data/master_catalog.dart';
import '../../state/card_browse_store.dart';
import '../browse/card_list_tile.dart';
import '../browse/card_sort.dart';
import '../browse/card_type_tabs.dart';
import '../deck/deck_counters_band.dart';

/// ★§3-3 の縦の積み方。
class AndroidCardBrowseView extends StatelessWidget {
  const AndroidCardBrowseView({
    super.key,
    required this.rows,
    required this.catalog,
    required this.imageSource,
    required this.store,
    required this.order,
    required this.onOrderChanged,
    this.onTapRow,
    this.filterChips,
    this.validation,
  });

  /// ★いま出す行（★★絞り込みも検索も★呼び出し側が済ませたもの★★）。
  final List<CardListRow> rows;

  final MasterCatalog catalog;
  final CardImageSource imageSource;

  /// ★カテゴリタブが読む（★§3-5 —— ★★種別は絞り込みではなくタブが持つ★★ / §1-2）。
  final CardBrowseStore store;

  final CardSortOrder order;
  final ValueChanged<CardSortOrder> onOrderChanged;

  /// ★行を押したときに何が起きるか（★★この層は決めない★★）。
  final void Function(CardListRow row)? onTapRow;

  /// ★★ §3-6 の差し込み口（★★U21 の論点 1 待ち / **W-85**★★）★★
  /// ★**`null` なら★★その段そのものを出さない★★**（★★空の帯を置かない★★）。
  final Widget? filterChips;

  /// ★★ 3 本のカウンタ（★§3-4）★★
  ///
  /// ★**`null` なら★★帯を出さない★★** —— ★**編集しているデッキが無いとき**。
  /// ★★**§3-4 の「3 本を常時出す」に反しない**★★ —— ★**あれは★★満たした本を隠さない★★という意味である**
  /// （★同じ行の「★1 段に入れば横 1 段。入らなければ 3 段」が★★3 本を前提にしている★★）。
  /// ★**差し替え点はこの 1 つの分岐である。**
  final DeckValidationResult? validation;

  @override
  Widget build(BuildContext context) {
    final counters = validation;
    return Column(
      key: const ValueKey('androidBrowse:column'),
      children: <Widget>[
        // ★★ 1 段目 —— ★件数 / 並び順（★§3-15）★★
        CardSortHeader(
          count: rows.length,
          order: order,
          onChanged: onOrderChanged,
        ),
        const Divider(height: 1),
        // ★★ 2 段目 —— ★カードの縦リスト（★§3-2 の 1 行を積む）★★
        //   ★**`Expanded` にする** —— ★★下の 3 段は★高さが中身で決まる★★。
        Expanded(
          child: ListView.builder(
            key: const ValueKey('androidBrowse:list'),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final card = catalog.cards[row.cardNumber];
              final printing = catalog.printings[row.printingId];
              // ★★ マスタに無い行は★飛ばさない。★1 行として出す ★★
              //   ★**捨てると「出したはずのカードが 1 枚も出ていない」ことに気づけない**
              //   （★決定 **D35** —— ★★黙って消さない★★ / ★先例は `deck_image_sheet.dart`）。
              if (card == null || printing == null) {
                return ListTile(
                  key: ValueKey('androidBrowse:unknown:${row.printingId}'),
                  title: Text(row.printingId),
                  subtitle: const Text('★このカードのデータがありません'),
                );
              }
              return CardListTile(
                card: card,
                printing: printing,
                imageSource: imageSource,
                onTap: onTapRow == null ? null : () => onTapRow!(row),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // ★★ 3 段目 —— ★カテゴリタブ（★§3-5）★★
        CardTypeTabs(store: store),
        // ★★ 4 段目 —— ★絞り込みチップ（★§3-6 / ★差し込み口）★★
        ?filterChips,
        // ★★ 5 段目 —— ★3 本のカウンタ（★§3-4）★★
        if (counters != null)
          DeckCountersBand(validation: counters, config: catalog.config),
      ],
    );
  }
}
