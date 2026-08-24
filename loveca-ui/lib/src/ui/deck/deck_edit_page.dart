/// R3 デッキ編集（`docs/UI設計メモ.md` §2-2 / §2-4 / M4）.
///
/// ★★ ここが「Release 1 の骨格が端から端まで通る」確認点である（§2-4）★★
/// 探す（R4 と同じ一覧ペイン）→ 入れる（ドラッグ / 「+」）→ 検証を見る（P1）が
/// 1 画面で繋がる。M2 の最小版が置いていた「M4 で足すもの」は 3 つとも入った。
///
/// | M2 で置いてあったもの | M4 で足したもの |
/// |---|---|
/// | 名前・メモのドラフト編集と保存 | ★一覧ペイン（R4 と**同じ Widget**） |
/// | 枚数と検証サマリ | ★デッキペイン（中身の増減・並べ替え・ゴミ箱） |
/// | 論理削除（P3） | ★検証パネル **P1** の常設 |
///
/// ★★ `PaneScaffold` の判断点は 1 箇所（§2-1）★★
/// 2 ペイン: 一覧 ／ デッキ。1 ペイン: 一覧だけ出し、デッキは**同じ Widget**を
/// モーダルで出す。絞り込みも同じ扱い。**器だけ替えてルートを増やさない。**
///
/// ★1 ペインではドラッグで一覧からデッキへ持ってこられない（モーダルが覆う）。
/// **セルの「+」がその場合の追加手段**であり、だから「+」を必ず置いてある。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../data/card_list_row.dart';
import '../../state/app_scope.dart';
import '../../state/card_browse_store.dart';
import '../../state/deck_edit_store.dart';
import '../browse/card_browse_pane.dart';
import '../browse/filter_panel.dart';
import '../common/card_drag.dart';
import '../common/card_thumb.dart';
import '../detail/card_detail_pane.dart';
import '../detail/open_card_detail.dart';
import '../layout/pane_scaffold.dart';
import 'deck_drag.dart';
import 'deck_meta_dialog.dart';
import 'deck_share_import_dialog.dart';
import 'deck_pane.dart';

class DeckEditPage extends StatefulWidget {
  const DeckEditPage({super.key, required this.deck});

  final Deck deck;

  @override
  State<DeckEditPage> createState() => _DeckEditPageState();
}

class _DeckEditPageState extends State<DeckEditPage> {
  DeckEditStore? _store;
  CardBrowseStore? _browse;
  late AppScope _scope;

  /// 2 ペインで詳細を出しているカード（決定 D66）。1 ペインでは常に null。
  String? _detailPrintingId;

  late final TextEditingController _nameController =
      TextEditingController(text: widget.deck.name);
  late final TextEditingController _memoController =
      TextEditingController(text: widget.deck.memo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    if (_store == null) {
      _store = DeckEditStore(_scope.environment.decks, widget.deck);
      _store!.addListener(_onStoreChanged);
      // 環境は起動ゲートで 1 回だけ作られ以降不変（決定 D56）なので Store も 1 回だけ。
      _browse = CardBrowseStore(
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
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _store?.dispose();
    _browse?.dispose();
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;

    // ★失敗を握らない（決定 D53）。
    final failure = _store!.value.actionError;
    if (failure != null) {
      _store!.clearActionError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作に失敗しました: ${failure.$1}')),
      );
    }

    if (_store!.value.deleted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final ok = await _store!.save();
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('保存しました')));
  }

