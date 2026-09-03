/// Android のカード検索の一覧の 1 行（`docs/Android UI 決定.md` §3-2 / §3-3）.
///
/// ★★ 器は縦リストである（1 行 1 枚。★左に絵、★右に文字）★★
/// ★**Windows の格子（`CardGrid` / タイル比 200:279）とは★★別の形である★★。**
/// ★**`CardGrid` を 1 行も変えていない**（★あちらは Windows のまま）。
///
/// ★★ 何を重ね、★何を並べるか（§3-2 の表）★★
///
/// | 項目 | 決定 |
/// |---|---|
/// | 絵の左上 | ★**メンバー = コスト / ライブ = スコア** |
/// | その下 | ★**色付きブレードハート → ドロー・スコアのアイコン** を縦に積む |
/// | エネルギー | ★**絵に何も重ねない。★右はカード名だけ** |
/// | 作品名の溢れ | ★**1 行のまま末尾を「…」で切る**（★折り返さない） |
///
/// ★★ §12 の実測が★形を 3 か所直した ★★
///
/// | # | ★§3-2 の絵 | ★★実測（§12 / 2026-09-03）★★ |
/// |---|---|---|
/// | ★**1** | ★メンバーの 3 行目は「(ハート)数字 (ハート)数字」＝ **2 つ** | ★★**最大 4 つ**★★（**W-75**）→ ★**数を決め打ちしない** |
/// | ★**2** | ★ライブの 2 行目は「必要ハート((ハート)数字…)」 | ★★**最大 7 つ / 合計 21**★★（**W-76**）→ ★**同上** |
/// | ★**3** | ★メンバーの「(D/S)」 | ★★**メンバーは 0 種である**★★（**W-77**）→ ★**出ない。★★出せないのではなく★データが 1 件も無い★★** |
///
/// ★★ ハートの符号 —— ★★アイコン画像を使わない★★（★§3-2 と食い違う。★理由を書く）★★
/// ★**§3-2 は「(ハートアイコン画像)数字」と定め、★素材は★★設計ファイルに在る★★と書いている。**
/// ★★**その設計ファイルはこのリポジトリに 1 バイトも無い**★★（★走査した / 2026-09-03）。
/// → ★**既に在る [HeartChips] の語彙（★色の丸 ＋ 日本語 1 文字 ＋ 数字）で描く。**
/// ★★**差し替え点は [CardHeartRow] 1 か所である**★★（★素材が入ったらそこだけを替える）。
/// ★**`CLAUDE.md` §5-(2) を読まずにアイコン画像を入れないこと** ——
/// ★★系統A を使うと★カードテキストの色表示が全件誤る★★。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_core/loveca_core.dart' as core show Card;

import '../../data/card_image_source.dart';
import '../common/card_thumb.dart';
import '../common/heart_chips.dart';

/// 絵に重ねるもの（§3-2 の「絵の左上」と「その下」）。
///
/// ★★ 純粋関数にしてある ★★
/// ★**種別ごとの出し分けを widget の中に埋めると★対が置けない**
/// （★先例は `deck_counters_band.dart` の `fitsOneRow`）。
typedef CardArtOverlay = ({
  /// ★左上の数字。★★エネルギーは `null`★★（§3-2 —— ★絵に何も重ねない）。
  int? corner,

  /// ★色付きブレードハート。★★メンバーの 55.6 % が持つ★★（**W-77**）。
  Map<HeartColor, int> bladeHearts,

  /// ★ドロー / スコア。★★メンバーは 0 種である★★（**W-77**）。
  Map<BladeHeartEffect, int> effects,
});

/// [card] から重ねるものを決める。
///
/// ★★ エネルギーには 1 つも重ねない（§3-2）★★
/// ★**「持っていないから空になる」ではなく★★出さないと決めている★★**
/// （★実測でも `bladeHearts` / `bladeHeartEffects` とも 0 種 / **W-77**）。
/// → ★**データが増えても出さない**（★対で固定した）。
CardArtOverlay cardArtOverlayOf(core.Card card) => switch (card.cardType) {
      CardType.energy =>
        (corner: null, bladeHearts: const {}, effects: const {}),
      // ★★ メンバー = コスト / ライブ = スコア（§3-2 の「絵の左上」）★★
      CardType.member => (
          corner: card.cost,
          bladeHearts: card.bladeHearts,
          effects: card.bladeHeartEffects,
        ),
      CardType.live => (
          corner: card.score,
          bladeHearts: card.bladeHearts,
          effects: card.bladeHeartEffects,
        ),
    };

/// 1 行目（★作品名, ユニット）。★★エネルギーは出さない★★（§3-2 —— ★右はカード名だけ）。
///
/// ★★ 「…」で切れるのは 7 種だけである（**W-78** / 0.41 %）★★
/// ★**それでも★★折り返さない★★**（§3-2）—— ★行の高さが揃わなくなる。
String? cardSubtitleOf(core.Card card) {
  if (card.cardType == CardType.energy) return null;
  final parts = [...card.groupNames, ...card.unitNames];
  if (parts.isEmpty) return null;
  return parts.join(', ');
}

