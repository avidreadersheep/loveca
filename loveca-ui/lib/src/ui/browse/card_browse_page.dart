/// R4 カード閲覧（`docs/UI設計メモ.md` §2-2）.
///
/// ★M2 でホームは R2（デッキ一覧）に移った。この画面へは R2 の AppBar から入る。
///
/// ★★ 起動時の警告（BootNotice）はここに置かない ★★
/// M1 ではこの画面が暫定のホームだったので `_NoticeBar` を持っていたが、
/// ホームが R2 に移った以上ここに置くと**この画面へ来ない限り警告が見えない。**
/// 決定 D39 / D60 の「記録するだけで誰も見ない状態にしない」に触れるため、
/// `ui/common/notice_bar.dart` へ出して R2 に置いた。
///
/// ★★ M4: 中身を `CardBrowsePane` へ出した ★★
/// R3（デッキ編集）が**同じ一覧ペイン**を置くため（§2-2「ルートを増やして
/// 分岐させない」）。この画面に残っているのは器だけ——
/// AppBar と、横に並べるもの（絞り込みパネル）の指定である。
///
/// ★★ M4: 絞り込みボタンを `PaneScaffold.header` へ移した（不具合の修正）★★
/// M3 までは `Scaffold.appBar` に置いており、`_PaneScope` は body の中にしか
/// 無いので `isTwoPaneOf` が**常に false** だった。結果として
/// 「1 ペインのときだけ出す」が効かず、**2 ペインで絞り込みパネルが
/// 見えているのに同じものを開くボタンも出ていた。**
library;

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/card_browse_store.dart';
import '../layout/pane_scaffold.dart';
import 'card_browse_pane.dart';
import 'filter_panel.dart';

class CardBrowsePage extends StatefulWidget {
  const CardBrowsePage({super.key});

  @override
  State<CardBrowsePage> createState() => _CardBrowsePageState();
}

class _CardBrowsePageState extends State<CardBrowsePage> {
  CardBrowseStore? _store;
  late AppScope _scope;

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('カード')),
        body: CardBrowsePane(
          store: _store!,
          imageSource: _scope.environment.imageSource,
          secondary: FilterPanel(store: _store!),
          // ★1 ペインのときだけ出す。判定は PaneScaffold に任せる。
          //   ここは `header` の中＝ `_PaneScope` の内側なので判定が実際に効く。
          headerTrailing: (context) => PaneScaffold.isTwoPaneOf(context)
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: '絞り込み',
                  icon: const Icon(Icons.filter_alt_outlined),
                  onPressed: _openFilterSheet,
                ),
        ),
      );
}
