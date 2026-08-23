/// R4 カード閲覧（`docs/UI設計メモ.md` §2-2）.
///
/// ★★ 絞り込みパネルを `PaneScaffold` の secondary にする ★★
/// そうしないと `PaneScaffold` が M1 で実際には使われない骨組みになり、
/// **決定 D51 の `spike/` と同じ性質で静かに腐る。**
/// 狭いときは AppBar のボタンからモーダルで同じ Widget を出す。
///
/// ★M1 のホームはこの画面。R2（デッキ一覧）は M2 なので、それまでの暫定。
/// ★検索は M3。ここには無い。
library;

import 'package:flutter/material.dart';

import '../../boot/boot_steps.dart';
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
    final notices = _scope.notices;

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
          // ★決定 D39 / D60: 起動時の警告を黙って捨てない。
          if (notices.isNotEmpty) _NoticeBar(notices: notices),
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

/// 起動時の「エラーではないが伝えるべきこと」（`docs/UI設計メモ.md` §3-4(3)）。
class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.notices});

  final List<BootNotice> notices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notices.map((n) => n.message).join(' / '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (notices.any((n) => n.details.isNotEmpty))
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _NoticeDialog(notices: notices),
                ),
                child: const Text('詳細'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog({required this.notices});

  final List<BootNotice> notices;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('起動時の警告'),
        content: SizedBox(
          width: 560,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final notice in notices) ...[
                Text(notice.message,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                // ★探した場所や失敗したファイルを省かない。
                for (final detail in notice.details)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: SelectableText('・$detail',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
}
