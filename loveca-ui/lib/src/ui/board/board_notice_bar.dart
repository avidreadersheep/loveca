/// 盤面の帯の描画（盤面設計メモ §10-3 / M-B3）.
///
/// ★★ 共有するのは「描画」だけで、「型」は共有しない ★★
/// `BoardNotice` は 4 つ目の系統として独立させてある（決定 D53）。
/// ここは `ui/common/degradation_line.dart` を使って 1 件 = 1 行に描くだけ。
///
/// ★★ 網羅 switch を 1 箇所に集める ★★
/// 枝を足したときに**コンパイルエラーになる場所を 1 つに保つ**。
/// 複数の画面がそれぞれ switch を持つと、片方だけ直されて無言で落ちる。
///
/// ★内部語彙（instanceId / printingId / 孤児 / reduce）を出さない。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/board_notice.dart';
import '../common/degradation_line.dart';

/// 注記の並び。★色は呼び出し側が決める（常設の帯と直前の結果で地の色が違う）。
class BoardNoticeBar extends StatelessWidget {
  const BoardNoticeBar({
    super.key,
    required this.notices,
    required this.background,
    this.heading,
  });

  final List<BoardNotice> notices;
  final Color background;

  /// 「直前の整理（9.5.3）」のような見出し。null なら出さない。
  final String? heading;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading case final text?)
            Text(text, style: theme.textTheme.labelSmall),
          for (final notice in notices) boardNoticeLine(notice),
        ],
      ),
    );
  }
}

/// 注記 1 件を 1 行に描く。★ここが唯一の網羅 switch。
Widget boardNoticeLine(BoardNotice notice) => switch (notice) {
      MulliganNotImplemented() => const DegradationLine(
          icon: Icons.construction_outlined,
          severity: DegradationSeverity.report,
          // ★暫定であることを盤面から読めるようにする。M-B5 で消す。
          text: '6.2.1.6 のマリガンはまだありません。'
              'この盤面は 0 枚として開始しています。',
        ),
      DeckNotValid(:final playerLabel, :final issues) => DegradationLine(
          icon: Icons.rule_outlined,
          severity: DegradationSeverity.warning,
          text: '$playerLabelのデッキは 6.1 の構築条件を満たしていません: '
              '${issues.map((i) => i.message).join(' / ')}',
        ),
      RuleProcessApplied(:final stepRuleRef, :final kinds) => DegradationLine(
          icon: Icons.cleaning_services_outlined,
          severity: DegradationSeverity.report,
          text: '$stepRuleRef のチェックタイミングで整理しました: '
              '${_countedRuleProcess(kinds)}',
        ),
      RuleProcessNotAutomatic(:final stepRuleRef, :final kinds) =>
        DegradationLine(
          icon: Icons.pan_tool_outlined,
          severity: DegradationSeverity.warning,
          text: '$stepRuleRef の時点で次に当たるものがありますが、'
              'アプリは実行しません（手で処理してください）: '
              '${kinds.map(_warningLabel).join(' / ')}',
        ),
      TidyExcluded(:final stepRuleRef, :final count, :final cardNumbers) =>
        DegradationLine(
          icon: Icons.help_outline,
          severity: DegradationSeverity.warning,
          text: '$stepRuleRef の整理で $count 枚を動かせませんでした。'
              'カードデータが未取得です（${cardNumbers.join(' / ')}）。'
              '設定から取り込み直すと解消します。',
        ),
    };

/// ★同じ種別が複数枚に当たるので件数を添える。★並びは enum の宣言順（決定的にする）。
String _countedRuleProcess(List<RuleProcessKind> kinds) {
  final counts = <RuleProcessKind, int>{};
  for (final kind in kinds) {
    counts[kind] = (counts[kind] ?? 0) + 1;
  }
  return [
    for (final kind in RuleProcessKind.values)
      if (counts[kind] case final n?) '${_appliedLabel(kind)} $n 件',
  ].join(' / ');
}

/// ★内部語彙（enum の名前）を出さない。条番号 + 日本語。
String _appliedLabel(RuleProcessKind kind) => switch (kind) {
      RuleProcessKind.duplicateMember => '同じエリアの重複メンバー ${kind.ruleRef}',
      RuleProcessKind.invalidLiveStage =>
        'ライブカード置き場のライブでないカード ${kind.ruleRef}',
      RuleProcessKind.invalidEnergyField =>
        'エネルギー置き場のエネルギーでないカード ${kind.ruleRef}',
      RuleProcessKind.orphanMember =>
        '上にメンバーが居ないメンバーカード ${kind.ruleRef}',
      RuleProcessKind.orphanEnergy =>
        '上にメンバーが居ないエネルギーカード ${kind.ruleRef}',
    };

String _warningLabel(RuleProcessWarningKind kind) => switch (kind) {
      // ★決定 D10: 勝敗確定は手動。1.2.1.2 により両者同時なら引き分け。
      RuleProcessWarningKind.victory =>
        '勝利処理 ${kind.ruleRef}（成功ライブカード置き場の枚数が勝利条件に達しています）',
      // ★D-A: 「プレイ中 / 解決中」は効果の解決状態なので観測できない。
      RuleProcessWarningKind.invalidResolution =>
        '不正解決領域処理 ${kind.ruleRef}（解決領域にカードがあります）',
    };
