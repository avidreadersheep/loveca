/// 絞り込みチップの帯（★Android / `docs/Android UI 決定.md` §3-6）.
///
/// ★★ この層は★フォームを 1 つも開かない ★★
/// ★**押したら★★呼ぶ側へ渡すだけである★★**（★運転指示【2】—— ★UI は差し込み口まで作って止める）。
/// ★**どのフォームを出すかは★★呼ぶ側が決める★★** —— ★§3-7 の [NumberPickerSheet] を出すのか、
/// ★一覧から選ばせるのか、★検索欄へ移すのかは★★軸ごとに違う★★。
///
/// ★★ 並びの正は [kCardFilterAxes] である ★★
/// ★**画面も試験も★★そこを読む★★**（★★字面を書き写さない★★ / **D-15** の規約 3）。
/// ★**順序は §3-6 の絵のとおり**（★左から）——
/// ★キーワード → 登場作品 → ユニット → コスト → パラレル
/// ★→ ブレードハート → ブレード → スコア → 所持ハート → 必要ハート → 商品。
///
/// ★★ キーワードだけは★絞り込みではない ★★
/// ★**§3-6 が「★★フリーワード検索★★（FTS5 / **D40** / **D50**）」と書いている。**
/// ★**したがって★★立っているかは [CardListFilter] ではなく★検索語で決まる★★**
/// （★★[CardBrowseState.query] —— ★別の量である★★）。
/// → ★**[cardFilterAxisIsSet] が★★2 つを引数で受ける★★のはこのためである。**
///
/// ★★ この層が★覆わないもの（★言い切る）★★
///
/// | # | ★何 | ★なぜ |
/// |---|---|---|
/// | ★**1** | ★**押したあとに出るもの** | ★★**1 行も無い**★★（★呼ぶ側の仕事） |
/// | ★**2** | ★**いま何件が当たっているか** | ★**上部（§3-15）が出す**（★★2 か所で同じことを言わない★★） |
/// | ★**3** | ★**軸を外す口** | ★★**チップは押すだけである**★★（★外すのはフォームの「クリア」/ §3-7） |
/// | ★**4** | ★**帯の高さ / 1 画面に何個入るか** | ★★**測っていない**★★（**D-28**） |
library;

import 'package:flutter/material.dart';

import '../../data/card_list_row.dart';

/// 絞り込みの軸（★★§3-6 の 11 個★★）。
///
/// ★★ 宣言の順は★並びではない。★意図してずらしてある ★★
/// ★**この列挙は★★集合であって★順序ではない★★。**★**並びの正は [kCardFilterAxes] である。**
/// ★**宣言を並び順にすると、★★`CardFilterAxis.values` を回しても同じ絵が出る★★**ので、
/// ★★**「どちらを読んでいるか」が★出る値に 1 ビットも現れない**★★（★2026-09-04 に測った ＝ **0 件**）。
/// → ★**アルファベット順で宣言する。★★これで★読み違えが★振る舞いに出る★★。**
enum CardFilterAxis {
  blade,
  bladeHeart,
  cost,
  expansion,
  groupName,
  heart,
  keyword,
  parallel,
  requiredHeart,
  score,
  unitName,
}

/// 並びの正（★★画面も試験もここを読む★★）。
const kCardFilterAxes = <CardFilterAxis>[
  CardFilterAxis.keyword,
  CardFilterAxis.groupName,
  CardFilterAxis.unitName,
  CardFilterAxis.cost,
  CardFilterAxis.parallel,
  CardFilterAxis.bladeHeart,
  CardFilterAxis.blade,
  CardFilterAxis.score,
  CardFilterAxis.heart,
  CardFilterAxis.requiredHeart,
  CardFilterAxis.expansion,
];

/// チップの字面（★§3-6 の絵）。
String cardFilterAxisLabel(CardFilterAxis axis) => switch (axis) {
      CardFilterAxis.keyword => 'キーワード',
      CardFilterAxis.groupName => '登場作品',
      CardFilterAxis.unitName => 'ユニット',
      CardFilterAxis.cost => 'コスト',
      CardFilterAxis.parallel => 'パラレル',
      CardFilterAxis.bladeHeart => 'ブレードハート',
      CardFilterAxis.blade => 'ブレード',
      CardFilterAxis.score => 'スコア',
      CardFilterAxis.heart => '所持ハート',
      CardFilterAxis.requiredHeart => '必要ハート',
      CardFilterAxis.expansion => '商品',
    };

/// その軸が★いま立っているか。
///
/// ★★ 純粋関数にしてある ★★
/// ★**`ListView` は画面外を作らないので、★★11 個すべてを widget 越しに見られない★★**
/// （**D-10** / ★先例は `deck_count_band.dart` の `deckCountPickerValues`）。
///
/// ★★ パラレルは★「出さない」ときだけ立つ ★★
/// ★**既定は「すべて出す」である**（`CardListFilter.showParallel` の既定が `true`）。
/// ★★**立てる向きを逆にすると「何も絞っていないのに全部のチップが立つ」**★★。
bool cardFilterAxisIsSet(
  CardFilterAxis axis,
  CardListFilter filter,
  String query,
) =>
    switch (axis) {
      CardFilterAxis.keyword => query.trim().isNotEmpty,
      CardFilterAxis.groupName => filter.groupName != null,
      CardFilterAxis.unitName => filter.unitName != null,
      CardFilterAxis.cost => filter.maxCost != null,
      CardFilterAxis.parallel => !filter.showParallel,
      CardFilterAxis.bladeHeart => !heartRangesAreEmpty(filter.bladeHearts),
      CardFilterAxis.blade => !numberRangeIsEmpty(filter.blade),
      CardFilterAxis.score => !numberRangeIsEmpty(filter.score),
      CardFilterAxis.heart => !numberRangeIsEmpty(filter.heartTotal) ||
          !heartRangesAreEmpty(filter.hearts),
      CardFilterAxis.requiredHeart =>
        !numberRangeIsEmpty(filter.requiredHeartTotal) ||
            !heartRangesAreEmpty(filter.requiredHearts),
      CardFilterAxis.expansion => filter.expansion != null,
    };

/// 11 個のチップを★横に並べる（§3-6）。
class CardFilterChips extends StatelessWidget {
  const CardFilterChips({
    super.key,
    required this.filter,
    required this.query,
    required this.onTap,
  });

  final CardListFilter filter;

  /// ★★ 検索語（★キーワードのチップだけが見る）★★
  final String query;

  final ValueChanged<CardFilterAxis> onTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final axis in kCardFilterAxes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  key: ValueKey('cardFilterChip:${axis.name}'),
                  label: Text(cardFilterAxisLabel(axis)),
                  selected: cardFilterAxisIsSet(axis, filter, query),
                  // ★★ 押しても★ここでは何も変えない ★★
                  //   ★**選択状態は★★[filter] と [query] から導く★★**（★自分で持たない）。
                  //   ★**持つと★★状態が 2 か所になる★★**（**D-15** の規約 3）。
                  onSelected: (_) => onTap(axis),
                ),
              ),
          ],
        ),
      );
}
