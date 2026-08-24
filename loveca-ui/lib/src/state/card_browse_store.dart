/// カード一覧と検索の状態（決定 D40 / D44 / D48 / D50 / D53）.
///
/// ★★ 絞り込みはメモリ上で行う。SQL を再実行しない（決定 D48）★★
/// 実測で 100〜200 倍速い（`docs/UI技術検証メモ.md` §3-6）。
/// 全 2,527 行はすでにメモリにあるので、絞り込みで DB へ行く理由がない。
///
/// ★★ 検索だけは DB へ行く（M3）★★
/// FTS5 の trigram 索引は SQLite の中にしか無い。したがって検索は非同期で、失敗しうる。
/// 絞り込み（同期・純関数）と検索（非同期・失敗しうる）を**同じ型で表さない**。
///
/// ★★ 「空」と「失敗」を同じ型で表さない（決定 D53）★★
/// [CardBrowseState.visible] は `Loadable`。リポジトリは例外を握らず、ここが `Failed` へ写す。
///
/// ★★ 縮退は `Loadable` とは別枠で持つ（`docs/UI設計メモ.md` §3-4(3)）★★
/// `Ready` に畳み込むと「成功したが不完全」が「成功」と区別できなくなる。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import '../data/card_catalog_repository.dart';
import '../data/card_list_row.dart';
import '../data/search_limit.dart';
import '../ui/common/debouncer.dart';
import 'search_degradation.dart';
import 'store.dart';

class CardBrowseState {
  const CardBrowseState({
    required this.all,
    required this.visible,
    required this.filter,
    required this.expansions,
    required this.query,
    required this.degradations,
  });

  /// 起動時に組んだ全行。★不変（決定 D56 により取り込みは起動時だけ）。
  final List<CardListRow> all;

  /// 絞り込み（同期）と検索（非同期）を掛けた結果。
  final Loadable<List<CardListRow>> visible;

  final CardListFilter filter;

  /// 絞り込みに使える商品。
  final List<String> expansions;

  /// ★いま画面に出ている結果を作った検索語。**入力中の生の文字列ではない**
  /// （デバウンスの待ち時間だけ遅れて追いつく / 決定 D44）。
  final String query;

  /// ★エラーではないが結果が完全でないこと（決定 D40 / D50 / D-8）。
  final List<SearchDegradation> degradations;

  int get totalCount => all.length;

  /// ★`Ready` のときだけ件数が言える。
  /// 検索中や失敗時に 0 を返すと、「0 件だった」と区別がつかなくなる。
  int? get visibleCount => switch (visible) {
        Ready<List<CardListRow>>(:final value) => value.length,
        _ => null,
      };

  bool get isFiltered => !filter.isEmpty;
  bool get hasQuery => query.trim().isNotEmpty;

  CardBrowseState copyWith({
    Loadable<List<CardListRow>>? visible,
    CardListFilter? filter,
    String? query,
    List<SearchDegradation>? degradations,
  }) =>
      CardBrowseState(
        all: all,
        visible: visible ?? this.visible,
        filter: filter ?? this.filter,
        expansions: expansions,
        query: query ?? this.query,
        degradations: degradations ?? this.degradations,
      );
}

class CardBrowseStore extends Store<CardBrowseState> {
  CardBrowseStore({
    required List<CardListRow> rows,
    required this.catalog,
    required this.searchLimit,
    CardListFilter filter = const CardListFilter(),
    Debouncer? debouncer,
  })  : _debouncer = debouncer ?? Debouncer(),
        // ★★ 起動時に 1 回だけ組む（決定 D55 / §4-3 と同じ考え方）★★
        //   `all` はセッション中ずっと不変（決定 D56）なので、
        //   **無効化そのものが要らない。**
        _knownCardNumbers = {for (final r in rows) r.cardNumber},
        super(CardBrowseState(
          all: rows,
          visible: Ready(filter.apply(rows)),
          filter: filter,
          expansions: _expansionsOf(rows),
          query: '',
          degradations: const [],
        ));

  /// 検索の口。★UI は DAO を直接呼ばない（決定 D55）。
  final CardCatalogRepository catalog;

  /// 実効上限とその出所（決定 D50 / D64）。
  final SearchLimitSetting searchLimit;

