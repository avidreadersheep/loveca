/// P2 取り込み失敗の詳細（決定 D39 / `docs/UI設計メモ.md` §2-3 / §2-6）.
///
/// ★★ 記録するだけで誰も見ない状態にしない ★★
/// D39 は「商品ファイル単位で隔離し `import_issues` に記録する」と定め、
/// D-1 が「読み飛ばした事実を UI に出すまでを含めること。
/// 黙って捨てるのは A-3 と同じ失敗になる」と釘を刺している。ここがその出口。
///
/// ★★ 0 件のときも「無い」と言う ★★
/// 何も描かないと、**出す仕組みが壊れている**のと区別がつかない。
library;

import 'package:flutter/material.dart';

import '../../data/import_issue.dart';

class ImportIssuesSection extends StatelessWidget {
  const ImportIssuesSection({super.key, required this.issues});

  final List<ImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16),
          const SizedBox(width: 6),
          const Expanded(child: Text('取り込めなかったファイルはありません')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${issues.length} 件のファイルを取り込めませんでした。'
          'そのファイルに入っているカードは、前回取り込んだ内容のままです。',
        ),
        const SizedBox(height: 8),
        for (final issue in issues) _IssueTile(issue: issue),
      ],
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final ImportIssue issue;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ★★ 2026-08-27: 「記録だけが残っている」の枝を撤去した ★★
                //   D-13 を根治したので、ここに並ぶのは
                //   **いま読めていないファイルだけ**である（D-13 / 決定 D39）。
                const Icon(Icons.warning_amber_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    issue.path,
                    key: ValueKey('importIssue:${issue.path}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ★内部語彙（fromKey / ArgumentError / trigram）を出さない。
            Text(issue.kindLabel),
            const SizedBox(height: 4),
            Text(
              '${issue.occurrenceCount} 回 ・ '
              '最後に起きたのは ${_formatDate(issue.lastSeenAt)}',
              style: small,
            ),
            const SizedBox(height: 6),
            // ★例外の toString() は内部語彙そのものなので、畳んでおく。
            //   ただし**捨てない**。原因を追える唯一の手がかりである。
            ExpansionTile(
              title: Text('詳しい内容', style: small),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(issue.message, style: small),
                const SizedBox(height: 4),
                SelectableText('版: ${issue.hash}', style: small),
                if (issue.currentHash case final current?)
                  SelectableText('いま取り込まれている版: $current', style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ★UTC のまま出さない。表示のときだけローカルに直す。
String _formatDate(DateTime at) {
  final t = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
