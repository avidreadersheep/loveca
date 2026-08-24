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

import '../../data/card_list_row.dart';
import '../../state/app_scope.dart';
import '../../state/card_browse_store.dart';
import '../detail/card_detail_pane.dart';
import '../detail/open_card_detail.dart';
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

  /// 2 ペインで詳細を出しているカード（決定 D66）。
  ///
  /// ★★ 1 ペインでは常に null ★★
  /// 1 ペインは R5 ルートを push するので、ここに値が入る経路が無い
  /// （`openCardDetail` が分ける / §2-1 の判断点 1 箇所）。
  String? _detailPrintingId;

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
      // ★★ 設定を読む（M6）★★
      //   `AppSettings.showParallel` は M5 まで**保存されるだけで
      //   読まれていなかった。** 設定項目が死んでいる状態であり、
      //   「設定したのに効かない」が原因不明のまま残る形そのもの。
      filter: CardListFilter(
        showParallel: _scope.environment.settings.showParallel,
      ),
    );
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  void _closeDetail() => setState(() => _detailPrintingId = null);

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
          // ★★ 詳細は secondary を差し替える（決定 D66）★★
          //   一覧（primary）を残すのが目的。閲覧の主目的は見比べることなので、
          //   一覧を潰すと詳細を見ながら次を選べない。
          secondary: _detailPrintingId == null
              ? FilterPanel(store: _store!)
              : CardDetailPane(
                  printingId: _detailPrintingId!,
                  onClose: _closeDetail,
                ),
          onCardTap: (context, row) => openCardDetail(
            context,
            row.printingId,
            showInPane: (id) => setState(() => _detailPrintingId = id),
          ),
          // ★横に絞り込みが「見えていないとき」だけ出す。
          //   2 ペインでも詳細を出している間は絞り込みが隠れているので出す。
          //   ここは `header` の中＝ `_PaneScope` の内側なので判定が実際に効く。
          headerTrailing: (context) =>
              PaneScaffold.isTwoPaneOf(context) && _detailPrintingId == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: '絞り込み',
                      icon: const Icon(Icons.filter_alt_outlined),
                      onPressed: _openFilterSheet,
                    ),
        ),
      );
}