  final Debouncer _debouncer;

  /// 一覧に刷りがある cardNumber。★D-8 の検出に使う。
  final Set<String> _knownCardNumbers;

  /// 直近の検索が当てた cardNumber。null は「検索していない（＝全件が対象）」。
  Set<String>? _hits;

  /// ★遅れて届いた古い結果で新しい結果を上書きしないための通し番号。
  /// デバウンスがあっても、遅い検索の直後に速い検索が返れば順序は入れ替わりうる。
  /// 上書きされると「打った語と違う結果が出ている」が無言で起きる。
  int _seq = 0;

  /// ★商品の一覧もメモリから作る。DB へ行く理由がない（決定 D48）。
  static List<String> _expansionsOf(List<CardListRow> rows) =>
      (rows.map((r) => r.expansion).toSet().toList()..sort());

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 検索（非同期）
  // ---------------------------------------------------------------------------

  /// 入力のたびに呼ぶ。★実際に検索が走るのは 150 ms 後（決定 D44）。
  void setQuery(String raw) => _debouncer.run(() => search(raw));

  /// デバウンスを介さずに検索する。★テストと、明示的な再検索のための入口。
  Future<void> search(String raw) async {
    final seq = ++_seq;
    final before = value;

    state = before.copyWith(
      query: raw,
      visible: const Loading(),
      // ★古い縮退を残さない。残すと「前の検索の打ち切り」が
      //   いまの検索の結果として読まれる。
      degradations: const [],
    );

    final CardSearchResult result;
    try {
      result = await catalog.search(raw, limit: searchLimit.limit);
    } on Object catch (error, stackTrace) {
      if (seq != _seq) return;
      // ★0 件にすり替えない（決定 D53）。利用者が「そのカードは無い」と誤解する。
      state = value.copyWith(visible: Failed(error, stackTrace));
      return;
    }

    if (seq != _seq) return;

    // ★空の検索語は「絞り込みなし」であって「0 件」ではない。
    _hits =
        result.mode == CardSearchMode.empty ? null : result.cardNumbers.toSet();

    final current = value;
    state = current.copyWith(
      visible: Ready(_compose(current.all, current.filter)),
      degradations: _degradationsOf(result),
    );
  }

  /// 検索結果から縮退を組み立てる。★3 つは独立に立つ（同時に立ちうる）。
  List<SearchDegradation> _degradationsOf(CardSearchResult result) {
    final out = <SearchDegradation>[];

    if (result.truncated) {
      out.add(SearchTruncated(
        shown: result.length,
        limit: searchLimit.limit,
        limitOverridden: searchLimit.isOverridden,
      ));
    }
    if (result.mode == CardSearchMode.likeFallback) {
      out.add(const SearchLikeFallback());
    }

    // ★★ 絞り込み前の全行に対して数える ★★
    // 絞り込み後で数えると、フィルタで消えただけの刷りまで
    // 「表示できないカード」に化ける。
    if (result.mode != CardSearchMode.empty) {
      final missing = result.cardNumbers
          .where((n) => !_knownCardNumbers.contains(n))
          .length;
      if (missing > 0) out.add(SearchMissingCards(missing));
    }

    return out;
  }

  /// 絞り込み（同期）と検索結果（cardNumber）を掛け合わせる。
  ///
  /// ★刷りへの展開は呼び出し側の責務（`card_search_dao.dart:212-215`）。
  /// 実測 0.00〜0.13ms（`docs/UI技術検証メモ.md` §4-2）で、設計上の考慮は要らない。
  List<CardListRow> _compose(List<CardListRow> all, CardListFilter filter) {
    final filtered = filter.apply(all);
    final hits = _hits;
    if (hits == null) return filtered;
    return filtered
        .where((r) => hits.contains(r.cardNumber))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // 絞り込み（同期・メモリ上 / 決定 D48）
  // ---------------------------------------------------------------------------

  void _apply(CardListFilter next) {
    final current = value;
    state = current.copyWith(
      filter: next,
      // ★検索中は結果がまだ無い。ここで古い hits から作ると
      //   「検索中なのに結果が出ている」ことになる。
      visible: switch (current.visible) {
        Ready<List<CardListRow>>() => Ready(_compose(current.all, next)),
        final other => other,
      },
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
