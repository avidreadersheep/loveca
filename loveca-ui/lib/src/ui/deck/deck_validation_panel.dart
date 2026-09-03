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

import '../../data/energy_fill.dart';

/// ★★ 画面に出す issue（`docs/Android UI 決定.md` §1-1）★★
///
/// ★★ エネルギーが 0 枚のときだけ、6.1.1.3 の未達を出さない ★★
///
/// ★★ 条文には反する。★利用者判断で表示しないことにした ★★
/// **6.1.1.3** はエネルギー 12 枚ちょうどを要求しており、**0 枚は満たさない**。
/// `docs/UI設計メモ.md` §12-3 の「0 枚を**完成**と呼ぶのは 6.1.1.3 に反する」は
/// ★**今も真である**。★覆したのは**表示の方針**であって条文の読みではない。
/// ★**`DeckValidator` は 1 行も変えていない** —— ★`issues` には今も入っている
/// （★★同期にもサーバーにも 1 ビットも影響しない★★）。
///
/// ★★ 0 だけを外す。1〜11 は外さない。★恣意ではない ★★
/// 盤面の補完（決定 **D96** / **D97**）は**0 枚のときだけ**行う
/// （`EnergyFillSkip.notNeeded` —— ★1 枚でもあれば補わない）。
/// → ★**0 枚のデッキは開始時に 12 枚になるが、★1〜11 枚は★補われないまま始まる。**
/// ★**警告が要るのは補われない側である。**
///
/// ★★ 12 枚以上（13 枚〜）は★今も出す ★★
/// `energyCount == 0` だけを見るので、★超過は 1 ビットも変わらない。
List<DeckIssue> visibleDeckIssues(DeckValidationResult validation) =>
    validation.energyCount == 0
        ? validation.issues
            .where((i) => i.code != DeckIssueCode.energyCountMismatch)
            .toList(growable: false)
        : validation.issues;

class DeckValidationPanel extends StatelessWidget {
  const DeckValidationPanel({
    super.key,
    required this.validation,
    required this.config,
    this.energyFill,
    this.energyFillName,
  });

  final DeckValidationResult validation;
  final RuleConfig config;

  /// ★★ 軸 2（決定 D96-2）—— 盤面で何が起きるか ★★
  ///
  /// ★**軸 1 とは主語が違う。**上の「構築条件を満たしていません」は
  /// **デッキそのもの**についての 6.1.1.3 の判定であり、
  /// こちらは**盤面**の挙動（サンドボックス / **D-A** / **D81**）である。
  ///
  /// ★★ 2026-09-03: 「上の行は絶対に変えない」を覆した（★申し送り §1-1）★★
  /// ★以前はこう書いてあった ——「★**上の行は絶対に変えない** —— 0 枚を
  /// 「満たしている」と呼ぶことは 6.1.1.3 に反しており、解けない」。
  /// ★★**その判定そのものは今も真である**★★（★条文の読みは 1 ミリも動いていない）。
  /// ★★**利用者が★条文に反することを承知で「出さない」を選んだ**★★。
  /// ★**軸が 2 つあること自体は変わらない** —— ★1〜11 枚では今も上の行が「満たしていません」になる。
  final EnergyFillPlan? energyFill;

  /// 補うカードの表示名。★`energyFill` が補う場合だけ使う。
  final String? energyFillName;

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
    final shown = visibleDeckIssues(validation);
    final others = shown
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
                shown.isEmpty ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: shown.isEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shown.isEmpty ? '構築条件を満たしています' : '構築条件を満たしていません',
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
            // ★★ 0 枚は「未達」として色を付けない（★申し送り §1-1）★★
            //   ★上の見出しが「満たしています」と言っているのに
            //   ★この 1 行だけ未達の色になっていると★★2 つが食い違って読める★★。
            warn: validation.energyCount != 0,
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '未達 ${shown.length} 件',
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
          // ★★ 軸 2（決定 D96-2）★★ 上の行とは主語が違うことが読める形にする。
          if (_energyOnlyLine case final text?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                key: const ValueKey('energyFillNote'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.battery_charging_full_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(text, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ★★ エネルギーだけが不足しているときに限って出す（決定 D96-2）★★
  ///
  /// ★**メンバー 47 枚のデッキで出してはいけない** ——
  /// 「盤面では補われます」と読めてしまい、**補完が効かない不足まで
  /// 補われるように見える。**
  ///
  /// ★**補えないときは文言を変える。**「補います」と書いて補われないのは嘘である
  /// （盤面側の `EnergyFillUnavailable` と揃える）。
  String? get _energyOnlyLine {
    final plan = energyFill;
    if (plan == null) return null;
    // ★6.1 を満たしているなら言うことは無い。
    if (validation.issues.isEmpty) return null;
    // ★★ 不足がエネルギーだけであること ★★
    final energyOnly = validation.issues
        .every((i) => i.code == DeckIssueCode.energyCountMismatch);
    if (!energyOnly) return null;

    if (plan.willFill) {
      final name = energyFillName;
      // ★★ 2026-09-03: 「上の 6.1 の判定は…変わりません」を消した ★★
      //   ★0 枚では上の見出しが「満たしています」になったので（★申し送り §1-1）、
      //   ★★あの 1 文は偽になった★★。★消すのは訂正である（**D-25** の型）。
      return '盤面では、開始時にエネルギーを ${plan.count} 枚'
          '${name == null ? '' : '（$name）'}補って始めます。';
    }
    return switch (plan.skip!) {
      // ★補完しないのは利用者の選択。★「エネルギーが出ない」ことだけを言う。
      EnergyFillSkip.unset => '盤面では補完しません。エネルギーが 1 枚も出ないまま始まります。'
          '設定で補うカードを選べます。',
      EnergyFillSkip.unknownCardNumber ||
      EnergyFillSkip.unknownPrinting ||
      EnergyFillSkip.notEnergy =>
        '盤面で補うカードを用意できません。設定で選び直してください。'
            'このままだとエネルギーが 1 枚も出ません。',
      // ★0 枚でなければここへ来ない（`energyOnly` が真なら 0 枚か 13 枚以上）。
      EnergyFillSkip.notNeeded => null,
    };
  }
}

/// 「メンバー 0 / 48」の 1 行。★過不足を色でも分かるようにする。
class _CountLine extends StatelessWidget {
  const _CountLine({
    required this.label,
    required this.actual,
    required this.expected,
    this.warn = true,
  });

  final String label;
  final int actual;
  final int expected;

  /// ★★ 過不足を「未達」として見せるか（★申し送り §1-1）★★
  /// ★false でも**数はそのまま出す** —— ★消すのではなく、★色を付けないだけである。
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 総合ルール 6.1.1 は「ちょうど」なので、多くても少なくても不足である。
    final ok = actual == expected || !warn;
    return Text(
      '$label $actual / $expected',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: ok ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: ok ? FontWeight.w600 : null,
      ),
    );
  }
}
