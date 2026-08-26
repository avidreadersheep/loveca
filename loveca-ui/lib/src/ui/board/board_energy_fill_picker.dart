/// ★★ 補完に使うエネルギーカードを選ぶ（決定 D97）★★
///
/// ★★ アプリが選ばない。利用者が選ぶ ★★
/// 総合ルール **6.1.1.3** が縛るのは**種別と枚数**であり、**どのカードかは縛っていない。**
/// 実データでもエネルギーはゲーム上の差が 1 件も無い（差は絵と名前だけ）ので、
/// **選択は純粋に見た目の好みである。**
///
/// ★★ 刷りを選ばせる（cardNumber ではない）★★
/// `LL-E-002` は**非パラレル刷りが 2 件**あり、**決定 D68 が開示対象にした 19 種**の 1 つ。
/// cardNumber では刷りが決まらず、2 刷りは絵柄が別物である。
/// → **printingId をそのまま選ばせれば、推論が発生しない。**
///
/// ★★ 「補完しない」を選べること ★★
/// 0 枚のまま開始するのは正当である（**D81** / **D-A**）。
/// 外す口が無いと片道になる（`_CoverPicker` の「カバーを外す」と同じ作法）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_image_source.dart';
import '../../data/card_list_row.dart';
import '../common/card_thumb.dart';

/// 選んだ結果。★`null` を返すダイアログでは「やめた」と区別できないので包む。
class EnergyFillChoice {
  const EnergyFillChoice(this.printingId);

  /// `null` は「補完しない」。★「やめた」は `showEnergyFillPicker` が `null` を返す。
  final String? printingId;
}

/// エネルギーの刷りだけを並べて 1 つ選ばせる。
///
/// 戻り値が `null` なら**やめた**（呼び出し側は何も変えない）。
Future<EnergyFillChoice?> showEnergyFillPicker(
  BuildContext context, {
  required List<CardListRow> rows,
  required String? selected,
  required CardImageSource imageSource,
}) =>
    showDialog<EnergyFillChoice>(
      context: context,
      builder: (_) => _EnergyFillPicker(
        rows: rows,
        selected: selected,
        imageSource: imageSource,
      ),
    );

/// [rows] からエネルギーの刷りだけを取り出して cardNumber 順に並べる。
///
/// ★★ 種別は `CardType` で見る（文字列比較にしない）★★
/// ★**パラレルも残す** —— 6.1.1.3 は刷りを区別しないので、
///   ここで落とすと利用者が選べる絵が減るだけである。
List<CardListRow> energyRowsOf(List<CardListRow> rows) {
  final out = rows.where((r) => r.cardType == CardType.energy).toList()
    ..sort((a, b) {
      final byNumber = a.cardNumber.compareTo(b.cardNumber);
      // ★同じ cardNumber の中は printingId 順（D68 が使うのと同じ並び）。
      return byNumber != 0 ? byNumber : a.printingId.compareTo(b.printingId);
    });
  return out;
}

class _EnergyFillPicker extends StatefulWidget {
  const _EnergyFillPicker({
    required this.rows,
    required this.selected,
    required this.imageSource,
  });

  final List<CardListRow> rows;
  final String? selected;
  final CardImageSource imageSource;

  @override
  State<_EnergyFillPicker> createState() => _EnergyFillPickerState();
}

class _EnergyFillPickerState extends State<_EnergyFillPicker> {
  late final List<CardListRow> _all = energyRowsOf(widget.rows);
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// ★絞り込みはメモリ上で行う（**決定 D48**）。
  ///   エネルギーは実データで 717 刷りしかなく、DB へ行く理由が無い。
  List<CardListRow> get _shown {
    final q = _query.text.trim();
    if (q.isEmpty) return _all;
    final lower = q.toLowerCase();
    return _all
        .where((r) =>
            r.cardNumber.toLowerCase().contains(lower) ||
            r.name.toLowerCase().contains(lower) ||
            r.expansion.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return AlertDialog(
      title: const Text('補完に使うエネルギーカード'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            Text(
              '総合ルール 6.1.1.3 はエネルギーカード 12 枚ちょうどを求めますが、'
              'どのカードかは定めていません。'
              'エネルギーはゲーム上の差が無いので、絵柄の好みで選べます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('energyFillQuery'),
              controller: _query,
              decoration: const InputDecoration(
                labelText: 'カード番号 / 名前 / 収録商品で絞る',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              // ★0 件を黙らせない（決定 D53 の作法）。
              child: shown.isEmpty
                  ? const Center(child: Text('当てはまるエネルギーカードがありません'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 96,
                        childAspectRatio: 200 / 279,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (context, i) =>
                          _Cell(row: shown[i], picker: this),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        // ★★ 外す口（0 枚のまま開始するのは正当である）★★
        TextButton.icon(
          key: const ValueKey('energyFillNone'),
          onPressed: () =>
              Navigator.of(context).pop(const EnergyFillChoice(null)),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('補完しない'),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.row, required this.picker});

  final CardListRow row;
  final _EnergyFillPickerState picker;

  @override
  Widget build(BuildContext context) {
    final chosen = row.printingId == picker.widget.selected;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('energyFill:${row.printingId}'),
      onTap: () => Navigator.of(context).pop(EnergyFillChoice(row.printingId)),
      // ★★ 掴める / 押せる矩形を作るのは外側であって絵ではない（決定 D46 / D72）★★
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: chosen ? 3 : 1,
            color: chosen ? scheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Tooltip(
          message: '${row.name}\n${row.cardNumber}・${row.expansion}',
          child: CardArt(
            source: picker.widget.imageSource,
            imageHash: row.imageHash,
            // ★★ 箱は変えず、中の枠だけ種別で選ぶ（決定 D72）★★
            cardType: row.cardType,
            logicalWidth: 92,
          ),
        ),
      ),
    );
  }
}
