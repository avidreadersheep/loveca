/// R3 デッキ編集（★M2 最小版 / `docs/UI設計メモ.md` §2-2 / §2-4）.
///
/// ★★★ この画面が「作りかけ」に見えるのは意図した状態である ★★★
/// M2 の目的は「読み書きの両方が層を通る」ことの確認であって、
/// デッキを組めるようにすることではない（§2-4）。
/// 何を置き、何を置いていないかを明示する。**書いておかないと、後から見た人が
/// 未完成のコードだと誤認して作り直す。**
///
/// | M2 で置いてあるもの | M4 で足すもの |
/// |---|---|
/// | 名前・メモのドラフト編集と保存（保存で初めて `revision` +1 / §9-1） | 一覧ペイン（カードを探して足す） |
/// | 枚数と検証サマリ（`DeckValidator` を実際に呼ぶ / 決定 D55） | デッキペイン（中身の増減。`PaneScaffold` の 2 ペイン） |
/// | 論理削除（P3） | 検証パネル **P1** の常設（§2-3） |
///
/// ★M2 でも `DeckValidator` を実際に呼ぶことに意味がある。
/// M1 で `MasterCatalog` の構築までは確かめたが、**そこから `DeckValidator` を
/// 作って使う経路は一度も通っていなかった。** 表示は最小でよいが経路は通す。
///
/// ★★ ここで `PaneScaffold` を使っていないのは M2 の範囲に 2 つ目のペインが
/// 無いからである（1 ペインしか無いのに器だけ被せると、切替が実際には
/// 効いていない骨組みになり D51 の `spike/` と同じ性質で腐る）。
/// M4 で一覧ペインを足すときに `PaneScaffold` を被せる。
library;

import 'package:flutter/material.dart';
// ★`Card` は loveca_core（ルール上のカード）と Material（ウィジェット）で衝突する。
//   この画面で要るのは Material の Card なので、loveca_core 側を隠す。
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../state/app_scope.dart';
import '../../state/deck_edit_store.dart';

class DeckEditPage extends StatefulWidget {
  const DeckEditPage({super.key, required this.deck});

  final Deck deck;

  @override
  State<DeckEditPage> createState() => _DeckEditPageState();
}

class _DeckEditPageState extends State<DeckEditPage> {
  DeckEditStore? _store;
  late final TextEditingController _nameController =
      TextEditingController(text: widget.deck.name);
  late final TextEditingController _memoController =
      TextEditingController(text: widget.deck.memo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) {
      _store = DeckEditStore(AppScope.of(context).environment.decks, widget.deck);
      _store!.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _store?.dispose();
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

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeckEditState>(
        valueListenable: _store!,
        builder: (context, state, _) => Scaffold(
          appBar: AppBar(
            title: Text(state.saved.name),
            actions: [
              IconButton(
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline),
                onPressed: state.busy ? null : _delete,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                // ★テストから安定して掴むための Key。文字を入れると
                //   ラベルや中身で探す方法は次の 1 打で外れる。
                key: const Key('deckNameField'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'デッキ名'),
                // ★★ ここで保存しない ★★
                // ドラフトを差し替えるだけ。保存するたびに revision が +1 されるので、
                // キー入力ごとに保存すると Phase 4 の同期で
                // 「大量に更新された」ように見える（§9-1）。
                onChanged: _store!.setName,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('deckMemoField'),
                controller: _memoController,
                decoration: const InputDecoration(labelText: 'メモ'),
                minLines: 2,
                maxLines: 4,
                onChanged: _store!.setMemo,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: state.canSave ? _save : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存'),
                  ),
                  const SizedBox(width: 12),
                  if (state.isDirty)
                    Text(
                      '未保存の変更があります',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _ValidationSummary(validation: state.validation),
              const SizedBox(height: 28),
              _ScopeNote(revision: state.saved.revision),
            ],
          ),
        ),
      );
}

/// 検証サマリ（★M2 は件数だけ。常設の検証パネル P1 は M4）.
///
/// ★★ 判定は `loveca_core` の `DeckValidator` が唯一の実装である（決定 D28）★★
/// UI 側で 48 / 12 / 12 を再計算しない。別実装を作ると
/// 「スマホでは合法、PC では不正」という事故が起きる。
/// 数値は `DeckRepository.validate`（DB へ行かない / 決定 D55）から来ている。
class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.validation});

  final DeckValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = RuleConfig.standard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  validation.isValid ? Icons.check_circle : Icons.info_outline,
                  size: 18,
                  color: validation.isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  validation.isValid ? '構築条件を満たしています' : '構築条件を満たしていません',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 総合ルール 6.1.1.1: メンバー 48 / ライブ 12、6.1.1.3: エネルギー 12。
            // ★期待値は RuleConfig から取る。配信で置換されうる（6.1.2）。
            Text('メンバー ${validation.memberCount} / ${config.memberCount}'),
            Text('ライブ ${validation.liveCount} / ${config.liveCount}'),
            Text('エネルギー ${validation.energyCount} / ${config.energyDeckSize}'),
            if (validation.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '未達 ${validation.issues.length} 件',
                style: theme.textTheme.bodySmall,
              ),
            ],
            // ★決定 D35: マスタに無い刷りを黙って落とさない。
            if (validation.hasUnknownCards) ...[
              const SizedBox(height: 8),
              Text(
                'カードデータが未取得の刷りが '
                '${validation.unknownPrintingIds.length} 件あります',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ★★ 画面に「ここまでが M2」と書いておく ★★
/// doc コメントは実行時には見えない。**触っている人が誤解するのはコードの前ではなく
/// 画面の前**なので、範囲を画面にも出す。
class _ScopeNote extends StatelessWidget {
  const _ScopeNote({required this.revision});

  final int revision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.construction_outlined,
            size: 16, color: theme.disabledColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'カードの追加・削除はまだ実装されていません（M4 で入ります）。\n'
            'いまは名前とメモの保存・検証の確認ができます。  revision: $revision',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}
