/// Android の数値の指定（`docs/Android UI 決定.md` §3-7）.
///
/// ★★ キーボードで打たせない。★リストから選ぶ（§3-7）★★
/// ★**値の欄は★★ボタンである★★**（★押すとフォームが開く）。
/// ★★**`TextField` は★フォームの「絞り込み」1 本だけである**★★ ——
/// ★あれは★★リストそのものを絞るもので、★値を入れるものではない★★（★§3-7 の絵）。
/// ★**対で固定した**（★値の行に `TextField` が 1 つも無いこと）。
///
/// ★★ 対象の軸（§3-7 の字面）★★
/// ★**コスト / ブレード / スコア / 合計ハート / 各色ハート / 合計必要ハート / 各色必要ハート。**
/// ★★**この 7 つは「数値を指定する軸」であって、★ブレードハートは入らない**★★
/// （★§3-6 —— ★★ブレードハートは★色のみで絞る★★）。
///
/// ★★ リストの終端は★実データの最大値である（§3-7）★★
/// ★**測った値を★★字面で持たない★★** —— ★[numberAxisMax] が★★カードから導く★★。
/// ★**§12-5 に測った値が在る**（★2026-09-03 / ★コスト 22 / ブレード 7 / スコア 9 /
/// ★合計ハート 9 / ★合計必要ハート 21）が、★★定数として置かない★★ ——
/// ★★**新しい商品で増えうる**★★（**D-28** —— ★「今後も同じである」とは書かない）。
///
/// ★★ 8 通りを持てる形にしておき、★出すかどうかを 1 か所で決める（§12-6）★★
/// ★**この層は★★色を 1 つも知らない★★** —— ★[NumberRangeField] は★ラベルと上限を受け取るだけである。
/// → ★**どの色を出すかは★★呼ぶ側（§3-6 の絞り込みチップ）が決める★★**（★★1 行も無い★★）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' as core;

import '../../data/card_list_row.dart' show NumberRange;

/// 範囲の型は★★データ層が持つ★★（**D-15** の規約 3 —— ★★同じ型を 2 か所に持たない★★）。
///
/// ★**2026-09-04 に移した** —— ★★絞り込み（`CardListFilter`）も同じ型を要る★★が、
/// ★★あちらは Flutter に依存しない★★ので、★依存の少ない側に置いた。
export '../../data/card_list_row.dart' show NumberRange;

/// フォームの答え。
///
/// ★★ 「キャンセル」と「未指定を選んだ」を★分ける ★★
/// ★**返り値そのものが `null` なら★★キャンセル★★**（★何も変えない）。
/// ★**`(value: null)` なら★★未指定を選んだ★★**（★★変える★★）。
/// → ★**2 つを 1 つの `int?` に畳むと★★区別できない★★。**
typedef NumberPick = ({int? value});

/// フォームに並べる選択肢（★★未指定 ＋ 0 から [max] まで★★）。
///
/// ★★ 純粋関数にしてある ★★
/// ★**`ListView` は画面外を作らないので、★★列そのものは widget 越しに見られない★★**
/// （**D-10** / ★先例は `deck_count_band.dart` の `deckCountPickerValues`）。
List<int?> numberPickerOptions(int max) => [
      null,
      for (var i = 0; i <= max; i++) i,
    ];

/// 選択肢の字面。★★`null` は「未指定」★★（§3-7 の絵）。
String numberOptionLabel(int? value) => value == null ? '未指定' : '$value';

/// リストそのものを絞る（§3-7 の「絞り込み」）。
///
/// ★★ 一致は「含む」である。★これは既定値である ★★
/// ★**§3-7 は★★一致の条件を 1 文字も述べていない★★**（★絵に欄が在るだけ）。
/// → ★**前方一致にすると「1」で 21 が出ない。★★含むにすると出る★★。**
/// ★★**差し替え点はこの関数 1 か所である。**★★
List<int?> filterNumberOptions(List<int?> options, String query) {
  final q = query.trim();
  if (q.isEmpty) return options;
  return [
    for (final o in options)
      if (numberOptionLabel(o).contains(q)) o,
  ];
}

/// 軸の終端を★カードから導く（§3-7 —— ★★実データの最大値★★）。
///
/// ★★ 測った値を★字面で持たない ★★
/// ★**§12-5 の値は★★測定であって定数ではない★★**（**D-28**）。
/// ★**1 枚も持っていなければ 0 を返す** —— ★★`null` にしない★★
/// （★★「軸が無い」と「上限が 0」は★フォームの側で同じ形になる★★ ＝ ★未指定と 0 だけが並ぶ）。
int numberAxisMax(
  Iterable<core.Card> cards,
  int? Function(core.Card card) valueOf,
) {
  var max = 0;
  for (final card in cards) {
    final v = valueOf(card);
    if (v != null && v > max) max = v;
  }
  return max;
}

