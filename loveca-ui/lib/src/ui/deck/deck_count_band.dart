/// Android の枚数の帯（`docs/Android UI 決定.md` §3-8）.
///
/// ★★ 「いま何枚入っているか」を出し、★数字を押して枚数を決める帯 ★★
/// ★**Windows の「− 枚数 +」（`deck_pane.dart` の `_CountControls`）とは★★別の形である★★。**
/// ★**あちらを 1 行も変えていない**（★増減 2 ボタン / ★活性は `canAdd`）。
///
/// ★★ 0 のボタンは★0 枚のときだけ出ない（§3-8 の表）★★
///
/// | 状態 | 帯 |
/// |---|---|
/// | ★**0 枚のとき** | ★**1 2 3 4**（★0 のボタンは**無い**） |
/// | ★**1 枚以上のとき** | ★**0 1 2 3 4**（★0 が左に現れ**灰色**。★選択中の数は**オレンジ**） |
///
/// ★★**0 を「無効なボタン」にしない**★★ —— ★**0 枚のときは★★列から消える★★。**
/// ★理由: ★**0 枚で 0 を押すと★★何も起きない★★**（§3-8 の「同じ数字を再度押す」）ので、
/// ★★押せるのに何も起きないボタンを置くことになる★★（★盤面の「黙って効かないボタンを作らない」と同じ向き / **U28**）。
///
/// ★★ 「…」はエネルギーだけに付く（§3-8）★★
/// ★**総合ルール 6.1.1.2 は「メインデッキには」と書いている** ——
/// ★★**エネルギーデッキに 4 枚制限は無い**★★（★申し送り §6 の 3 / ★★条文の新所見★★）。
/// → ★**メンバー / ライブは 4 枚が上限なので★「…」を付けない。**
///
/// ★★ 他の刷りで埋まっている分で★押せる数を制限しない（§1-3 / 決定 D69 の向き）★★
/// ★**4 枚を超えても★入る。★★警告は `DeckValidator.validate` が出す★★**
/// （★2026-09-03 に `canAdd` が 4 枚制限で止めなくなった / `CLAUDE.md` §3）。
/// → ★**この帯は★★`canAdd` を 1 度も呼ばない★★**（★★呼ぶと 2 か所で判定することになる★★ / **D-15** の規約 3）。
///
/// ★★ 上限は `RuleConfig` から来る。★字面で書かない ★★
/// ★**エネルギーの 12 は `RuleConfig.energyDeckSize`、★4 は `maxCopiesPerCardNumber`。**
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

/// 帯の中身。★**画面もテストもここを読む**（★書き写さない）。
typedef DeckCountBandSpec = ({
  /// ★並べる数字。★★0 枚のときは 0 を含まない★★（§3-8）。
  List<int> numbers,

  /// ★末尾の「…」を出すか。★★エネルギーだけ★★（§3-8）。
  bool hasMore,

  /// ★右の大きな数字。★★0 枚では出さない★★（§3-8）。
  int? bigNumber,

  /// ★「…」を押したときのフォームの上限。★★エネルギー以外は null★★。
  int? moreMax,
});

/// [count] 枚入っている [cardType] の帯を組み立てる。
///
/// ★★ 純粋関数にしてある ★★
/// ★**種別ごとの出し分けを widget の中に埋めると★対が置けない**
/// （★先例は `deck_counters_band.dart` の `fitsOneRow` / `card_list_tile.dart` の `cardArtOverlayOf`）。
DeckCountBandSpec deckCountBandOf({
  required CardType cardType,
  required int count,
  RuleConfig config = RuleConfig.standard,
}) {
  final energy = cardType == CardType.energy;
  return (
    // ★★ 0 枚のときだけ 0 を落とす（§3-8）★★
    numbers: [
      if (count > 0) 0,
      for (var i = 1; i <= config.maxCopiesPerCardNumber; i++) i,
    ],
    hasMore: energy,
    bigNumber: count > 0 ? count : null,
    moreMax: energy ? config.energyDeckSize : null,
  );
}

/// 1 つの数字の見た目。
enum DeckCountEmphasis {
  /// ★選択中（★★オレンジ★★ / §3-8）。
  selected,

  /// ★0（★★灰色★★ / §3-8）。
  zero,

  /// ★それ以外。
  plain,
}

/// [value] のボタンの見た目を決める。
///
/// ★★ 純粋関数にしてある —— ★色を widget の中で分岐させると対が置けない ★★
/// ★★**選択中が 0 のときは★「選択中」を採る**★★ —— ★★0 枚の列に 0 は無い★★ので、
/// ★この場合は起こらない（★★合成の入力では作れるので★どちらを採るかを決めておく★★）。
DeckCountEmphasis deckCountEmphasisOf(int value, int count) {
  if (value == count) return DeckCountEmphasis.selected;
  if (value == 0) return DeckCountEmphasis.zero;
  return DeckCountEmphasis.plain;
}

