/// ハートとブレードハートのアイコンの表示（CLAUDE.md §6 / 総合ルール 2.1.1）.
///
/// ★★★ 色ハートと非色アイコンを同じ入れ物で描かない ★★★
/// `loveca_core` が `Map<HeartColor,int>` と `Map<BladeHeartEffect,int>` を
/// **型で分けている**理由がそのまま表示にも当てはまる。
///
/// | | 参照する時点 | 合算先 |
/// |---|---|---|
/// | 色（`hearts` / `requiredHearts` / `bladeHearts`） | 8.3.14 | **ライブ所有ハートに合算する** |
/// | `DRAW`（8.3.12.1） | ハート合計より**前** | 合算しない（カードを引く） |
/// | `SCORE`（8.4.2.1） | スコア集計 | 合算しない |
///
/// 同じ並びに混ぜて出すと、**画面の上で 8.3.14 の合算対象を取り違える。**
/// → [HeartChips] と [BladeHeartEffectChips] を別のウィジェットにしてある。
///
/// ★★★ ここで使う色は「表示用」であって対応表ではない ★★★
/// CLAUDE.md §5-(2) のとおり、実データには**色マッピングが 3 系統**あり
/// （系統A `heartNN` フィールド / 系統B `heart_NN.png` 画像 / 系統C 日本語）、
/// **系統A と系統B は 02/03/04/05 が食い違う。**
/// ここは**アイコン画像を一切使わない**（日本語ラベル + 汎用の丸）ので、
/// 系統A / 系統B の選択そのものが発生しない。
/// ★**アイコン画像を出し始めるときは必ず CLAUDE.md §5-(2) を読むこと。**
/// 系統A を使うと**カードテキストの色表示が全件誤る。**
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

/// 表示の並び順。★Map の反復順に任せない（同じデータで並びが変わる）。
///
/// 総合ルール 2.1.1.1 の 6 色 → [HeartColor.gray]（2.1.1.2）→
/// [HeartColor.all]（2.1.1.3）。
const List<HeartColor> heartDisplayOrder = [
  ...HeartColor.sixColors,
  HeartColor.gray,
  HeartColor.all,
];

/// 系統C（日本語表記 / CLAUDE.md §5-(2)）。
String heartLabel(HeartColor color) => switch (color) {
      HeartColor.pink => '桃',
      HeartColor.red => '赤',
      HeartColor.yellow => '黄',
      HeartColor.green => '緑',
      HeartColor.blue => '青',
      HeartColor.purple => '紫',
      // 総合ルール 2.1.1.2: 色を指定しないハート。
      HeartColor.gray => '無',
      // 総合ルール 2.1.1.3: 任意の 1 色として扱えるハート。
      HeartColor.all => 'ALL',
    };

/// ★**表示用の色**。系統A / 系統B の対応表ではない（上の doc）。
Color _swatch(HeartColor color, ThemeData theme) => switch (color) {
      HeartColor.pink => const Color(0xFFEC6FA0),
      HeartColor.red => const Color(0xFFE24B4B),
      HeartColor.yellow => const Color(0xFFE8B32A),
      HeartColor.green => const Color(0xFF4CAF6B),
      HeartColor.blue => const Color(0xFF4A8FE0),
      HeartColor.purple => const Color(0xFF9A6BD1),
      // 「無」と「ALL」は特定の色ではない。色を当てず地の色で出す。
      HeartColor.gray => theme.colorScheme.outline,
      HeartColor.all => theme.colorScheme.onSurfaceVariant,
    };

/// 色ハートの並び（`hearts` / `requiredHearts` / `bladeHearts`）。
class HeartChips extends StatelessWidget {
  const HeartChips({super.key, required this.hearts});

  final Map<HeartColor, int> hearts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final color in heartDisplayOrder)
          if (hearts[color] case final count?)
            _Chip(
              // ★丸は「色がある」ことの目印。ALL / 無 は地の色になる。
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _swatch(color, theme),
                  shape: BoxShape.circle,
                ),
              ),
              text: '${heartLabel(color)} $count',
            ),
      ],
    );
  }
}

/// ブレードハートの**非色**アイコン（8.3.12.1 ドロー / 8.4.2.1 スコア）。
///
/// ★★ 色ハートと同じ並びに入れない ★★
class BladeHeartEffectChips extends StatelessWidget {
  const BladeHeartEffectChips({super.key, required this.effects});

  final Map<BladeHeartEffect, int> effects;

  /// ★内部語彙（`DRAW` / `SCORE`）を画面に出さない。
  static String labelOf(BladeHeartEffect effect) => switch (effect) {
        BladeHeartEffect.draw => 'ドロー',
        BladeHeartEffect.score => 'スコア',
      };

  static IconData _iconOf(BladeHeartEffect effect) => switch (effect) {
        BladeHeartEffect.draw => Icons.file_download_outlined,
        BladeHeartEffect.score => Icons.star_border,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // ★並びを決定的にする（enum の宣言順）。
        for (final effect in BladeHeartEffect.values)
          if (effects[effect] case final count?)
            _Chip(
              leading: Icon(
                _iconOf(effect),
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              text: '${labelOf(effect)} $count',
            ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 5),
            Text(text, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
