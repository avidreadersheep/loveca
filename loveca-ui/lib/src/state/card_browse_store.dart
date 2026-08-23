/// カード一覧の状態（決定 D48 / D53）.
///
/// ★★ 絞り込みはメモリ上で行う。SQL を再実行しない（決定 D48）★★
/// 実測で 100〜200 倍速い（`docs/UI技術検証メモ.md` §3-6）。
/// 全 2,527 行はすでにメモリにあるので、絞り込みで DB へ行く理由がない。
///
/// ★検索は M3。ここには入れない。
library;

import 'package:loveca_core/loveca_core.dart';

import '../data/card_list_row.dart';
import 'store.dart';

class CardBrowseState {
  const CardBrowseState({
    required this.all,
    required this.visible,
    required this.filter,
    required this.expansions,
  });

  /// 起動時に組んだ全行。★不変（決定 D56 により取り込みは起動時だけ）。
  final List<CardListRow> all;

  /// 絞り込み後。
  final List<CardListRow> visible;

  final CardListFilter filter;

  /// 絞り込みに使える商品。
  final List<String> expansions;

  int get totalCount => all.length;
  int get visibleCount => visible.length;
  bool get isFiltered => !filter.isEmpty;
}

class CardBrowseStore extends Store<CardBrowseState> {
  CardBrowseStore({
    required List<CardListRow> rows,
    CardListFilter filter = const CardListFilter(),
  }) : super(CardBrowseState(
          all: rows,
          visible: filter.apply(rows),
          filter: filter,
          expansions: _expansionsOf(rows),
        ));

  /// ★商品の一覧もメモリから作る。DB へ行く理由がない（決定 D48）。
  static List<String> _expansionsOf(List<CardListRow> rows) =>
      (rows.map((r) => r.expansion).toSet().toList()..sort());

  void _apply(CardListFilter next) {
    final current = value;
    state = CardBrowseState(
      all: current.all,
      visible: next.apply(current.all),
      filter: next,
      expansions: current.expansions,
    );
  }

  void setExpansion(String? expansion) => _apply(
        expansion == null
            ? value.filter.copyWith(clearExpansion: true)
            : value.filter.copyWith(expansion: expansion),
      );

  /// ★種別を変えるとコスト絞り込みの可否が変わる（`CardListFilter.appliesCost`）。
  /// メンバー以外にしたときはコストを外す。**残したまま無効化すると、
  /// 画面に出ていない条件が状態にだけ残る。**
  void setCardType(CardType? cardType) {
    final base = cardType == null
        ? value.filter.copyWith(clearCardType: true)
        : value.filter.copyWith(cardType: cardType);
    _apply(
      cardType == CardType.member ? base : base.copyWith(clearMaxCost: true),
    );
  }

  void setMaxCost(int? maxCost) => _apply(
        maxCost == null
            ? value.filter.copyWith(clearMaxCost: true)
            : value.filter.copyWith(maxCost: maxCost),
      );

  /// ★false のとき `isParallel == false` の刷りを「すべて」残す（CLAUDE.md §5-(4)）。
  void setShowParallel(bool showParallel) =>
      _apply(value.filter.copyWith(showParallel: showParallel));

  void clearFilter() => _apply(const CardListFilter());
}
