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
/// ★検索は M3。ここには無い。
library;

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/card_browse_store.dart';
import '../layout/pane_scaffold.dart';
import 'card_grid.dart';
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
    _store ??= CardBrowseStore(rows: _scope.environment.rows);
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
  Widget build(BuildContext context) {
    final store = _store!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('カード'),
        actions: [
          // ★1 ペインのときだけ出す。判定は PaneScaffold に任せる。
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
      body: Column(
        children: [
          Expanded(
            child: PaneScaffold(
              primary: ValueListenableBuilder<CardBrowseState>(
                valueListenable: store,
                builder: (context, state, _) => CardGrid(
                  rows: state.visible,
                  imageSource: _scope.environment.imageSource,
                ),
              ),
              secondary: FilterPanel(store: store),
            ),
          ),
        ],
      ),
    );
  }
}
