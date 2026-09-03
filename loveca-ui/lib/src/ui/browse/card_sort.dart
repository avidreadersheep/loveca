/// Android のカード検索の上部（`docs/Android UI 決定.md` §3-15）.
///
/// ★★ 件数と並び順だけ（§3-15）★★
/// ★**検索ボタン（詳細検索）もカメラも置かない**（★§3-18 の 6 —— ★★将来実装するかもしれない★★）。
///
/// ★★ 並び順の軸は 4 つ（§3-15）★★
///
/// | ★軸 | ★中身 |
/// |---|---|
/// | ★**収録商品** | ★`expansion` |
/// | ★**カード番号** | ★`cardNumber` |
/// | ★**カード名** | ★`name` |
/// | ★★**コスト・スコア**★★ | ★★**コスト順とスコア順を統合した 1 つの軸**★★（★メンバーはコスト、★ライブはスコア） |
///
/// ★★ 「すべて」タブのときは★種別で束ねてから並べる（§3-15）★★
/// ★**メンバー → ライブ → エネルギー**（★`CardType` の宣言順と★★同じである★★ / ★実読）。
/// ★★**束ねる向きは★昇順 / 降順で 1 ビットも変わらない**★★（★§3-15 は束ねる順を 1 つだけ挙げている）。
/// ★**対で固定した。**
///
/// ★★ 昇順 / 降順は「同じ軸を再度選ぶと反転」（§3-15）★★
/// ★**デッキ一覧（§3-9）と揃える**（★同じ規則を 2 つの語で呼ばない）。
///
/// ★★ コスト・スコアの値は★呼び出し側から受け取る ★★
/// ★**`CardListRow` は `cost` しか持たない**（★★`score` を持っていない★★ / ★実読）。
/// → ★**この層は★★値の取り方を 1 つも決めない★★**
/// （★★U21 の論点 1 に 1 ミリも触らない★★ / ★先例は `card_list_tile.dart` / `deck_stats_section.dart`）。
///
/// ★★ 値が無い行は★末尾に落とす ★★
/// ★**決定 **D99** の比較器が★★同じ規則を採っている★★**（`deck_order.dart` —— ★null は末尾）。
/// ★**降順でも末尾である**（★★「無い」を「最小」として扱わない★★ / ★対で固定した）。
library;

import 'package:flutter/material.dart';

import '../../data/card_list_row.dart';

/// 並び順の軸（§3-15）。
enum CardSortAxis {
  expansion,
  cardNumber,
  name,
  costOrScore;

  /// ★画面に出す字面。★**画面もテストもここを読む**（★書き写さない）。
  String get label => switch (this) {
        CardSortAxis.expansion => '収録商品',
        CardSortAxis.cardNumber => 'カード番号',
        CardSortAxis.name => 'カード名',
        CardSortAxis.costOrScore => 'コスト・スコア',
      };
}

/// 並び順（★軸 ＋ 向き）。
typedef CardSortOrder = ({CardSortAxis axis, bool descending});

/// ★★ 既定値。★§3-15 は★既定を述べていない ★★
/// ★**差し替え点はこの 1 か所である。**
/// ★★**収録商品順も候補である**★★（★§3-15 の表の先頭）—— ★★どちらかを選ぶ根拠が無い★★。
const CardSortOrder kDefaultCardSortOrder =
    (axis: CardSortAxis.cardNumber, descending: false);

/// 軸を押したときの次の並び順（§3-15 —— ★★同じ軸を再度選ぶと反転★★）。
///
/// ★★ 純粋関数にしてある —— ★反転の規則を widget の中に埋めると対が置けない ★★
CardSortOrder toggleCardSort(CardSortOrder current, CardSortAxis axis) =>
    current.axis == axis
        ? (axis: axis, descending: !current.descending)
        // ★★ 別の軸に移るときは★昇順から始める ★★
        //   ★**前の軸の向きを引き継がない**（★★引き継ぐと★押した軸が降順で始まりうる★★）。
        : (axis: axis, descending: false);

