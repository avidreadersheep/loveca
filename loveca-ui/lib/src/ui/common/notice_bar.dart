/// 起動時の「エラーではないが伝えるべきこと」（`docs/UI設計メモ.md` §3-4(3) / §11）.
///
/// ★★ ランディング画面に出さないと誰も読まない ★★
/// M1 ではこれが R4（カード閲覧）の中に private で書かれていた。
/// R4 が暫定のホームだったので結果的に出ていただけで、
/// **ホームが R2 に移った時点で「R4 へ移動しないと警告が見えない」状態になる。**
/// 決定 D39 / D60 が繰り返し言っている「記録するだけで誰も見ない状態にしない」に
/// 触れるので、共通部品として出してホームに置く。
///
/// ★★ M-B4 で置き場を `BootGate` 1 箇所へ一本化した（決定 D89）★★
/// R2 に置いても**同じ形の失敗が残っていた** —— dist が解決できていないときの
/// 症状（カード画像が 1 枚も出ない）は R3 / R4 / R7 で現れるのに、
/// 原因はそこから読めない。★組み立ては [BootNoticeHost] が持つ。
///
/// ★★ 「詳細」から次にすべきことへ行けるようにする（D89 の層 3）★★
/// `dist` は内部語彙で利用者には通じない。**探した場所を出したうえで、
/// 設定画面（R6）へ飛べるボタンを置く。**
/// ★帯は `Navigator` の**上**にあるので `Navigator.of(context)` が届かない。
/// [navigator] の鍵を通す（`Navigator.of` は「context 自身が Navigator の要素」を扱える）。
library;

import 'package:flutter/material.dart';

import '../../boot/boot_steps.dart';
import '../settings/settings_page.dart';

class NoticeBar extends StatelessWidget {
  const NoticeBar({super.key, required this.notices, required this.navigator});

  final List<BootNotice> notices;

  /// ★アプリの `Navigator`。★帯より下にあるので鍵で辿る（決定 D89）。
  final GlobalKey<NavigatorState> navigator;

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
                key: const ValueKey('boot-notice-bar'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            // ★★ 「詳細」は常に出す（決定 D89）★★
            //   以前は details を持つ notice があるときだけ出していたが、
            //   **R6 への導線がここにしか無い**ので、details が無くても要る。
            TextButton(
              key: const ValueKey('boot-notice-details'),
              onPressed: () => _showDetails(),
              child: const Text('詳細'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails() {
    // ★`Navigator.of` は「context 自身が Navigator の要素」の場合を扱える。
    final context = navigator.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _NoticeDialog(notices: notices, navigator: navigator),
    );
  }
}

class _NoticeDialog extends StatelessWidget {
  const _NoticeDialog({required this.notices, required this.navigator});

  final List<BootNotice> notices;
  final GlobalKey<NavigatorState> navigator;

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
          // ★★ 次にすべきことへ行けるようにする（決定 D89）★★
          //   3 段解決の結果も、場所を指定する口も R6 にある。
          TextButton(
            key: const ValueKey('open-settings-from-notice'),
            onPressed: () {
              final nav = navigator.currentState;
              if (nav == null) return;
              nav.pop();
              nav.push<void>(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            child: const Text('設定・診断を開く'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      );
}
