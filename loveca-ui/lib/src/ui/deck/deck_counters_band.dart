/// デッキの 3 本のカウンタ（`docs/Android UI 決定.md` §3-4）.
///
/// ★★ メンバー / ライブ / エネルギー の「いま何枚 / 何枚必要か」を常時出す帯 ★★
///
/// ★★ 段は 1 か 3 である。★2 段の状態は作らない（§3-4）★★
/// ★**1 段に入らなければ★★そのまま 3 段へ行く★★**（★2 本ずつ折り返さない）。
/// ★**ラベルは縮めない**（★§3-4 —— ★★入らなければ 3 段である★★）。
///
/// ★★ しきい値は実測して決める（§3-4）★★
/// ★**定数として書かない** —— ★★`LayoutBuilder` が実際の幅を見て決める★★。
/// ★「411 論理px で 1 段に入るか」は `test/ui/deck_counters_band_test.dart` が測っている。
///
/// ★★ 判断点はこの widget の中に閉じる（§3-4）★★
/// ★**`PaneScaffold` のしきい値を増やさない**（**D61** は 1 ビットも動かない）。
///
/// ★★ 枚数を数え直さない（決定 D28）★★
/// ★`DeckValidationResult` を受け取る。★★ここで数えると検証が二重になる★★
/// （★`energy_fill.dart` が同じ理由で `energyCount` を受け取っているのと同じ形）。
///
/// ★★ 「超過」は数字を赤にする（§3-4）★★
/// ★**総合ルール 6.1.1 は「ちょうど」なので、多くても少なくても足りていない。**
/// ★★ただし★★赤にするのは超過だけである★★（★§3-4 の字面）—— ★不足は赤にしない。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

/// 1 本ぶんの中身。★**画面もテストもここを読む**（★書き写さない）。
typedef DeckCounter = ({String label, int actual, int expected});

/// 3 本を組み立てる。★並びは メンバー → ライブ → エネルギー（§3-3 の図の順）。
///
/// ★★ ラベルは `DeckValidationPanel` の 3 行と同じ字面である ★★
/// ★同じものを 2 つの語で呼ばない（★先例は M-B5 の帯の文言）。
List<DeckCounter> deckCountersOf(
  DeckValidationResult validation,
  RuleConfig config,
) =>
    [
      (
        label: 'メンバー',
        actual: validation.memberCount,
        expected: config.memberCount
      ),
      (label: 'ライブ', actual: validation.liveCount, expected: config.liveCount),
      (
        label: 'エネルギー',
        actual: validation.energyCount,
        expected: config.energyDeckSize
      ),
    ];

/// 3 本が [available] の幅に 1 段で入るか。
///
/// ★★ 純粋関数にしてある ★★
/// ★**しきい値を実測するのはこの関数である**（★widget を立てずに刻める）。
/// ★[widths] は 1 本ずつの必要幅、[gap] は本と本のあいだ。
bool fitsOneRow(List<double> widths, double gap, double available) {
  if (widths.isEmpty) return true;
  final total =
      widths.fold<double>(0, (a, b) => a + b) + gap * (widths.length - 1);
  return total <= available;
}

class DeckCountersBand extends StatelessWidget {
  const DeckCountersBand({
    super.key,
    required this.validation,
    required this.config,
  });

  final DeckValidationResult validation;
  final RuleConfig config;

  /// 本と本のあいだ。★1 段のときだけ効く。
  static const double gap = 16;

  @override
  Widget build(BuildContext context) {
    final counters = deckCountersOf(validation, config);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [
          for (final c in counters) _measure(context, c, theme).width,
        ];
        final oneRow = fitsOneRow(widths, gap, constraints.maxWidth);
        final items = [
          for (final c in counters) _CounterText(counter: c),
        ];
        // ★★ 2 段の状態は作らない（§3-4）★★
        //   ★`Wrap` を使うと**入る本数だけ 1 段目に載る** = 2 段が作れてしまう。
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: oneRow
              ? Row(
                  key: const ValueKey('deckCounters:oneRow'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: items,
                )
              : Column(
                  key: const ValueKey('deckCounters:threeRows'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items,
                ),
        );
      },
    );
  }

  Size _measure(BuildContext context, DeckCounter c, ThemeData theme) {
    final painter = TextPainter(
      text: TextSpan(
        text: _CounterText.textOf(c),
        style: theme.textTheme.bodyMedium,
      ),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.size;
  }
}

class _CounterText extends StatelessWidget {
  const _CounterText({required this.counter});

  final DeckCounter counter;

  static String textOf(DeckCounter c) => '${c.label} ${c.actual} / ${c.expected}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ★★ 赤にするのは超過だけである（§3-4 の字面）★★
    //   ★不足は赤にしない —— ★★組んでいる途中は必ず不足している★★。
    final over = counter.actual > counter.expected;
    return Text(
      textOf(counter),
      key: ValueKey('deckCounter:${counter.label}'),
      maxLines: 1,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: over ? theme.colorScheme.error : null,
        fontWeight: over ? FontWeight.w600 : null,
      ),
    );
  }
}