/// [rows] を [order] で並べる。
///
/// ★★ 純粋関数にしてある。★元の列を書き換えない ★★
/// ★[groupByType] が真のときは★★種別で束ねてから★★軸を当てる（★§3-15 の「すべて」タブ）。
/// ★[costOrScoreOf] は★★コスト・スコアの値の取り方★★（★呼び出し側が決める / ★上の doc）。
List<CardListRow> sortCardList(
  List<CardListRow> rows,
  CardSortOrder order, {
  required int? Function(CardListRow row) costOrScoreOf,
  bool groupByType = false,
}) {
  final out = [...rows];
  out.sort((a, b) {
    // ★★ 種別の束は★向きに依らない（§3-15）★★
    if (groupByType) {
      final t = a.cardType.index.compareTo(b.cardType.index);
      if (t != 0) return t;
    }
    // ★★ 値が無い行は★末尾（★★向きの反転を通さない★★ / ★決定 D99 と同じ規則）★★
    //   ★**反転の内側に置くと★★降順で先頭に来る★★**（★2026-09-03 に実測して直した /
    //   ★★書いた doc が偽だった ＝ **D-15 (j)**。★対が教えた★★）。
    final missing = _compareMissingLast(a, b, order.axis, costOrScoreOf);
    if (missing != null) return missing;
    final axis = _compareAxis(a, b, order.axis, costOrScoreOf);
    if (axis != 0) return order.descending ? -axis : axis;
    // ★★ 最後の鍵 —— ★`printingId` の昇順（★§3-15 は述べていない / ★既定値）★★
    //   ★**全順序にしないと★★同じ入力で並びが揺れる★★**（★Dart の `sort` は安定ではない）。
    //   ★**向きに依らない**（★★束ねる順と同じ扱い★★）。
    return a.printingId.compareTo(b.printingId);
  });
  return out;
}

/// 値が無い行の扱い。★★どちらも在る / どちらも無い ときは `null` を返す★★。
///
/// ★★ 値が無いのは★コスト・スコアの軸だけである ★★
/// ★**`expansion` / `cardNumber` / `name` は★★`CardListRow` で null 不可★★**（★実読）。
int? _compareMissingLast(
  CardListRow a,
  CardListRow b,
  CardSortAxis axis,
  int? Function(CardListRow row) costOrScoreOf,
) {
  if (axis != CardSortAxis.costOrScore) return null;
  final x = costOrScoreOf(a);
  final y = costOrScoreOf(b);
  if ((x == null) == (y == null)) return null;
  return x == null ? 1 : -1;
}

int _compareAxis(
  CardListRow a,
  CardListRow b,
  CardSortAxis axis,
  int? Function(CardListRow row) costOrScoreOf,
) {
  switch (axis) {
    case CardSortAxis.expansion:
      return a.expansion.compareTo(b.expansion);
    case CardSortAxis.cardNumber:
      return a.cardNumber.compareTo(b.cardNumber);
    case CardSortAxis.name:
      return a.name.compareTo(b.name);
    case CardSortAxis.costOrScore:
      // ★★ ここへ来るのは★★両方在る / 両方無い★★ときだけである
      //   （★片方だけ無い場合は [_compareMissingLast] が先に答えている）。
      final x = costOrScoreOf(a);
      final y = costOrScoreOf(b);
      if (x == null || y == null) return 0;
      return x.compareTo(y);
  }
}

/// カード検索の上部（★件数 ＋ 並び順 / §3-15）。
class CardSortHeader extends StatelessWidget {
  const CardSortHeader({
    super.key,
    required this.count,
    required this.order,
    required this.onChanged,
  });

  /// ★件数（★§3-15 —— ★★件数と並び順だけ★★）。
  final int count;

  final CardSortOrder order;
  final ValueChanged<CardSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            '$count 件',
            key: const ValueKey('cardSortHeader:count'),
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          PopupMenuButton<CardSortAxis>(
            key: const ValueKey('cardSortHeader:menu'),
            onSelected: (axis) => onChanged(toggleCardSort(order, axis)),
            itemBuilder: (context) => [
              for (final axis in CardSortAxis.values)
                PopupMenuItem(
                  key: ValueKey('cardSortHeader:axis:${axis.name}'),
                  value: axis,
                  child: Text(axis.label),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.axis.label,
                  key: const ValueKey('cardSortHeader:current'),
                  style: theme.textTheme.bodyMedium,
                ),
                Icon(
                  // ★★ 向きを絵で出す（★§3-15 は字面を述べていない / ★既定値）★★
                  order.descending ? Icons.arrow_downward : Icons.arrow_upward,
                  key: ValueKey(
                    'cardSortHeader:direction:'
                    '${order.descending ? 'desc' : 'asc'}',
                  ),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
