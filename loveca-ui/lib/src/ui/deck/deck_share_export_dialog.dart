/// 共有形式の書き出し（`docs/UI設計メモ.md` §2-5 / 決定 D67 / D35）.
///
/// ★★ 落としたものを必ず見せる ★★
/// `Deck.toShareFormat` は `if (printing == null) continue;`
/// （`loveca-core/lib/src/entities/deck.dart:145`）で
/// **マスタに無い刷りを無言で落とす。** cardNumber が引けないので
/// 落とすこと自体は正しいが、**落としたことを言わないのは A-3 と同じ型**。
///
/// ★★ 刷りの違いが残らないことも必ず見せる ★★
/// 共有形式は cardNumber ごとに合算するので、`-SD` 3 枚 + `-SD2` 1 枚は
/// `x4` の 1 行になる。往復すると刷りが変わる。
/// 刷りを保ったまま写したいなら**複製**（決定 D71）を使う。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/deck_share.dart';

Future<void> showDeckShareExportDialog(
  BuildContext context, {
  required Deck deck,
  required Map<String, Printing> printings,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ExportDialog(
        export: encodeDeckShare(deck, printings, title: deck.name),
        deckName: deck.name,
      ),
    );

class _ExportDialog extends StatelessWidget {
  const _ExportDialog({required this.export, required this.deckName});

  final DeckShareExport export;
  final String deckName;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;

    return AlertDialog(
      title: const Text('共有形式をコピー'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ★★ 往復で刷りが変わることを先に言う ★★
              //   あとから気づくと「取り込んだら別の絵になった」になる。
              Text(
                'カード番号と枚数だけの形式です。'
                '同じカード番号の刷り違いは合算されるため、'
                '取り込み直すと刷りが変わることがあります。'
                '刷りごと写したいときは「複製」を使ってください。',
                style: small,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  export.text.trimRight(),
                  key: const Key('shareExportText'),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              if (export.droppedUnknownPrintingIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Warning(
                  // ★★ 決定 D35: 黙って落とさない ★★
                  text: '${export.droppedUnknownPrintingIds.length} 種類 '
                      '（${export.droppedCopies} 枚）は共有形式に出せませんでした。'
                      'カードデータに無い刷りで、カード番号が分からないためです。'
                      'カードデータを更新すると出せるようになることがあります。',
                  detail: [
                    for (final (printingId, count)
                        in export.droppedUnknownPrintingIds)
                      '$printingId x$count',
                  ].join('\n'),
                ),
              ],
              if (export.unencodableCardNumbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Warning(
                  text: '${export.unencodableCardNumbers.length} 件のカード番号は'
                      'この形式で書けませんでした。',
                  detail: export.unencodableCardNumbers.join('\n'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: export.text));
            if (!context.mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('共有形式をコピーしました')),
            );
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('コピー'),
        ),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text, required this.detail});

  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_outlined, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(text)),
          ],
        ),
        // ★内部語彙（printingId）は畳んでおく。ただし**捨てない**。
        ExpansionTile(
          title: Text('詳しい内容', style: small),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [SelectableText(detail, style: small)],
        ),
      ],
    );
  }
}
