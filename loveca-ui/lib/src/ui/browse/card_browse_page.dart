/// R4 カード閲覧（`docs/UI設計メモ.md` §2-2）.
///
/// ★★ 絞り込みパネルを `PaneScaffold` の secondary にする ★★
/// そうしないと `PaneScaffold` が M1 で実際には使われない骨組みになり、
/// **決定 D51 の `spike/` と同じ性質で静かに腐る。**
/// 狭いときは AppBar のボタンからモーダルで同じ Widget を出す。
///
/// ★M2 でホームは R2（デッキ一覧）に移った。この画面へは R2 の AppBar から入る。
///
/// ★★ 起動時の警告（BootNotice）はここに置かない ★★
/// M1 ではこの画面が暫定のホームだったので `_NoticeBar` を持っていたが、
/// ホームが R2 に移った以上ここに置くと**この画面へ来ない限り警告が見えない。**
/// 決定 D39 / D60 の「記録するだけで誰も見ない状態にしない」に触れるため、
/// `ui/common/notice_bar.dart` へ出して R2 に置いた。
///
/// ★★ M3: 検索を足した ★★
/// 検索欄と結果ヘッダは**どちらのペインの中にも入れない**。
/// 中に入れると 1 ペインのときにしか見えない／2 ペインのときだけ位置が変わる、
/// といった器ごとの差が出る。**縮退の表示は器に依らず常に同じ場所に出す。**
///
/// ★★ M4 で `PaneScaffold.header` へ移した（不具合の修正）★★
/// M3 は上記を「`PaneScaffold` の外に置く」形で実現していたが、そのせいで
/// **絞り込みボタンが `Scaffold.appBar` に置かれ、`isTwoPaneOf` が常に false** だった。
/// `_PaneScope` は `PaneScaffold` の内側にしか無いので、AppBar からは辿れない。
/// 結果として「1 ペインのときだけ出す」が効かず、**2 ペインで絞り込みパネルが
/// 見えているのに、同じものを開くボタンも出ていた。**
/// `header` は全幅・両ペインの上・かつ `_PaneScope` の内側なので、両方を満たす。
library;

import 'package:flutter/material.dart';

import '../../data/card_list_row.dart';
import '../../state/app_scope.dart';
import '../../state/card_browse_store.dart';
import '../common/loadable_view.dart';
import '../layout/pane_scaffold.dart';
import 'card_grid.dart';
import 'filter_panel.dart';
import 'search_result_header.dart';

class CardBrowsePage extends StatefulWidget {
  const CardBrowsePage({super.key});

  @override
  State<CardBrowsePage> createState() => _CardBrowsePageState();
}

class _CardBrowsePageState extends State<CardBrowsePage> {
  CardBrowseStore? _store;
  late AppScope _scope;

  /// ★入力欄は自前の Controller を持つ（Store の `query` で駆動しない）。
  /// Store の `query` はデバウンス後に追いつく値なので、
  /// それを `TextField` に流すと**打鍵中にカーソルが飛ぶ。**
  final TextEditingController _queryController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    // 環境は起動ゲートで 1 回だけ作られ以降不変（決定 D56）なので、
    // Store も 1 回だけ作れば足りる。
    _store ??= CardBrowseStore(
      rows: _scope.environment.rows,
      catalog: _scope.environment.cardCatalog,
      searchLimit: _scope.environment.searchLimit,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _store?.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        // ★2 ペインのときと同じ Widget を出す。器だけ替える。
        child: FilterPanel(store: _store!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _store!;

    return Scaffold(
      appBar: AppBar(title: const Text('カード')),
      body: ValueListenableBuilder<CardBrowseState>(
        valueListenable: store,
        builder: (context, state, _) => PaneScaffold(
          // ★器に依らず常に同じ場所に出る。かつ isTwoPaneOf が読める（M4）。
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
                          onChanged: store.setQuery,
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
                                      store.setQuery('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // ★1 ペインのときだけ出す。判定は PaneScaffold に任せる。
                    //   ここは _PaneScope の内側なので、判定が実際に効く。
                    Builder(
                      builder: (context) => PaneScaffold.isTwoPaneOf(context)
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: '絞り込み',
                              icon: const Icon(Icons.filter_alt_outlined),
                              onPressed: _openFilterSheet,
                            ),
                    ),
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
              imageSource: _scope.environment.imageSource,
            ),
          ),
          secondary: FilterPanel(store: store),
        ),
      ),
    );
  }
}
