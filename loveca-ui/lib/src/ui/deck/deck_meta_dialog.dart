/// P3 デッキのメタ編集（`docs/UI設計メモ.md` §2-3 / M6）.
///
/// ★★ これが無いと DB の列が死ぬ ★★
/// `decks.memo` / `deck_tags` / `decks.cover_printing_id` は
/// `DeckDao.save` が書ける（`deck_dao.dart:77-106`）のに、M5 まで
/// **UI に編集口が無かった。**
///
/// ★★ `DeckDraft` を受け取り `DeckDraft` を返す純粋な部品にしてある ★★
/// R2（一覧）と R3（編集）の両方から**同じダイアログ**を使う。
/// 器だけ替えて置く、という §2-1 の方針をダイアログにも通す。
/// 違うのは**保存のタイミングだけ**である。
///
/// | どこから | 押したあと |
/// |---|---|
/// | R3 | ドラフトへ適用する。保存ボタンを押すまで書かない（未保存表示が出る） |
/// | R2 | 「未保存」の器が無いので、その場で保存 1 回に相当させる |
///
/// ★★ どちらも `Deck` を畳むのは 1 回だけ ★★
/// 打鍵のたびに `copyWith` すると `revision` が跳ね、Phase 4 の同期で
/// 「大量に更新された」ように見える（§9-1）。
/// このダイアログは自分の中でだけ編集し、閉じるときに 1 個の
/// `DeckDraft` を返す。
library;

import 'package:flutter/material.dart';

import '../../data/card_image_source.dart';
import '../../data/deck_repository.dart';
import '../common/card_thumb.dart';

/// 編集して返す。やめたら null。
Future<DeckDraft?> showDeckMetaDialog(
  BuildContext context, {
  required DeckDraft draft,
  required DeckCatalogView catalog,
  required CardImageSource imageSource,
}) =>
    showDialog<DeckDraft>(
      context: context,
      builder: (_) => _DeckMetaDialog(
        draft: draft,
        catalog: catalog,
        imageSource: imageSource,
      ),
    );

class _DeckMetaDialog extends StatefulWidget {
  const _DeckMetaDialog({
    required this.draft,
    required this.catalog,
    required this.imageSource,
  });

  final DeckDraft draft;
  final DeckCatalogView catalog;
  final CardImageSource imageSource;

  @override
  State<_DeckMetaDialog> createState() => _DeckMetaDialogState();
}

class _DeckMetaDialogState extends State<_DeckMetaDialog> {
  late final TextEditingController _name;
  late final TextEditingController _memo;
  final _tagInput = TextEditingController();

  late List<String> _tags;
  late String? _cover;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.name);
    _memo = TextEditingController(text: widget.draft.memo);
    _tags = [...widget.draft.tags];
    _cover = widget.draft.coverPrintingId;
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    // ★同じタグを 2 つ入れない（`deck_tags` の主キーが {deckId, tag}）。
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags = [..._tags, tag];
      _tagInput.clear();
    });
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      widget.draft.copyWith(
        name: _name.text.trim(),
        memo: _memo.text,
        tags: _tags,
        coverPrintingId: _cover,
        // ★外すのも編集のうち。渡さないと片道になる（決定 D70）。
        clearCover: _cover == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ★カバーに選べるのは**このデッキに入っているカード**だけ。
    //   一覧から選ばせると、デッキに無いカードが表紙になりうる。
    final candidates = widget.draft.entries
        .map((e) => e.printingId)
        .where((id) => widget.catalog.rowOf(id) != null)
        .toList();

    return AlertDialog(
      title: const Text('デッキの情報'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('metaNameField'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'デッキ名'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('metaMemoField'),
                controller: _memo,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text('タグ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (_tags.isEmpty)
                Text(
                  'まだありません',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in _tags)
                      InputChip(
                        key: ValueKey('metaTag:$tag'),
                        label: Text(tag),
                        // ★アイコンを明示する。既定は Material の版で変わりうるので、
                        //   テストが図らずも版に縛られる。
                        deleteIcon: const Icon(Icons.close, size: 16),
                        deleteButtonTooltipMessage: 'タグを外す',
                        onDeleted: () =>
                            setState(() => _tags = [..._tags]..remove(tag)),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('metaTagField'),
                      controller: _tagInput,
                      decoration: const InputDecoration(
                        labelText: 'タグを足す',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _addTag, child: const Text('足す')),
                ],
              ),
              const SizedBox(height: 16),
              Text('カバー', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              if (candidates.isEmpty)
                Text(
                  // ★「選べない」理由を言う。空欄だけだと壊れて見える。
                  'デッキにカードを入れると、その中から選べます',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                _CoverPicker(
                  candidates: candidates,
                  selected: _cover,
                  catalog: widget.catalog,
                  imageSource: widget.imageSource,
                  onSelect: (id) => setState(() => _cover = id),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, v, _) => FilledButton(
            // ★名前が空のまま保存させない（`decks.name` は NOT NULL だが空は入る）。
            onPressed: v.text.trim().isEmpty ? null : _submit,
            child: const Text('決定'),
          ),
        ),
      ],
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.candidates,
    required this.selected,
    required this.catalog,
    required this.imageSource,
    required this.onSelect,
  });

  final List<String> candidates;
  final String? selected;
  final DeckCatalogView catalog;
  final CardImageSource imageSource;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final id = candidates[i];
                final row = catalog.rowOf(id)!;
                final chosen = id == selected;
                return InkWell(
                  key: ValueKey('metaCover:$id'),
                  onTap: () => onSelect(id),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: chosen ? 3 : 1,
                        color: chosen
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    // ★横スクロールの中では幅が無限に来るので、幅を閉じてやる。
                    //   高さは ListView の交差軸（96）から来る。
                    // ★★ 枠は種別で選ぶ（決定 D72）★★
                    //   ライブは横長（200:143）。縦長の箱で cover すると左右が切れる。
                    //   ★★ 叩ける矩形を作るのは外側であって、この絵ではない（決定 D46）★★
                    //     支えているのは 2 つ。(a) 上の `Container` の `BoxDecoration`
                    //     ——`RenderDecoratedBox.hitTestSelf` が `Decoration.hitTest` に
                    //     委ね、矩形の中ならどこでも true になる。(b) `InkWell` の
                    //     `HitTestBehavior.opaque`。★実測では (a) だけでも帯は叩ける。
                    //     **どちらかを消すときは `test/ui/card_art_test.dart` を見ること。**
                    child: SizedBox(
                      width: 56,
                      child: CardArt(
                        source: imageSource,
                        imageHash: row.imageHash,
                        cardType: row.cardType,
                        logicalWidth: 56,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // ★★ 外す口を必ず置く ★★
          //   カバーに選んだカードをデッキから抜いても宙に浮いたまま残る。
          //   `Deck.copyWith` では書けないので、決定 D70 で save を
          //   明示コンストラクタに変えてある。
          TextButton.icon(
            onPressed: selected == null ? null : () => onSelect(null),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('カバーを外す'),
          ),
        ],
      );
}
