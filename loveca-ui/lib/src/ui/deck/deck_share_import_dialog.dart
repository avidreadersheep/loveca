/// 共有形式の取り込み（`docs/UI設計メモ.md` §2-5 / 決定 D67 / D68 / D69）.
///
/// ★★ 黙って捨てない ★★
/// 取り込めなかったものを 3 種類に分けて出す。**どれも原因と対処が違う。**
///
/// | 種類 | 何が起きたか | 利用者の対処 |
/// |---|---|---|
/// | 読めなかった行 | 書式に合わない | 書き直す |
/// | 見つからないカード番号 | マスタに無い | カードデータを更新する |
/// | 4 枚を超える | 6.1.1.2 違反 | 取り込んだうえで減らす |
///
/// ★★ 取り込み先はドラフトである ★★
/// 保存しなければ元に戻せる。だから「置き換えます」と言い切れる。
///
/// ★★ 入口は R3 の 1 本だけ（§2-2）★★
/// R2 からは「新規デッキ → 開く → 取り込む」で届く。
/// ルートを増やして分岐させない。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_detail.dart';
import '../../data/deck_share.dart';

/// 取り込む中身を決めて返す。中止したら null。
Future<List<DeckEntry>?> showDeckShareImportDialog(
  BuildContext context, {
  required CardDetailView catalog,
  required int maxCopies,
}) =>
    showDialog<List<DeckEntry>>(
      context: context,
      builder: (_) => _ImportDialog(catalog: catalog, maxCopies: maxCopies),
    );

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.catalog, required this.maxCopies});

  final CardDetailView catalog;
  final int maxCopies;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _input = TextEditingController();

  /// ★解釈した結果。貼り付けただけでは取り込まない——**先に見せる。**
  DeckShareImportResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _analyze() {
    setState(() {
      _result = resolveDeckShare(
        parseDeckShare(_input.text),
        widget.catalog,
        maxCopies: widget.maxCopies,
      );
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _input.text = text;
    _analyze();
  }

  void _swap(int index, String printingId) {
    final result = _result!;
    final next = [...result.resolved];
    next[index] = next[index].withPrinting(printingId);
    setState(() {
      _result = DeckShareImportResult(
        resolved: next,
        unknown: result.unknown,
        unparsedLines: result.unparsedLines,
        overLimit: result.overLimit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final small = Theme.of(context).textTheme.bodySmall;

    return AlertDialog(
      title: const Text('共有形式から取り込む'),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // ★★ 何が起きるかを先に言う ★★
              'いまのデッキの中身を、貼り付けた内容で置き換えます。'
              '保存しなければ元に戻せます。',
              style: small,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('shareImportField'),
              controller: _input,
              minLines: 3,
              maxLines: 4,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'LL-bp1-001 x4',
              ),
              onChanged: (_) => _analyze(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.paste, size: 16),
                  label: const Text('貼り付け'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result != null)
              Expanded(child: _Preview(result: result, onSwap: _swap)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('中止する'),
        ),
        FilledButton(
          // ★1 枚も取り込めないなら押させない。
          onPressed: result == null || result.isEmpty
              ? null
              : () => Navigator.of(context).pop(result.toEntries()),
          child: Text(
            result != null && result.needsConfirmation
                // ★★ 断りが要るときは文言を変える ★★
                //   同じ「取り込む」だと、警告を読まずに押したのか
                //   読んで押したのかが分からない。
                ? 'このまま取り込む'
                : '取り込む',
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.result, required this.onSwap});

  final DeckShareImportResult result;
  final void Function(int index, String printingId) onSwap;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    return ListView(
      children: [
        Text(
          '${result.resolved.length} 種類 '
          '/ ${result.resolved.fold(0, (s, r) => s + r.count)} 枚を取り込みます',
        ),
        // ★★ 取り込めなかったものを 3 種類に分けて出す ★★
        if (result.unknown.isNotEmpty)
          _Issue(
            key: const Key('shareImportUnknown'),
            icon: Icons.help_outline,
            text: '${result.unknown.length} 件のカード番号が見つかりません。'
                'その分は取り込まれません。'
                'カードデータを更新すると見つかることがあります。',
            detail: [
              for (final (cardNumber, count) in result.unknown)
                '$cardNumber x$count',
            ].join('\n'),
          ),
        if (result.unparsedLines.isNotEmpty)
          _Issue(
            key: const Key('shareImportUnparsed'),
            icon: Icons.report_gmailerrorred_outlined,
            text: '${result.unparsedLines.length} 行を読めませんでした。'
                '「カード番号 x枚数」の形で 1 行ずつ書いてください。',
            detail: result.unparsedLines.join('\n'),
          ),
        if (result.overLimit.isNotEmpty)
          _Issue(
            key: const Key('shareImportOverLimit'),
            icon: Icons.filter_4_outlined,
            // ★弾かないし丸めない（決定 D69）。取り込んだうえで検証に出す。
            text: '${result.overLimit.length} 件が 4 枚を超えています'
                '（総合ルール 6.1.1.2）。'
                'そのまま取り込みますが、検証に違反として出ます。',
            detail: [
              for (final (cardNumber, count) in result.overLimit)
                '$cardNumber $count 枚',
            ].join('\n'),
          ),
        if (result.ambiguous.isNotEmpty)
          _Issue(
            key: const Key('shareImportAmbiguous'),
            icon: Icons.style_outlined,
            // ★★ 既定を選ぶしかなかったものだけ言う（決定 D68）★★
            //   「刷りが複数」は 600 件あるので、そこまで言うと意味が薄れる。
            text: '${result.ambiguous.length} 件は通常の刷りが複数あります。'
                '下の一覧で選び直せます。',
            detail: [for (final r in result.ambiguous) r.cardNumber].join('\n'),
          ),
        const SizedBox(height: 8),
        if (result.resolved.isNotEmpty)
          Text('刷りを選ぶ', style: Theme.of(context).textTheme.labelLarge),
        for (final (i, card) in result.resolved.indexed)
          _CardRow(
            card: card,
            small: small,
            onSwap: (printingId) => onSwap(i, printingId),
          ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.small,
    required this.onSwap,
  });

  final ResolvedShareCard card;
  final TextStyle? small;
  final void Function(String) onSwap;

  @override
  Widget build(BuildContext context) => Padding(
        key: ValueKey('shareImportRow:${card.cardNumber}'),
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text('${card.cardNumber} x${card.count}', style: small),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: card.candidates.length < 2
                  // ★選びようが無いものにプルダウンを出さない。
                  //   出すと「選べるのに選ばなかった」ように見える。
                  ? Text(card.printingId, style: small)
                  : DropdownButton<String>(
                      key: ValueKey('shareImportPick:${card.cardNumber}'),
                      value: card.printingId,
                      isDense: true,
                      isExpanded: true,
                      onChanged: (v) => v == null ? null : onSwap(v),
                      items: [
                        for (final printing in card.candidates)
                          DropdownMenuItem(
                            value: printing.printingId,
                            child: Text(
                              '${printing.printingId}'
                              '${printing.isParallel ? '（パラレル）' : ''}',
                              style: small,
                            ),
                          ),
                      ],
                    ),
            ),
            if (card.hasMultipleNormalPrintings)
              Tooltip(
                message: '通常の刷りが複数あります',
                child: Icon(Icons.style_outlined, size: 16, color: small?.color),
              ),
          ],
        ),
      );
}

class _Issue extends StatelessWidget {
  const _Issue({
    super.key,
    required this.icon,
    required this.text,
    required this.detail,
  });

  final IconData icon;
  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: small)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: SelectableText(detail, style: small),
          ),
        ],
      ),
    );
  }
}
