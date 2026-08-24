/// R2 デッキ一覧（★ホーム / `docs/UI設計メモ.md` §2-2）.
///
/// ★★ ホームはデッキ一覧である ★★
/// アプリの目的がデッキ構築だから（§2-2）。M1 では R2 がまだ無かったので
/// R4（カード閲覧）を暫定のホームにしていたが、M2 で本来の構成に戻す。
///
/// ★M2 の範囲は「作る / 開く / 一覧 / 論理削除」。
/// M6 で複製・共有形式の書き出し・メタ編集・R6 への導線を足した（§2-2）。
///
/// ★★ 論理削除には戻す口が無い ★★
/// `deletedAt` を立てるだけなので DB には行が残る（P3。物理削除すると
/// 削除が同期で伝播しない）が、**それを戻す操作が存在しない。**
/// 誤操作の手当てとして確認ダイアログを 1 枚挟んである。
/// ★★ M6 でも入れなかった（未決 **U9**）★★
/// `DeckDao.softDelete` が `revision` を上げない（**D-9**）のが未解決で、
/// 復元時に `revision` をどう扱うかはその判断が先に要る。
/// 決めないまま復元を作ると、Phase 4 の同期で**削除と復元の差分検出が
/// 両方壊れる。** → 判断は **D-9 を決めたとき（Phase 4）**。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/deck_repository.dart';
import '../../state/app_scope.dart';
import '../../state/deck_list_store.dart';
import '../browse/card_browse_page.dart';
import '../common/loadable_view.dart';
import '../common/notice_bar.dart';
import '../settings/settings_page.dart';
import 'deck_edit_page.dart';
import 'deck_meta_dialog.dart';
import 'deck_share_export_dialog.dart';

class DeckListPage extends StatefulWidget {
  const DeckListPage({super.key});

  @override
  State<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends State<DeckListPage> {
  DeckListStore? _store;
  late AppScope _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AppScope.of(context);
    // 環境は起動ゲートで 1 回だけ作られ以降不変（決定 D56）なので Store も 1 回だけ。
    if (_store == null) {
      _store = DeckListStore(_scope.environment.decks)..load();
      _store!.addListener(_showActionErrorIfAny);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_showActionErrorIfAny);
    _store?.dispose();
    super.dispose();
  }