/// 1 つの軸の行（★★`ラベル [ 未指定 ]個 ～ [ 未指定 ]個`★★ / §3-7 の絵）。
class NumberRangeField extends StatelessWidget {
  const NumberRangeField({
    super.key,
    required this.label,
    required this.range,
    required this.max,
    required this.onChanged,
  });

  /// ★軸の名前（★「合計ハート」「桃ハート」など）。★★この層は色を知らない★★。
  final String label;

  final NumberRange range;

  /// ★★ フォームの終端。★[numberAxisMax] が導いた値を★呼ぶ側が渡す ★★
  final int max;

  final ValueChanged<NumberRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          _ValueButton(
            keyName: 'numberRange:$label:min',
            value: range.min,
            max: max,
            title: '$label（下）',
            onPicked: (pick) => onChanged((min: pick.value, max: range.max)),
          ),
          const Text('個 ～ '),
          _ValueButton(
            keyName: 'numberRange:$label:max',
            value: range.max,
            max: max,
            title: '$label（上）',
            onPicked: (pick) => onChanged((min: range.min, max: pick.value)),
          ),
          const Text('個'),
        ],
      ),
    );
  }
}

/// 値の欄。★★ボタンである（★キーボードで打たせない / §3-7）★★
class _ValueButton extends StatelessWidget {
  const _ValueButton({
    required this.keyName,
    required this.value,
    required this.max,
    required this.title,
    required this.onPicked,
  });

  final String keyName;
  final int? value;
  final int max;
  final String title;
  final ValueChanged<NumberPick> onPicked;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: ValueKey(keyName),
      onPressed: () async {
        final pick = await showModalBottomSheet<NumberPick>(
          context: context,
          isScrollControlled: true,
          builder: (context) =>
              NumberPickerSheet(title: title, max: max, value: value),
        );
        // ★★ キャンセルなら何も変えない（★`null` はキャンセルである）★★
        if (pick == null) return;
        onPicked(pick);
      },
      child: Text(numberOptionLabel(value)),
    );
  }
}

/// 値を 1 つ選ぶフォーム（§3-7 の絵）。
///
/// ★★ 「クリア」と「未指定」は★同じ結果になる。★隠さない ★★
/// ★**どちらも `(value: null)` を返す**（★対で固定した）。
/// ★★**違いは 1 つ在る**★★ —— ★**絞り込みに文字を入れて「未指定」が消えても、
/// ★★「クリア」は押せる★★**（★実測 / ★対で固定した）。
/// ★★**§3-7 が 2 つを置いた理由は★述べていない。★推測で埋めない**★★（**D-28**）。
class NumberPickerSheet extends StatefulWidget {
  const NumberPickerSheet({
    super.key,
    required this.title,
    required this.max,
    required this.value,
  });

  final String title;
  final int max;

  /// ★いま選ばれている値（★★印を付けるためだけに使う★★）。
  final int? value;

  @override
  State<NumberPickerSheet> createState() => _NumberPickerSheetState();
}

class _NumberPickerSheetState extends State<NumberPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = filterNumberOptions(
      numberPickerOptions(widget.max),
      _controller.text,
    );
    return SafeArea(
      child: Column(
        key: const ValueKey('numberPickerSheet'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const ValueKey('numberPickerSheet:query'),
              controller: _controller,
              decoration: InputDecoration(
                labelText: '絞り込み',
                suffixIcon: IconButton(
                  key: const ValueKey('numberPickerSheet:clearQuery'),
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_controller.clear),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Flexible(
            child: ListView(
              key: const ValueKey('numberPickerSheet:list'),
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    key: ValueKey('numberPickerSheet:option:${o ?? 'none'}'),
                    title: Text(numberOptionLabel(o)),
                    trailing:
                        o == widget.value ? const Icon(Icons.check) : null,
                    onTap: () =>
                        Navigator.of(context).pop<NumberPick>((value: o)),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('numberPickerSheet:cancel'),
                // ★★ キャンセルは★何も返さない（★値を変えない）★★
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              TextButton(
                key: const ValueKey('numberPickerSheet:clear'),
                onPressed: () =>
                    Navigator.of(context).pop<NumberPick>((value: null)),
                child: const Text('クリア'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
