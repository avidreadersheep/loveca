/// デッキペイン（R3 の secondary / `docs/UI設計メモ.md` §2-1 / §2-3 / M4）.
///
/// ★★ 1 ペインのときは同じ Widget をモーダルで出す ★★
/// 器だけ替えて置き、ルートを増やして分岐させない（§2-1）。
/// ★1 ペインではドラッグで一覧から持ってこられない（モーダルが一覧を覆う）ので、
/// **セルの「+」が唯一の追加手段になる。**だから「+」は必ず置く。
///
/// ★★ 縦に積む順（測る前に決めてある / 未決 U8 の検算手順）★★
///
/// | 位置 | 中身 | 折りたたまない理由 |
/// |---|---|---|
/// | 1 | 名前 + 保存 | 保存が届かない場所にあると、編集の区切りが見えない |
/// | 2 | メモ | 同上（M2 から置いてある） |
/// | 3 | 中身の一覧（区分ごと） | ここが本体 |
/// | 4 | ゴミ箱バー | ★常設。出したり隠したりすると「落とせる場所」が分からない |
/// | 5 | 縮退（決定 D65 / D35） | 起きたときだけ |
/// | 6 | P1 検証パネル | ★**常設**（§2-3）。別画面だと構築の最中に効かない |
///
/// ★★ この 6 つを削らないまま最小幅を測る ★★
/// U8 の論点は「デッキペインの最小幅 320 が見積りである」ことなので、
/// **320 に収まるよう表示を削ってから測ると検算にならない。**
/// 実測は `test/ui/deck_pane_width_test.dart`（構造の下限）と実機（正）。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_image_source.dart';
import '../../state/deck_edit_degradation.dart';
import '../../state/deck_edit_store.dart';
import '../common/card_drag.dart';
import '../common/card_thumb.dart';
import '../common/degradation_line.dart';
import 'deck_drag.dart';
import 'deck_validation_panel.dart';

/// デッキペインの幅（★M4 で実測した / 未決 **U8**）。
///
/// ★★ 暫定の 320 は見積りだった（決定 D61 の根拠 (b)）★★
/// 手順と数値は `docs/UI設計メモ.md` §9-6 と `test/ui/deck_pane_width_test.dart`。
///
/// ★★ 実測の格が 2 段ある。混ぜないこと ★★
///
/// **(1) ウィジェットテスト**（`test/ui/deck_pane_width_test.dart`）
/// - 溢れない下限: **151 論理px**。★`flutter test` は**テスト用フォント**で組むので
///   日本語の実幅ではない。これは「構造の下限」であって**読める幅ではない**
///   （名前も刷り番号も ellipsis で潰れるだけで、溢れはしない）。
/// - 採用値 320 のとき行の名前に残る幅: **177 論理px**。
///   ★固定幅（サムネ 34 / 枚数コントロール / 余白）の引き算なので**フォントに依らない**。
///
/// **(2) 実機**（Windows / debug / 実データ）★**こちらが正**
/// - **240**: 刷り番号の行が切れる（`PL!-bp1-000-LLE・…`）→ 狭すぎる
/// - **288**: 同じ行が最後まで読める → **自然な最小幅は 288 付近**
/// - **320（採用）**: 余裕を持たせた値
///
/// ★debug / profile でこの寸法は変わらない。レイアウトは同じ RenderObject・
/// 同じ制約・同じフォントで計算され、`kDebugMode` は寸法に影響しない。
/// 設計メモ §9-3 の注記（**時間**は debug と profile で違う）とは**別の話**である。
///
/// ★しきい値の算数: 一覧 3 列 444 + 仕切り 1 + 320 = **765 ≤ 840** → **840 は動かさない**。
const double kDeckPaneMinWidth = 320;

/// デッキ行の高さ（★測る前に決めた値。あとから削らない）。
const double kDeckRowHeight = 56;

/// 行のサムネの論理幅（比 200:279 なので高さは約 47）。
const double kDeckRowThumbWidth = 34;

class DeckPane extends StatelessWidget {
  const DeckPane({
    super.key,
    required this.store,
    required this.imageSource,
    required this.config,
    required this.nameController,
    required this.memoController,
    required this.onSave,
  });

  final DeckEditStore store;
  final CardImageSource imageSource;

  /// 総合ルール 6.1.2 により置換されうるので定数にしない。
  final RuleConfig config;

  final TextEditingController nameController;
  final TextEditingController memoController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DeckEditState>(
        valueListenable: store,
        builder: (context, state, _) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                state: state,
                nameController: nameController,
                memoController: memoController,
                onSave: onSave,
                store: store,
              ),
              const Divider(height: 1),
              Expanded(
                child: _EntryList(
                  store: store,
                  state: state,
                  imageSource: imageSource,
                ),
              ),
              _TrashBar(store: store),
              const Divider(height: 1),
              for (final degradation in state.degradations)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _DeckDegradationLine(degradation: degradation),
                ),
              // ★★ 常設（§2-3）★★
              ColoredBox(
                color: theme.colorScheme.surfaceContainerLow,
                child: DeckValidationPanel(
                  validation: state.validation,
                  config: config,
                ),
              ),
            ],
          );
        },
      );
}

