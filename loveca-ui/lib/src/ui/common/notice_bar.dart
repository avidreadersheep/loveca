/// 起動時の「エラーではないが伝えるべきこと」（`docs/UI設計メモ.md` §3-4(3)）.
///
/// ★★ ランディング画面に出さないと誰も読まない ★★
/// M1 ではこれが R4（カード閲覧）の中に private で書かれていた。
/// R4 が暫定のホームだったので結果的に出ていただけで、
/// **ホームが R2 に移った時点で「R4 へ移動しないと警告が見えない」状態になる。**
/// 決定 D39 / D60 が繰り返し言っている「記録するだけで誰も見ない状態にしない」に
/// 触れるので、共通部品として出してホームに置く。
library;

import 'package:flutter/material.dart';

import '../../boot/boot_steps.dart';

class NoticeBar extends StatelessWidget {
  const NoticeBar({super.key, required this.notices});

  final List<BootNotice> notices;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();

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
                // ★探した場所や失敗したファイルを省かない（決定 D60）。
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