  Future<void> _delete() async {
    // ★戻す口が無いので確認を挟む（未決 U9 / `deck_list_page.dart` の doc）。
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('デッキを削除しますか'),
        content: const Text('記録としては残りますが、この画面から戻すことはできません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store!.softDelete();
  }

  void _closeDetail() => setState(() => _detailPrintingId = null);

  void _openSheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        // ★2 ペインのときと同じ Widget を出す。器だけ替える。
        child: child,
      ),
    );
  }

  Widget _deckPane() => DeckPane(
        store: _store!,
        imageSource: _scope.environment.imageSource,
        // 総合ルール 6.1.2 により置換されうるので配信の値を使う。
        config: _scope.environment.ruleConfig,
        nameController: _nameController,
        memoController: _memoController,
        onSave: _save,
        onEditMeta: _editMeta,
      );

  /// 共有形式から取り込む（M6 / 決定 D67 / D68 / D69）。
  ///
  /// ★★ ここでも保存しない ★★
  /// ドラフトを置き換えるだけ。保存ボタンを押すまで DB は変わらない。
  Future<void> _importShare() async {
    final entries = await showDeckShareImportDialog(
      context,
      catalog: _scope.environment.cardDetail,
      // ★総合ルール 6.1.2 により置換されうるので配信の値を使う。
      maxCopies: _scope.environment.ruleConfig.maxCopiesPerCardNumber,
    );
    if (entries == null || !mounted) return;
    _store!.replaceEntries(entries);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entries.length} 種類を取り込みました（未保存）'),
      ),
    );
  }

  /// P3 メタ編集（M6）。★R2 と同じダイアログを器だけ替えて開く（§2-1）。
  ///
  /// ★★ ここでは保存しない ★★
  /// R3 は「未保存」の器を持っているので、適用するのはドラフトまで。
  /// 保存ボタンが 1 回だけ `Deck` に畳む（§9-1 / 決定 D70）。
  Future<void> _editMeta() async {
    final store = _store!;
    final edited = await showDeckMetaDialog(
      context,
      draft: store.value.draft,
      catalog: _scope.environment.decks.catalogView,
      imageSource: _scope.environment.imageSource,
    );
    if (edited == null || !mounted) return;
    store.applyMeta(edited);
    // ★名前とメモは画面が自前の TextEditingController を持っている
    //   （Store の値で駆動すると打鍵中にカーソルが飛ぶ / M3）ので、
    //   ダイアログで変えたぶんはこちらから書き戻す。
    _nameController.text = edited.name;
    _memoController.text = edited.memo;
  }

  /// 一覧のセルを「掴めて + で足せる」形に包む（M4）。
  ///
  /// ★★ グリッドそのものは R4 と同じ（§2-2）★★
  /// セルの外側だけを替える。グリッドを 2 本にすると、決定 D42 の寸法の前提が
  /// 2 箇所に分かれる。
  Widget _catalogCell(CardListRow row, Widget cell) =>
      ValueListenableBuilder<DeckEditState>(
        valueListenable: _store!,
        builder: (context, state, _) {
          final theme = Theme.of(context);
          final count = state.draft.countOf(row.printingId);
          // ★総合ルール 6.1.1.2 / 6.1.1.3 の判定は DeckValidator が唯一の実装
          //   （決定 D28）。UI 側で 4 や 12 を書かない。
          final canAdd = _store!.canAdd(row.printingId);

          return CardDragSource<DeckDrag>(
            // ★テストから安定して掴むための Key（デッキ行と区別できる名前）。
            key: ValueKey('catalogCell:${row.printingId}'),
            data: CatalogCardDrag(row.printingId),
            // ★決定 D46: 掴める矩形を作る。セルの余白でも掴める。
            background: theme.colorScheme.surface,
            feedback: SizedBox(
              // ★★ feedback は箱そのものが札（決定 D72）★★
              //   枠を中に作ると宙に浮くので、箱の高さを種別で決める。
              //   ライブは 60 / 1.399 = 43、メンバー・エネルギーは 60 / 0.717 = 84。
              width: 60,
              height: 60 / cardAspectRatioOf(row.cardType),
              child: CardThumb(
                source: _scope.environment.imageSource,
                imageHash: row.imageHash,
                logicalWidth: 60,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                cell,
                if (count > 0)
                  Positioned(
                    left: 2,
                    top: 2,
                    child: _Badge(text: '$count', color: theme.colorScheme.primary),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton(
                    tooltip: canAdd ? 'デッキに入れる' : 'これ以上は入れられません',
                    icon: const Icon(Icons.add_circle),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints.tightFor(width: 28, height: 28),
                    color: theme.colorScheme.primary,
                    onPressed: canAdd
                        ? () => addCardWithFeedback(
                              context,
                              _store!,
                              row.printingId,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<DeckEditState>(
            valueListenable: _store!,
            builder: (context, state, _) => Text(state.saved.name),
          ),
          actions: [
            // ★★ 取り込みの入口はここ 1 本だけ（§2-2）★★
            //   R2 からは「新規デッキ → 開く → 取り込む」で届く。
            //   ルートを増やして分岐させない。
            IconButton(
              tooltip: '共有形式から取り込む',
              icon: const Icon(Icons.download_outlined),
              onPressed: _importShare,
            ),
            ValueListenableBuilder<DeckEditState>(
              valueListenable: _store!,
              builder: (context, state, _) => IconButton(
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline),
                onPressed: state.busy ? null : _delete,
              ),
            ),
          ],
        ),
        body: CardBrowsePane(
          store: _browse!,
          imageSource: _scope.environment.imageSource,
          secondaryWidth: kDeckPaneMinWidth,
          // ★★ 詳細は secondary を差し替える（決定 D66）★★
          //   デッキペインが一時的に隠れる。**編集は失われていない**ので、
          //   そのことを帯で出す（下の `_DeckReturnBanner`）。
          secondary: _detailPrintingId == null
              ? _deckPane()
              : _DetailWithDeckReturn(
                  store: _store!,
                  printingId: _detailPrintingId!,
                  onReturn: _closeDetail,
                ),
          cellWrapper: _catalogCell,
          onCardTap: (context, row) => openCardDetail(
            context,
            row.printingId,
            showInPane: (id) => setState(() => _detailPrintingId = id),
          ),
          // ★ここは `header` の中＝ `_PaneScope` の内側なので判定が実際に効く。
          //   AppBar に置くと `isTwoPaneOf` は常に false になる。
          headerTrailing: (context) {
            final twoPane = PaneScaffold.isTwoPaneOf(context);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '絞り込み',
                  icon: const Icon(Icons.filter_alt_outlined),
                  onPressed: () => _openSheet(FilterPanel(store: _browse!)),
                ),
                // ★1 ペインのときだけ。2 ペインでは横に出ている。
                if (!twoPane)
                  IconButton(
                    tooltip: 'デッキを見る',
                    icon: const Icon(Icons.list_alt),
                    onPressed: () => _openSheet(_deckPane()),
                  ),
              ],
            );
          },
        ),
      );
}

/// ★★ デッキペインが隠れていることを画面で分かるようにする（決定 D66）★★
///
/// デッキを編集している最中に詳細を開くとデッキペインが消えるので、
/// **保存していない編集が失われたように見える。**
/// 帯で 3 つを同時に出す。
///
/// 1. いまデッキを編集中であること
/// 2. ★**未保存の変更があるか**（デッキペインと同じ文言。M2 から出しているもの）
/// 3. ★**閉じれば戻ること**と、目立つ戻るボタン
///
/// ★2 の文言をデッキペインと揃えてあるのが要点。別の言い方にすると
/// 「さっき見ていたあれ」と結びつかない。
class _DetailWithDeckReturn extends StatelessWidget {
  const _DetailWithDeckReturn({
    required this.store,
    required this.printingId,
    required this.onReturn,
  });

  final DeckEditStore store;
  final String printingId;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ValueListenableBuilder<DeckEditState>(
          valueListenable: store,
          builder: (context, state, _) => ColoredBox(
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.edit_note,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('デッキ編集中', style: theme.textTheme.labelMedium),
                        Text(
                          // ★★ 未保存を隠さない ★★
                          //   隠すと「消えた＝失われた」と読まれる。
                          state.isDirty
                              ? '未保存の変更があります（戻れば残っています）'
                              : '閉じるとデッキに戻ります',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: onReturn,
                    child: const Text('デッキに戻る'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          // ★中身は R4 と同じ Widget（§2-2）。器が違うだけ。
          child: CardDetailPane(printingId: printingId, onClose: onReturn),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      );
}