/// 名前 + 保存 + メモ。
class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.nameController,
    required this.memoController,
    required this.onSave,
    required this.store,
  });

  final DeckEditState state;
  final TextEditingController nameController;
  final TextEditingController memoController;
  final VoidCallback onSave;
  final DeckEditStore store;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    // ★テストから安定して掴むための Key。文字を入れると
                    //   ラベルや中身で探す方法は次の 1 打で外れる。
                    key: const Key('deckNameField'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'デッキ名',
                    ),
                    // ★★ ここで保存しない ★★
                    // ドラフトを差し替えるだけ。保存するたびに revision が +1 されるので、
                    // キー入力ごとに保存すると Phase 4 の同期で
                    // 「大量に更新された」ように見える（§9-1）。
                    onChanged: store.setName,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: state.canSave ? onSave : null,
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('deckMemoField'),
              controller: memoController,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'メモ',
              ),
              minLines: 1,
              maxLines: 2,
              onChanged: store.setMemo,
            ),
            if (state.isDirty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '未保存の変更があります',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      );
}

/// 区分ごとの中身。
///
/// ★★ 区分は `card_type` から導出する（決定 D41）★★
/// 行に区分を保存しない。`DeckValidator` の判定と食い違う経路を作らないため。
class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.store,
    required this.state,
    required this.imageSource,
  });

  final DeckEditStore store;
  final DeckEditState state;
  final CardImageSource imageSource;

  @override
  Widget build(BuildContext context) {
    final sections = state.sections;
    final children = <Widget>[
      ..._section(context, 'メンバー', sections.members),
      ..._section(context, 'ライブ', sections.lives),
      ..._section(context, 'エネルギー', sections.energies),
      // ★決定 D35: マスタに無い刷りを黙って落とさない。読み取り専用で残す。
      ..._section(context, '表示できないカード', sections.unknown, readOnly: true),
    ];

    // ★★ 一覧の余白へ落とすと末尾に足す ★★
    //   行の上に落とす場合との違いは「位置を指定するかどうか」だけ。
    return CardDropTarget<DeckDrag>(
      background: Theme.of(context).colorScheme.surface,
      accepts: (data) => data is CatalogCardDrag,
      onDrop: (data, _) => addCardWithFeedback(context, store, data.printingId),
      builder: (context, hovering) => children.isEmpty
          ? _EmptyDeck(hovering: hovering != null)
          : ListView(padding: EdgeInsets.zero, children: children),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String label,
    List<DeckEntry> entries, {
    bool readOnly = false,
  }) {
    if (entries.isEmpty) return const [];
    final count = entries.fold(0, (sum, e) => sum + e.count);
    return [
      _SectionHeader(label: label, count: count),
      for (final entry in entries)
        _EntryRow(
          // ★テストから安定して掴むための Key。一覧のセルと区別できる名前にする。
          key: ValueKey('deckRow:${entry.printingId}'),
          store: store,
          entry: entry,
          imageSource: imageSource,
          readOnly: readOnly,
        ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text('$label  $count 枚', style: theme.textTheme.labelSmall),
      ),
    );
  }
}

