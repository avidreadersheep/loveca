/// Android の統計（`docs/Android UI 決定.md` §3-11 / §3-10 の「確認」タブ）.
///
/// ★★ 出すのは 4 つ。★横棒はコストの分布だけ（§3-11 の表）★★
///
/// | # | ★出すもの | ★横棒 |
/// |---|---|---|
/// | ★**1** | ★**3 本のカウンタ** | ★無し |
/// | ★**2** | ★**コストの分布** | ★★**あり**★★ |
/// | ★**3** | ★**ブレードハートの色の分布** | ★無し |
/// | ★**4** | ★**ブレードハートの数** | ★無し |
///
/// ★★ 「所持ハートの色の分布」は★置かない（§3-11）★★
/// ★**一度採ったあと★★利用者が撤回した★★**（★§3-11 が自らそう記録している）。
/// → ★**同じ検討をやり直さないこと。★★対で固定した★★**（★所持ハートの行が 1 つも出ない）。
///
/// ★★ 3 本のカウンタは★[DeckCountersBand] を呼ぶ。★数え直さない ★★
/// ★**同じものを 2 つの語で呼ばない**（★§3-4 のラベルと★§3-11 の 1 番は★同じ 3 本である）。
///
/// ★★ ブレードハートは★色だけを数える。★ドロー / スコアは混ぜない ★★
/// ★**`CLAUDE.md` §6 が★★型で分けてある理由を書いている★★** ——
/// ★総合ルール **8.3.14**（ハート合計）に合算するのは★★色だけ★★で、
/// ★ドローは **8.3.12.1**（★★8.3.14 より前★★）、★スコアは **8.4.2.1** と
/// ★★処理する時点が違う★★。→ ★**同じ勘定に入れると取り違える。**
/// ★**対で固定した**（★`bladeHeartEffects` を持つカードを入れても★数が 1 も動かない）。
///
/// ★★ コストはメンバーだけを数える ★★
/// ★**`Card.cost` は★★メンバーにしか値が無い★★**
/// （`loveca-data/loveca_data/normalize.py` は `KIND_MEMBER` の分岐でしか設定しない /
/// ★★ライブの `cost` は★ブレードハートの供給元として使われている★★ / `CLAUDE.md` §5-(1)）。
/// → ★**`cost != null` ではなく★★種別で絞る★★**（★★字面が入っていても拾わない★★ / ★対で固定した）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_core/loveca_core.dart' as core show Card;

import '../common/heart_chips.dart';
import 'deck_counters_band.dart';

/// デッキの 1 行（★★カードと枚数★★）。
///
/// ★★ カタログを引かない ★★
/// ★**`Card` は★★呼び出し側から受け取る★★**（★★U21 の論点 1 に 1 ミリも触らない★★ /
/// ★先例は `card_list_tile.dart` / `number_range_picker.dart`）。
typedef DeckStatEntry = ({core.Card card, int count});

/// 統計の中身。★**画面もテストもここを読む**（★書き写さない）。
typedef DeckStats = ({
  /// ★コスト → 枚数。★★メンバーだけ★★（★上の doc）。
  Map<int, int> costs,

  /// ★色 → 個数。★★色だけ★★（★ドロー / スコアは入らない）。
  Map<HeartColor, int> bladeHearts,

  /// ★ブレードハートの数（★★色の合計★★）。
  int bladeHeartTotal,
});

/// [entries] から統計を作る。
///
/// ★★ 純粋関数にしてある ★★
/// ★**枚数の重みを widget の中で掛けると★対が置けない**
/// （★先例は `deck_counters_band.dart` の `deckCountersOf`）。
DeckStats deckStatsOf(Iterable<DeckStatEntry> entries) {
  final costs = <int, int>{};
  final bladeHearts = <HeartColor, int>{};
  var bladeHeartTotal = 0;
  for (final e in entries) {
    final card = e.card;
    // ★★ コストはメンバーだけ（★上の doc / `CLAUDE.md` §5-(1)）★★
    if (card.cardType == CardType.member && card.cost != null) {
      costs[card.cost!] = (costs[card.cost!] ?? 0) + e.count;
    }
    // ★★ ブレードハートは色だけ（★総合ルール 8.3.14 に合算するのは色である）★★
    for (final entry in card.bladeHearts.entries) {
      final n = entry.value * e.count;
      bladeHearts[entry.key] = (bladeHearts[entry.key] ?? 0) + n;
      bladeHeartTotal += n;
    }
  }
  return (
    costs: costs,
    bladeHearts: bladeHearts,
    bladeHeartTotal: bladeHeartTotal,
  );
}

/// 横棒の長さの割合（★0.0 〜 1.0）。
///
/// ★★ 純粋関数にしてある —— ★★最大が 0 のときに割らない★★ ★★
/// ★**空のデッキでも★★例外を出さない★★**（★対で固定した）。
double deckStatBarFraction(int value, int max) {
  if (max <= 0) return 0;
  final f = value / max;
  return f < 0 ? 0 : (f > 1 ? 1 : f);
}

/// コストの分布の並び（★★昇順★★。★Map の反復順に任せない）。
List<int> deckStatCostOrder(Map<int, int> costs) {
  final keys = costs.keys.toList()..sort();
  return keys;
}

/// Android の統計。
class DeckStatsSection extends StatelessWidget {
  const DeckStatsSection({
    super.key,
    required this.entries,
    required this.validation,
    this.config = RuleConfig.standard,
  });

  final List<DeckStatEntry> entries;
  final DeckValidationResult validation;
  final RuleConfig config;

  @override
  Widget build(BuildContext context) {
    final stats = deckStatsOf(entries);
    final theme = Theme.of(context);
    final costOrder = deckStatCostOrder(stats.costs);
    final costMax = stats.costs.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      key: const ValueKey('deckStats'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ★★ 1 —— ★3 本のカウンタ（★数え直さない）★★
        DeckCountersBand(validation: validation, config: config),
        // ★★ 2 —— ★コストの分布（★★横棒あり★★）★★
        _Heading(text: 'コストの分布', keyName: 'deckStats:costs'),
        for (final cost in costOrder)
          _CostRow(
            cost: cost,
            count: stats.costs[cost]!,
            fraction: deckStatBarFraction(stats.costs[cost]!, costMax),
          ),
        // ★★ 3 —— ★ブレードハートの色の分布（★横棒なし）★★
        _Heading(
          text: 'ブレードハートの色の分布',
          keyName: 'deckStats:bladeHeartColors',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            children: [
              // ★★ 並びは `heartDisplayOrder`（★Map の反復順に任せない）★★
              for (final color in heartDisplayOrder)
                if ((stats.bladeHearts[color] ?? 0) > 0)
                  Text(
                    '${heartLabel(color)}${stats.bladeHearts[color]}',
                    key: ValueKey('deckStats:bladeHeart:${color.name}'),
                    style: theme.textTheme.bodyMedium,
                  ),
            ],
          ),
        ),
        // ★★ 4 —— ★ブレードハートの数（★横棒なし）★★
        _Heading(text: 'ブレードハートの数', keyName: 'deckStats:bladeHeartTotal'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '${stats.bladeHeartTotal}',
            key: const ValueKey('deckStats:bladeHeartTotal:value'),
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.keyName});

  final String text;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 2),
      child: Text(
        text,
        key: ValueKey(keyName),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.cost,
    required this.count,
    required this.fraction,
  });

  final int cost;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$cost',
              key: ValueKey('deckStats:cost:$cost'),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: FractionallySizedBox(
              key: ValueKey('deckStats:costBar:$cost'),
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                height: 8,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            key: ValueKey('deckStats:costCount:$cost'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
