/// 絞り込みチップの帯（★`docs/Android UI 決定.md` §3-6 / §28）.
///
/// ★★ 何を固定するか ★★
/// ★**並びが [kCardFilterAxes] のとおりであること** ／ ★**11 個であること** ／
/// ★**立っているかが★[CardListFilter] と★検索語から★★導かれる★★こと**（★自分で持たない）／
/// ★**押すと★★呼ぶ側へ渡すだけ★★であること**。
///
/// ★★ 並びの字面を書き写さない ★★
/// ★**期待は [kCardFilterAxes] を読む**（**D-15** の規約 3）。
/// ★**対で固定した** —— ★★字面を書き写す仕込みで落ちる★★。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/ui/browse/card_filter_chips.dart';

Future<void> _pump(
  WidgetTester tester, {
  CardListFilter filter = const CardListFilter(),
  String query = '',
  required List<CardFilterAxis> tapped,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardFilterChips(
          filter: filter,
          query: query,
          onTap: tapped.add,
        ),
      ),
    ));

void main() {
  group('★★ 並び（§3-6 の絵）★★', () {
    test('★★ 11 個である（★§3-6 が 11 と書いている）★★', () {
      expect(kCardFilterAxes, hasLength(11));
    });

    test('★★ 列挙の値を★1 つ残らず並べている（★落とさない）★★', () {
      expect(kCardFilterAxes.toSet(), CardFilterAxis.values.toSet());
      expect(kCardFilterAxes.toSet(), hasLength(kCardFilterAxes.length));
    });

    test('★★ 先頭はキーワード / 末尾は商品（§3-6 の左右）★★', () {
      expect(kCardFilterAxes.first, CardFilterAxis.keyword);
      expect(kCardFilterAxes.last, CardFilterAxis.expansion);
    });

    test('★★ 宣言の順は★並びではない（★意図してずらしてある）★★', () {
      // ★★ 揃えると「どちらを読んでいるか」が★出る値に 1 ビットも現れない ★★
      //   ★**2026-09-04 に測った** —— ★★揃っていたとき、
      //   ★画面が `CardFilterAxis.values` を回しても★★0 件だった★★（**D-27**）。
      expect(kCardFilterAxes, isNot(CardFilterAxis.values.toList()));
    });

    test('★★ 字面は §3-6 の 11 個である（★ここだけ書き写す）★★', () {
      // ★★ 字面の正は §3-6 の絵である。★1 か所で突き合わせる ★★
      //   ★**他の試験は [cardFilterAxisLabel] を読む**（★★2 か所に写さない★★ / **D-15** の規約 3）。
      expect(kCardFilterAxes.map(cardFilterAxisLabel).toList(), <String>[
        'キーワード',
        '登場作品',
        'ユニット',
        'コスト',
        'パラレル',
        'ブレードハート',
        'ブレード',
        'スコア',
        '所持ハート',
        '必要ハート',
        '商品',
      ]);
    });

    testWidgets('★★ 並びは [kCardFilterAxes] のとおりに出る ★★', (tester) async {
      await _pump(tester, tapped: <CardFilterAxis>[]);
      final keys = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .map((c) => (c.key! as ValueKey<String>).value)
          .toList();
      expect(keys,
          kCardFilterAxes.map((a) => 'cardFilterChip:${a.name}').toList());
    });
  });

  group('★★ 立っているか（★導く / ★自分で持たない）★★', () {
    test('★★ 何も指定していなければ★1 つも立たない ★★', () {
      for (final axis in kCardFilterAxes) {
        expect(cardFilterAxisIsSet(axis, const CardListFilter(), ''), isFalse,
            reason: '★${cardFilterAxisLabel(axis)} が立っている');
      }
    });

    test('★★ キーワードは★検索語で立つ（★絞り込みではない）★★', () {
      const filter = CardListFilter();
      expect(cardFilterAxisIsSet(CardFilterAxis.keyword, filter, '花帆'), isTrue);
      // ★空白だけでは立たない（★★検索していない★★）
      expect(cardFilterAxisIsSet(CardFilterAxis.keyword, filter, '   '), isFalse);
      // ★対: ★検索語は★他の軸を 1 つも立てない
      for (final axis in kCardFilterAxes) {
        if (axis == CardFilterAxis.keyword) continue;
        expect(cardFilterAxisIsSet(axis, filter, '花帆'), isFalse);
      }
    });

    test('★★ パラレルは「出さない」ときだけ立つ（★既定は出す）★★', () {
      expect(
          cardFilterAxisIsSet(
              CardFilterAxis.parallel, const CardListFilter(), ''),
          isFalse);
      expect(
          cardFilterAxisIsSet(CardFilterAxis.parallel,
              const CardListFilter(showParallel: false), ''),
          isTrue);
    });

    test('★★ 10 個の軸は★1 つずつ立つ（★他は立たない）★★', () {
      const on = (min: 1, max: null);
      final cases = <CardFilterAxis, CardListFilter>{
        CardFilterAxis.groupName: const CardListFilter(groupName: 'Liella!'),
        CardFilterAxis.unitName: const CardListFilter(unitName: 'u'),
        CardFilterAxis.cost: const CardListFilter(maxCost: 2),
        CardFilterAxis.parallel: const CardListFilter(showParallel: false),
        CardFilterAxis.bladeHeart:
            const CardListFilter(bladeHearts: {HeartColor.red: on}),
        CardFilterAxis.blade: const CardListFilter(blade: on),
        CardFilterAxis.score: const CardListFilter(score: on),
        CardFilterAxis.heart: const CardListFilter(heartTotal: on),
        CardFilterAxis.requiredHeart:
            const CardListFilter(requiredHeartTotal: on),
        CardFilterAxis.expansion: const CardListFilter(expansion: 'BP01'),
      };
      expect(cases, hasLength(10));
      cases.forEach((axis, filter) {
        for (final other in kCardFilterAxes) {
          expect(cardFilterAxisIsSet(other, filter, ''), other == axis,
              reason: '★${cardFilterAxisLabel(axis)} を立てたら '
                  '${cardFilterAxisLabel(other)} が ${other == axis ? "立たない" : "立った"}');
        }
      });
    });

    test('★★ ハートは★合計でも★色でも立つ ★★', () {
      const byColor = CardListFilter(hearts: {HeartColor.pink: (min: 1, max: null)});
      expect(cardFilterAxisIsSet(CardFilterAxis.heart, byColor, ''), isTrue);
      const byTotal = CardListFilter(heartTotal: (min: 1, max: null));
      expect(cardFilterAxisIsSet(CardFilterAxis.heart, byTotal, ''), isTrue);
    });

    testWidgets('★★ 立っている軸だけ★選択状態になる ★★', (tester) async {
      await _pump(tester,
          filter: const CardListFilter(expansion: 'BP01'),
          tapped: <CardFilterAxis>[]);
      final selected = tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .where((c) => c.selected)
          .length;
      expect(selected, 1);
      final chip = tester.widget<FilterChip>(
          find.byKey(const ValueKey('cardFilterChip:expansion')));
      expect(chip.selected, isTrue);
    });
  });

  group('★★ 押すと★呼ぶ側へ渡すだけ ★★', () {
    testWidgets('★ 押した軸が渡る', (tester) async {
      final tapped = <CardFilterAxis>[];
      await _pump(tester, tapped: tapped);
      await tester
          .tap(find.byKey(const ValueKey('cardFilterChip:groupName')));
      await tester.pump();
      expect(tapped, <CardFilterAxis>[CardFilterAxis.groupName]);
    });

    testWidgets('★★ 押しても★この層は選択状態を変えない ★★', (tester) async {
      final tapped = <CardFilterAxis>[];
      await _pump(tester, tapped: tapped);
      await tester.tap(find.byKey(const ValueKey('cardFilterChip:cost')));
      await tester.pump();
      final chip = tester
          .widget<FilterChip>(find.byKey(const ValueKey('cardFilterChip:cost')));
      expect(chip.selected, isFalse,
          reason: '★状態を自分で持つと★★2 か所になる★★');
    });

    testWidgets('★★ 立っている軸を押しても★渡すだけ（★外さない）★★', (tester) async {
      final tapped = <CardFilterAxis>[];
      await _pump(tester,
          filter: const CardListFilter(expansion: 'BP01'), tapped: tapped);
      // ★★ 11 個は 800 論理px に入らない。★横へ送ってから押す ★★
      //   ★**帯は横スクロールである**（★§3-6 の絵）。★★入る個数は測っていない★★（**D-28**）。
      final target = find.byKey(const ValueKey('cardFilterChip:expansion'));
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.pump();
      expect(tapped, <CardFilterAxis>[CardFilterAxis.expansion]);
      final chip = tester.widget<FilterChip>(
          find.byKey(const ValueKey('cardFilterChip:expansion')));
      expect(chip.selected, isTrue);
    });
  });

  group('★★ 覆わないもの（★対で固定する）★★', () {
    testWidgets('★★ この層は★件数を 1 つも出さない（§3-15 が出す）★★', (tester) async {
      await _pump(tester, tapped: <CardFilterAxis>[]);
      expect(find.textContaining('件'), findsNothing);
    });

    testWidgets('★★ この層は★フォームを 1 つも開かない ★★', (tester) async {
      final tapped = <CardFilterAxis>[];
      await _pump(tester, tapped: tapped);
      final before = tester.widgetList(find.byType(Text)).length;
      await tester.tap(find.byKey(const ValueKey('cardFilterChip:blade')));
      await tester.pumpAndSettle();
      expect(tester.widgetList(find.byType(Text)).length, before,
          reason: '★押したら★★画面の字面が増えた ＝ 何かを開いている★★');
    });
  });
}
