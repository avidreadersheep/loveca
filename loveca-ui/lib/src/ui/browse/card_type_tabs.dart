/// カテゴリタブ —— すべて / メンバー / ライブ / エネルギー.
///
/// ★★ 種別は絞り込みパネルから外し、ここへ移した（`docs/Android UI 決定.md` §1-2）★★
/// ★**Windows も同じ**（★申し送りが「Windows 版も似た UI にしたい」と明記している）。
///
/// ★★ 絞り込みそのものは 1 ビットも変わっていない ★★
/// 押すと `CardBrowseStore.setCardType` を呼ぶ。★**`CardListFilter.cardType` が正であり、
/// この widget は★★その値を出し入れする口でしかない★★。**
/// ★**種別を 2 か所で持たない**（`ルール整合性チェック_v1.06.md` **D-15** の規約 3）。
///
/// ★★ 「お気に入り」は置かない（§3-5）★★
/// ★★ 「すべて」が在るので、3 種別は同じ一覧に混ざって出る（§3-5）★★
///
/// ★★ 横スクロールにする（§3-5）★★
/// ★4 つが入らない幅でも**畳まない**。★★縮めた文字にもしない★★
/// （★§3-4 の「ラベルは縮めない」と同じ向き）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/card_browse_store.dart';

/// タブの並び。★**「すべて」が先頭**（§3-5 の字面の順）。
///
/// ★★ ここが唯一の並びの正である ★★
/// ★試験も画面もここを読む（★★書き写さない★★）。
const List<(CardType?, String)> kCardTypeTabs = [
  (null, 'すべて'),
  (CardType.member, 'メンバー'),
  (CardType.live, 'ライブ'),
  (CardType.energy, 'エネルギー'),
];

class CardTypeTabs extends StatelessWidget {
  const CardTypeTabs({super.key, required this.store});

  final CardBrowseStore store;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CardBrowseState>(
        valueListenable: store,
        builder: (context, state, _) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final (type, label) in kCardTypeTabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('cardTypeTab:${type?.name ?? 'all'}'),
                    label: Text(label),
                    selected: state.filter.cardType == type,
                    // ★★ 選ばれているものを押しても外れない ★★
                    //   ★「すべて」へ戻す口は**「すべて」のタブ自身**である。
                    //   ★外せるようにすると「どれも選ばれていない」状態ができ、
                    //   ★★それは「すべて」と同じなのに見た目が違う★★。
                    onSelected: (_) => store.setCardType(type),
                  ),
                ),
            ],
          ),
        ),
      );
}