/// Android の一覧の 1 行。
class CardListTile extends StatelessWidget {
  const CardListTile({
    super.key,
    required this.card,
    required this.printing,
    required this.imageSource,
    this.onTap,
    this.artWidth = 64,
  });

  final core.Card card;
  final Printing printing;
  final CardImageSource imageSource;
  final VoidCallback? onTap;

  /// 左の絵の論理幅。
  final double artWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = cardArtOverlayOf(card);
    final subtitle = cardSubtitleOf(card);
    return InkWell(
      key: ValueKey('cardListTile:${printing.printingId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Art(
              overlay: overlay,
              card: card,
              printing: printing,
              imageSource: imageSource,
              width: artWidth,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ★★ 0 行目 —— ★カード名（大きい文字）★★
                  Text(
                    card.name,
                    key: const ValueKey('cardListTile:name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  // ★★ 1 行目 —— ★作品名, ユニット（★1 行のまま「…」で切る / §3-2）★★
                  if (subtitle != null)
                    Text(
                      subtitle,
                      key: const ValueKey('cardListTile:subtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  // ★★ 2 行目 —— ★メンバー = ブレード / ライブ = 必要ハート ★★
                  if (card.cardType == CardType.member &&
                      card.bladeCount != null)
                    Text(
                      'ブレード ${card.bladeCount}',
                      key: const ValueKey('cardListTile:blade'),
                      maxLines: 1,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (card.cardType == CardType.live &&
                      card.requiredHearts.isNotEmpty)
                    CardHeartRow(
                      key: const ValueKey('cardListTile:requiredHearts'),
                      label: '必要ハート',
                      hearts: card.requiredHearts,
                    ),
                  // ★★ 3 行目 —— ★メンバーの所持ハート（★最大 4 色 / **W-75**）★★
                  if (card.cardType == CardType.member &&
                      card.hearts.isNotEmpty)
                    CardHeartRow(
                      key: const ValueKey('cardListTile:hearts'),
                      hearts: card.hearts,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ハートを「符号 ＋ 数字」で並べる 1 行。
///
/// ★★ ここが★アイコン画像への差し替え点である（★上の doc）★★
/// ★**いまは [heartLabel]（系統C ＝ 日本語）と★色の丸で描く。**
/// ★**数を決め打ちしない** —— ★★メンバーは最大 4 色、★ライブの必要ハートは最大 7 色★★（**W-75** / **W-76**）。
/// ★**並びは [heartDisplayOrder]**（★Map の反復順に任せない）。
class CardHeartRow extends StatelessWidget {
  const CardHeartRow({super.key, required this.hearts, this.label});

  final Map<HeartColor, int> hearts;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [
      for (final color in heartDisplayOrder)
        if ((hearts[color] ?? 0) > 0) (color, hearts[color]!),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Text(label!, style: theme.textTheme.bodySmall),
        for (final (color, count) in entries)
          Text(
            '${heartLabel(color)}$count',
            key: ValueKey('cardListHeart:${color.name}'),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({
    required this.overlay,
    required this.card,
    required this.printing,
    required this.imageSource,
    required this.width,
  });

  final CardArtOverlay overlay;
  final core.Card card;
  final Printing printing;
  final CardImageSource imageSource;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: width / cardAspectRatioOf(card.cardType),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CardArt(
            source: imageSource,
            imageHash: printing.imageHash,
            cardType: card.cardType,
            logicalWidth: width,
          ),
          // ★★ 絵の左上（§3-2）★★
          //   ★エネルギーは `corner` が null なので★1 つも重ならない。
          if (overlay.corner != null)
            Positioned(
              left: 0,
              top: 0,
              child: _Badge(
                text: '${overlay.corner}',
                keyName: 'cardListTile:corner',
              ),
            ),
          // ★★ その下 —— ★色付きブレードハート → ドロー / スコア（§3-2）★★
          //   ★**順序は §3-2 の字面どおり**（★色が先、★アイコンが後）。
          Positioned(
            left: 0,
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final color in heartDisplayOrder)
                  if ((overlay.bladeHearts[color] ?? 0) > 0)
                    _Badge(
                      text: '${heartLabel(color)}${overlay.bladeHearts[color]}',
                      keyName: 'cardListTile:bladeHeart:${color.name}',
                      color: theme.colorScheme.secondaryContainer,
                    ),
                for (final effect in BladeHeartEffect.values)
                  if ((overlay.effects[effect] ?? 0) > 0)
                    _Badge(
                      text: BladeHeartEffectChips.labelOf(effect),
                      keyName: 'cardListTile:effect:${effect.name}',
                      color: theme.colorScheme.tertiaryContainer,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.keyName, this.color});

  final String text;
  final String keyName;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          text,
          key: ValueKey(keyName),
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