/// 押しても何も起きないか（§3-8「同じ数字を再度押す → 何も起きない」）。
bool deckCountIsNoop(int value, int count) => value == count;

/// 「…」のフォームに並べる数（★0 から [max] まで）。
///
/// ★★ 純粋関数にしてある。★理由は★★対が置けないからである★★ ★★
/// ★**`ListView` は画面外を作らない**（`CLAUDE.md` §3 の M5 の作法）——
/// ★★**widget 越しでは「上限を 1 つ超えたものが無い」を見られない**★★
/// （★送っても★★最後の 1 つが構築されるとは限らない★★ /
/// ★実測: ★★`i <= max + 1` に変えても★対が 0 件だった★★）。
/// → ★**列そのものを★★合成の入力で当てる★★**（★★同じ処置の先例は §72 の (D) / §80-6 の (L)★★）。
List<int> deckCountPickerValues(int max) => [for (var i = 0; i <= max; i++) i];

/// Android の枚数の帯。
class DeckCountBand extends StatelessWidget {
  const DeckCountBand({
    super.key,
    required this.cardType,
    required this.count,
    required this.onSelect,
    this.config = RuleConfig.standard,
  });

  final CardType cardType;
  final int count;

  /// ★選ばれた枚数。★★同じ数字を押したときは呼ばれない★★（§3-8）。
  final ValueChanged<int> onSelect;

  final RuleConfig config;

  /// ★★ 「オレンジ」「灰色」の濃さは★申し送りが述べていない。★既定値である ★★
  /// ★**差し替え点はこの 2 つの定数である。**
  static const selectedColor = Color(0xFFF57C00);
  static const zeroColor = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    final spec = deckCountBandOf(
      cardType: cardType,
      count: count,
      config: config,
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final value in spec.numbers)
            _CountButton(
              value: value,
              emphasis: deckCountEmphasisOf(value, count),
              // ★★ 同じ数字を再度押しても何も起きない（§3-8）★★
              //   ★**無効にしない** —— ★★押せるが★呼ばない★★
              //   （★無効にすると「いま何枚か」が★活性から読めてしまい、
              //   ★★大きな数字と 2 か所で同じことを言う★★ / **D-15** の規約 3）。
              onTap: deckCountIsNoop(value, count)
                  ? null
                  : () => onSelect(value),
            ),
          // ★★ 「…」はエネルギーだけ（§3-8）★★
          if (spec.hasMore)
            TextButton(
              key: const ValueKey('deckCountBand:more'),
              onPressed: () => _openMore(context, spec.moreMax!),
              child: const Text('…'),
            ),
          const Spacer(),
          // ★★ 右の大きな数字。★0 枚では出さない（§3-8）★★
          if (spec.bigNumber != null)
            Text(
              '${spec.bigNumber}',
              key: const ValueKey('deckCountBand:big'),
              style: theme.textTheme.headlineSmall,
            ),
        ],
      ),
    );
  }

  Future<void> _openMore(BuildContext context, int max) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => DeckCountFullPicker(max: max, count: count),
    );
    // ★★ 選ばなかった / 同じ数字を選んだときは呼ばない（§3-8）★★
    if (chosen == null || deckCountIsNoop(chosen, count)) return;
    onSelect(chosen);
  }
}

/// 「…」を押したときのフォーム（§3-8 —— ★★最大 12 枚★★）.
///
/// ★★ キーボードで打たせない。★リストから選ぶ（§3-7 と同じ向き）★★
/// ★**0 も出す** —— ★★このフォームは「枚数を決める」ものであり、★0 は「入れない」である★★。
class DeckCountFullPicker extends StatelessWidget {
  const DeckCountFullPicker({
    super.key,
    required this.max,
    required this.count,
  });

  /// ★上限。★★`RuleConfig.energyDeckSize` から来る★★（★字面で書かない）。
  final int max;

  /// ★いま入っている枚数（★★印を付けるためだけに使う★★）。
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('deckCountFullPicker'),
      shrinkWrap: true,
      children: [
        for (final i in deckCountPickerValues(max))
          ListTile(
            key: ValueKey('deckCountFullPicker:$i'),
            title: Text('$i 枚'),
            trailing: i == count ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(i),
          ),
      ],
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.value,
    required this.emphasis,
    required this.onTap,
  });

  final int value;
  final DeckCountEmphasis emphasis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (emphasis) {
      DeckCountEmphasis.selected => DeckCountBand.selectedColor,
      DeckCountEmphasis.zero => DeckCountBand.zeroColor,
      DeckCountEmphasis.plain => null,
    };
    return InkWell(
      key: ValueKey('deckCountBand:$value'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          '$value',
          key: ValueKey('deckCountBand:label:$value'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: emphasis == DeckCountEmphasis.selected
                ? FontWeight.w700
                : null,
          ),
        ),
      ),
    );
  }
}