  /// ★作成 / 削除の失敗を握らない（決定 D53）。
  /// 一覧は読めているので `Loadable` を倒さず、別枠で必ず出す（§3-4(3)）。
  void _showActionErrorIfAny() {
    final failure = _store?.value.actionError;
    if (failure == null || !mounted) return;
    _store!.clearActionError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作に失敗しました: ${failure.$1}')),
    );
  }

  Future<void> _createDeck() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _DeckNameDialog(),
    );
    if (name == null || !mounted) return;

    final created = await _store!.create(name);
    if (created == null || !mounted) return;
    await _openDeck(created);
  }

  Future<void> _openDeck(Deck deck) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DeckEditPage(deck: deck)),
    );
    // ★名前が変わったかもしれないし、削除されたかもしれない。DB を正とする。
    if (mounted) await _store!.load();
  }

  /// P3 メタ編集（M6）。★R3 と同じダイアログを器だけ替えて使う（§2-1）。
  ///
  /// ★R2 には「未保存」の器が無いので、決定がそのまま保存 1 回に相当する。
  Future<void> _editMeta(Deck deck) async {
    final env = _scope.environment;
    final edited = await showDeckMetaDialog(
      context,
      draft: DeckDraft.of(deck),
      catalog: env.decks.catalogView,
      imageSource: env.imageSource,
    );
    if (edited == null || !mounted) return;
    await _store!.saveMeta(deck, edited);
  }

  /// 複製（決定 D71 / M6）。
  ///
  /// ★共有形式では同じ cardNumber の別の刷りが合算されて潰れる。
  /// 刷りを保ったまま写せるのはこちらだけ。
  Future<void> _duplicateDeck(Deck deck) async {
    await _store!.duplicate(deck, name: '${deck.name} のコピー');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('複製しました')),
      );
    }
  }

  /// 共有形式をコピーする（決定 D67 / D35）。
  Future<void> _shareDeck(Deck deck) => showDeckShareExportDialog(
        context,
        deck: deck,
        printings: _scope.environment.printings,
      );

  Future<void> _deleteDeck(Deck deck) async {
    // ★★ 戻す口が無いので確認を 1 枚挟む（未決 U9）★★
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('デッキを削除しますか'),
        content: Text(
          '「${deck.name}」を削除します。\n'
          '記録としては残りますが、この画面から戻すことはできません。',
        ),
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
    await _store!.softDelete(deck.deckId);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('デッキ'),
        actions: [
          // ★R4 をホームから外したので、ここが唯一の導線になる。
          //   無いと M1 の一覧が到達不能になる。
          IconButton(
            tooltip: 'カードを見る',
            icon: const Icon(Icons.style_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const CardBrowsePage()),
            ),
          ),
          // ★★ R6 の入口は R2 だけにしてある ★★
          //   R3（未保存の編集がありうる）の上に積むと、
          //   R6 の「アプリを終了する」が編集を巻き添えにする。
          _SettingsAction(scope: _scope),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDeck,
        icon: const Icon(Icons.add),
        label: const Text('新規デッキ'),
      ),
      body: Column(
        children: [
          // ★決定 D39 / D60: 起動時の警告を黙って捨てない。
          //   ホームに出さないと誰も読まない。
          NoticeBar(notices: _scope.notices),
          Expanded(
            child: ValueListenableBuilder<DeckListState>(
              valueListenable: store,
              builder: (context, state, _) =>
                  // ★onError を渡さない = 既定でエラーが出る（決定 D53 / §3-4(1)）。
                  LoadableView<List<Deck>>(
                loadable: state.decks,
                ready: (decks) => decks.isEmpty
                    ? const _EmptyDecks()
                    : _DeckList(
                        decks: decks,
                        onOpen: _openDeck,
                        onDelete: _deleteDeck,
                        onEditMeta: _editMeta,
                        onDuplicate: _duplicateDeck,
                        onShare: _shareDeck,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// R6 への導線と、取り込み失敗のバッジ（決定 D39 / §2-3 の P2）。
///
/// ★★ 0 件のときはバッジを出さない ★★
/// 常に丸が付いていると、それは「何も言っていない」のと同じになる。
class _SettingsAction extends StatelessWidget {
  const _SettingsAction({required this.scope});

  final AppScope scope;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: '設定・診断',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      ),
    );

    // ★`Stream<int>` は drift の型ではないのでそのまま通してよい（§4-2）。
    return StreamBuilder<int>(
      stream: scope.environment.master.watchOutstandingImportIssueCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return button;
        return Badge.count(count: count, child: button);
      },
    );
  }
}

class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.decks,
    required this.onOpen,
    required this.onDelete,
    required this.onEditMeta,
    required this.onDuplicate,
    required this.onShare,
  });

  final List<Deck> decks;
  final void Function(Deck) onOpen;
  final void Function(Deck) onDelete;
  final void Function(Deck) onEditMeta;
  final void Function(Deck) onDuplicate;
  final void Function(Deck) onShare;

  @override
  Widget build(BuildContext context) => ListView.separated(
        itemCount: decks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final deck = decks[i];
          return ListTile(
            title: Text(deck.name),
            subtitle: Text(
              // ★合計枚数は Deck が持っている（区分の内訳は R3 で出す）。
              '${deck.totalCount} 枚 ・ 更新 ${_formatDate(deck.updatedAt)}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'このデッキの操作',
              onSelected: (v) => switch (v) {
                'meta' => onEditMeta(deck),
                'duplicate' => onDuplicate(deck),
                'share' => onShare(deck),
                _ => onDelete(deck),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'meta', child: Text('情報を編集')),
                PopupMenuItem(value: 'duplicate', child: Text('複製')),
                PopupMenuItem(value: 'share', child: Text('共有形式をコピー')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
            onTap: () => onOpen(deck),
          );
        },
      );
}

/// ★「空」を「失敗」と同じ見た目にしない（§3-4(2)）。
/// 同じにすると利用者は「壊れている」と誤解する。
class _EmptyDecks extends StatelessWidget {
  const _EmptyDecks();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 40, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            const Text('デッキがまだありません'),
            const SizedBox(height: 4),
            Text(
              '「新規デッキ」から作れます',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _DeckNameDialog extends StatefulWidget {
  const _DeckNameDialog();

  @override
  State<_DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<_DeckNameDialog> {
  final _controller = TextEditingController(text: '新しいデッキ');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('新規デッキ'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'デッキ名'),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('やめる'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, v, _) => FilledButton(
              // ★名前が空のまま作らせない。
              onPressed: v.text.trim().isEmpty ? null : _submit,
              child: const Text('作る'),
            ),
          ),
        ],
      );
}

/// ★日時の表示は UTC のまま出さない。`Deck.updatedAt` は UTC で保存されている
/// （`DeckDao` が正規化する）ので、表示のときだけローカルに直す。
String _formatDate(DateTime utc) {
  final t = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