/// デッキ 1 行。
///
/// ★★ 掴む部分も落とす部分も、必ず色を持つ（決定 D46）★★
/// ラッパ（`CardDragSource` / `CardDropTarget`）が `background` を必須にしているので、
/// 「色を付け忘れて行の余白から掴めない」形が書けない。
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.store,
    required this.entry,
    required this.imageSource,
    required this.readOnly,
  });

  final DeckEditStore store;
  final DeckEntry entry;
  final CardImageSource imageSource;

  /// マスタに無い刷り（決定 D35）。★掴めないし増減もできない。**消えもしない。**
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = store.rowOf(entry.printingId);
    final background = theme.colorScheme.surface;

    final content = SizedBox(
      height: kDeckRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: kDeckRowThumbWidth,
              height: kDeckRowHeight - 8,
              child: row == null
                  // ★絵が出せないことを黙って空白にしない。
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: theme.disabledColor,
                      ),
                    )
                  : CardThumb(
                      source: imageSource,
                      imageHash: row.imageHash,
                      logicalWidth: kDeckRowThumbWidth,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row?.name ?? 'カードデータが未取得',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    row == null
                        ? entry.printingId
                        : '${entry.printingId} · ${row.rarity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            if (!readOnly)
              _CountControls(store: store, entry: entry)
            else
              Text('×${entry.count}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );

    if (readOnly) {
      // ★掴めないし落とせない。**が、消えていない**ことが分かるように出す。
      return ColoredBox(color: background, child: content);
    }

    return CardDropTarget<DeckDrag>(
      background: background,
      onDrop: (data, edge) {
        switch (data) {
          // ★一覧から: この位置へ足す。
          case CatalogCardDrag():
            addCardWithFeedback(
              context,
              store,
              data.printingId,
              before: entry.printingId,
              edge: edge,
            );
          // ★デッキから: 並べ替える（★保存されない / 決定 D65）。
          case DeckEntryDrag():
            store.moveEntry(data.printingId, entry.printingId, edge);
        }
      },
      builder: (context, hovering) => DecoratedBox(
        // ★★ どちらの意味で落ちるかを出す（決定 D47）★★
        //   出さないと利用者は前に入るのか後ろに入るのか分からない。
        decoration: BoxDecoration(
          border: Border(
            top: hovering == DropEdge.leading
                ? BorderSide(color: theme.colorScheme.primary, width: 3)
                : BorderSide.none,
            bottom: hovering == DropEdge.trailing
                ? BorderSide(color: theme.colorScheme.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: CardDragSource<DeckDrag>(
          data: DeckEntryDrag(entry.printingId),
          background: background,
          feedback: SizedBox(
            width: 40,
            height: 56,
            child: row == null
                ? ColoredBox(color: theme.colorScheme.surfaceContainerHighest)
                : CardThumb(
                    source: imageSource,
                    imageHash: row.imageHash,
                    logicalWidth: 40,
                  ),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 「− 枚数 +」。★`+` の活性は `DeckValidator.canAdd`（決定 D28 / D55）。
class _CountControls extends StatelessWidget {
  const _CountControls({required this.store, required this.entry});

  final DeckEditStore store;
  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TightIconButton(
          tooltip: '1 枚減らす',
          icon: Icons.remove,
          onPressed: () => store.removeCopy(entry.printingId),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '${entry.count}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        _TightIconButton(
          tooltip: '1 枚増やす',
          icon: Icons.add,
          // ★総合ルール 6.1.1.2 / 6.1.1.3 の判定は DeckValidator が唯一の実装。
          //   UI 側で 4 や 12 を書かない。
          onPressed: store.canAdd(entry.printingId)
              ? () => store.addCard(entry.printingId)
              : null,
        ),
      ],
    );
  }
}

class _TightIconButton extends StatelessWidget {
  const _TightIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        iconSize: 18,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        onPressed: onPressed,
      );
}

/// ゴミ箱。★常設のバー（決定 D46: 落とす先も描画物にする）。
class _TrashBar extends StatelessWidget {
  const _TrashBar({required this.store});

  final DeckEditStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Builder(
        builder: (context) {
          return CardDropTarget<DeckDrag>(
            background: theme.colorScheme.surfaceContainerLow,
            // ★一覧から来たカードはそもそもデッキに無い。受け取らない。
            accepts: (data) => data is DeckEntryDrag,
            onDrop: (data, _) => store.removeEntry(data.printingId),
            builder: (context, hovering) => Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: hovering == null
                        ? theme.hintColor
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hovering == null ? 'ここへ落とすとデッキから外す' : 'デッキから外す',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hovering == null
                          ? theme.hintColor
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.hovering});

  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          hovering ? 'ここへ落とすと入る' : 'カードがまだありません\n一覧から引っぱるか「+」で入れます',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ),
    );
  }
}

/// 縮退 1 行（★描画は `ui/common/degradation_line.dart` と共有 / 型は分けてある）。
class _DeckDegradationLine extends StatelessWidget {
  const _DeckDegradationLine({required this.degradation});

  final DeckEditDegradation degradation;

  @override
  Widget build(BuildContext context) {
    // ★★ `switch` は網羅的でなければならない（`DeckEditDegradation` は sealed）★★
    // 3 つ目を足したとき、ここを直し忘れると**コンパイルエラーになる。**
    final (IconData icon, DegradationSeverity severity, String text) =
        switch (degradation) {
      DeckOrderNotPersisted() => (
          Icons.swap_vert,
          DegradationSeverity.report,
          // ★「保存されません」で止めない。**戻る先**まで言う。
          '並び順はこの画面の中だけです。開き直すとカード番号順に戻ります。',
        ),
      DeckUnknownPrintings(:final count) => (
          Icons.report_problem_outlined,
          DegradationSeverity.warning,
          'カードデータが未取得の刷りが $count 件あります。'
              '消してはいないので、データを更新すると出てきます。',
        ),
    };

    return DegradationLine(icon: icon, severity: severity, text: text);
  }
}

/// 足せなかった理由を必ず出す（★黙って何も起きない状態にしない）。
///
/// ドラッグで落としたときは「+」と違ってボタンの活性で止められない。
/// 落ちたのに何も起きないと、利用者は**アプリが壊れている**と読む。
void addCardWithFeedback(
  BuildContext context,
  DeckEditStore store,
  String printingId, {
  String? before,
  DropEdge edge = DropEdge.leading,
}) {
  final refusal = store.addCard(printingId, before: before, edge: edge);
  if (refusal == null) return;

  final message = switch (refusal) {
    // 総合ルール 6.1.1.2。★パラレル違いも合算される（CLAUDE.md §5-(4)）。
    AddCardRefusal.tooManyCopies =>
      '同じカードナンバーは 4 枚までです（別の絵柄も合算されます）。',
    // 総合ルール 6.1.1.3。
    AddCardRefusal.energyDeckFull => 'エネルギーデッキは 12 枚までです。',
    AddCardRefusal.unknownPrinting => 'このカードのデータが取得できていません。',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
