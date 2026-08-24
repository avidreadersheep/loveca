/// 一覧ペイン（`docs/UI設計メモ.md` §2-2 / M4）.
///
/// ★★ R3（デッキ編集）と R4（カード閲覧）が**同じものを置く** ★★
/// 「同じ Widget を器だけ替えて置き、ルートを増やして分岐させない」（§2-1）。
/// 違うのは横に何を並べるか（[secondary]）だけで、
/// R4 は絞り込みパネル、R3 はデッキペインを渡す。
///
/// ★★ 検索欄と結果ヘッダは `PaneScaffold.header` に置く ★★
/// どちらのペインの中にも入れない。中に入れると
/// 1 ペインのときにしか見えない／2 ペインのときだけ位置が変わる、という
/// 器ごとの差が出る。**縮退の表示は器に依らず常に同じ場所に出す。**
/// `header` なら全幅で両ペインの上に載り、かつ `isTwoPaneOf` が読める。
library;

import 'package:flutter/material.dart';

import '../../data/card_image_source.dart';
import '../../data/card_list_row.dart';
import '../../state/card_browse_store.dart';
import '../common/loadable_view.dart';
import '../layout/pane_scaffold.dart';
import 'card_grid.dart';
import 'search_result_header.dart';

class CardBrowsePane extends StatefulWidget {
  const CardBrowsePane({
    super.key,
    required this.store,
    required this.imageSource,
    required this.secondary,
    this.secondaryWidth = 320,
    this.cellWrapper,
    this.onCardTap,
    this.headerTrailing,
  });

  final CardBrowseStore store;
  final CardImageSource imageSource;

  /// 2 ペインのときに横へ並ぶもの。R4 は絞り込み、R3 はデッキ。
  final Widget secondary;

  final double secondaryWidth;

  /// セルを包む口。R3 が掴めるセルにするために使う（M4）。
  final Widget Function(CardListRow row, Widget cell)? cellWrapper;

  /// セルを叩いたとき（M5 / R5）。★R3 / R4 が同じ `openCardDetail` を呼ぶ。
  final void Function(BuildContext context, CardListRow row)? onCardTap;

  /// 検索欄の右に置くボタン。
  ///
  /// ★★ この builder は `PaneScaffold` の**内側**で呼ばれる ★★
  /// つまり `PaneScaffold.isTwoPaneOf(context)` が読める。
  /// AppBar に置くと `_PaneScope` に届かず**常に false** になる（M4 で直した不具合）。
  final Widget Function(BuildContext context)? headerTrailing;

  @override
  State<CardBrowsePane> createState() => _CardBrowsePaneState();
}

class _CardBrowsePaneState extends State<CardBrowsePane> {
  /// ★入力欄は自前の Controller を持つ（Store の `query` で駆動しない）。
  /// Store の `query` はデバウンス後に追いつく値なので、
  /// それを `TextField` に流すと**打鍵中にカーソルが飛ぶ。**
  final TextEditingController _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CardBrowseState>(
        valueListenable: widget.store,
        builder: (context, state, _) => PaneScaffold(
          secondaryWidth: widget.secondaryWidth,
          header: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      // ★消去ボタンの出し入れは打鍵ごとに要るが、Store は
                      //   デバウンス後にしか動かない（決定 D44）。Controller を直接聴く。
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _queryController,
                        builder: (context, text, _) => TextField(
                          key: const Key('cardSearchField'),
                          controller: _queryController,
                          // ★実際に検索が走るのは 150ms 後（決定 D44）。
                          onChanged: widget.store.setQuery,
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'カード名・効果・グループで検索',
                            suffixIcon: text.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '検索語を消す',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _queryController.clear();
                                      widget.store.setQuery('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.headerTrailing case final builder?)
                      Builder(builder: builder),
                  ],
                ),
              ),
              SearchResultHeader(state: state),
            ],
          ),
          // ★★ `LoadableView` が唯一の描画口（決定 D53）★★
          //   `onError` を渡さない = 失敗は既定でエラー表示になる。
          //   握り潰すには 1 行明示的に書く必要があり、レビューで見える。
          primary: LoadableView<List<CardListRow>>(
            loadable: state.visible,
            ready: (rows) => CardGrid(
              rows: rows,
              imageSource: widget.imageSource,
              cellWrapper: widget.cellWrapper,
              onCardTap: widget.onCardTap,
            ),
          ),
          secondary: widget.secondary,
        ),
      );
}
