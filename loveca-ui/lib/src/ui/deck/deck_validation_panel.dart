/// P1 検証パネル（`docs/UI設計メモ.md` §2-3 / 決定 D28 / D55）.
///
/// ★★ 常設する。別画面にしない ★★
/// 別画面だと「見に行く」操作が要り、**構築の最中に効かない**（§2-3）。
/// デッキペインの内側に縦に積む（★3 つ目のペインにしきい値を増やさない / §2-1）。
///
/// ★★ 判定は `loveca_core` の `DeckValidator` が唯一の実装である（決定 D28）★★
/// UI 側で 48 / 12 / 12 を再計算しない。別実装を作ると
/// 「スマホでは合法、PC では不正」という事故が起きる。
/// 数値は `DeckRepository.validateDraft`（DB へ行かない / 決定 D55）から来ている。
///
/// ★★ 期待値も `RuleConfig` から取る ★★
/// 総合ルール 6.1.2 に「デッキの構築条件に関する常時能力は…置換効果として適用される」と
/// あり、構築条件を変えるカードが存在しうる。定数を書き込まない。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:loveca_core/loveca_core.dart';

class DeckValidationPanel extends StatelessWidget {
  const DeckValidationPanel({
    super.key,
    required this.validation,
    required this.config,
  });

  final DeckValidationResult validation;
  final RuleConfig config;

  /// 枚数の過不足は下の 3 行が見せているので、メッセージでは繰り返さない。
  static const _countCodes = {
    DeckIssueCode.memberCountMismatch,
    DeckIssueCode.liveCountMismatch,
    DeckIssueCode.energyCountMismatch,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ★未知の刷り（決定 D35）は縮退として別に出しているので、ここでは重ねない。
    final others = validation.issues
        .where((i) =>
            !_countCodes.contains(i.code) &&
            i.code != DeckIssueCode.unknownPrinting)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              Expanded(
                child: Text(
                  validation.isValid ? '構築条件を満たしています' : '構築条件を満たしていません',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 総合ルール 6.1.1.1: メンバー 48 / ライブ 12、6.1.1.3: エネルギー 12。
          _CountLine(
            label: 'メンバー',
            actual: validation.memberCount,
            expected: config.memberCount,
          ),
          _CountLine(
            label: 'ライブ',
            actual: validation.liveCount,
            expected: config.liveCount,
          ),
          _CountLine(
            label: 'エネルギー',
            actual: validation.energyCount,
            expected: config.energyDeckSize,
          ),
          if (validation.issues.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '未達 ${validation.issues.length} 件',
              style: theme.textTheme.bodySmall,
            ),
          ],
          // ★4 枚超過（6.1.1.2）などは枚数の 3 行では読み取れないので出す。
          //   ★パラレル違いも合算される旨は DeckIssue のメッセージが持っている。
          for (final issue in others.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                issue.message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (others.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'ほか ${others.length - 3} 件',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「メンバー 0 / 48」の 1 行。★過不足を色でも分かるようにする。
class _CountLine extends StatelessWidget {
  const _CountLine({
    required this.label,
    required this.actual,
    required this.expected,
  });

  final String label;
  final int actual;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 総合ルール 6.1.1 は「ちょうど」なので、多くても少なくても不足である。
    final ok = actual == expected;
    return Text(
      '$label $actual / $expected',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: ok ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: ok ? FontWeight.w600 : null,
      ),
    );
  }
}
