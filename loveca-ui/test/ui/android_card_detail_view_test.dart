/// カード詳細（★Android / `docs/Android UI 決定.md` §3-14 / §29）.
///
/// ★★ 何を固定するか ★★
/// ★**属性の行が★★種別で変わる★★こと**（★エネルギーは★★数値の欄ごと消える★★）／
/// ★**「3 / 25」が★★1 始まりで出る★★こと** ／ ★**左右スワイプが★呼ぶ側へ渡ること** ／
/// ★**テキストが折り畳めること** ／ ★**帯は★★渡されたときだけ出る★★こと**。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_core/loveca_core.dart' as core show Card;
import 'package:loveca_ui/src/ui/android/android_card_detail_view.dart';

core.Card _card({
  CardType cardType = CardType.member,
  String name = '日野下花帆',
  // ★★ キャラクター名を★必ず持たせる ★★
  //   ★**2026-09-04 に測った** —— ★★空にしていたので、
  //   ★特徴にキャラクター名を混ぜても★★0 件だった★★（**D-27** の (a)）。
  List<String> characterNames = const ['日野下花帆'],
  List<String> groupNames = const ['蓮ノ空'],
  List<String> unitNames = const ['スリーゼ'],
  String effectText = '【登場】あなたは…',
  int? cost = 3,
  int? bladeCount = 2,
  int? score,
  Map<HeartColor, int> hearts = const {HeartColor.pink: 2},
  Map<HeartColor, int> requiredHearts = const {},
}) =>
    core.Card(
      cardNumber: 'LL-bp1-001',
      name: name,
      cardType: cardType,
      characterNames: characterNames,
      groupNames: groupNames,
      unitNames: unitNames,
      effectText: effectText,
      cost: cost,
      bladeCount: bladeCount,
      score: score,
      hearts: hearts,
      requiredHearts: requiredHearts,
    );

Printing _printing({String id = 'LL-bp1-001-R', String rarity = 'R'}) => Printing(
      printingId: id,
      cardNumber: 'LL-bp1-001',
      expansion: 'BP01',
      rarity: rarity,
      isParallel: false,
      imageHash: '',
    );

Future<void> _pump(
  WidgetTester tester, {
  core.Card? card,
  int index = 2,
  int total = 25,
  List<Printing> otherPrintings = const <Printing>[],
  int? copies,
  int? maxCopies,
  Widget? countBand,
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  VoidCallback? onCopyInfo,
  ValueChanged<Printing>? onSelectPrinting,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AndroidCardDetailView(
          card: card ?? _card(),
          printing: _printing(),
          index: index,
          total: total,
          otherPrintings: otherPrintings,
          copies: copies,
          maxCopies: maxCopies,
          countBand: countBand,
          onPrevious: onPrevious,
          onNext: onNext,
          onCopyInfo: onCopyInfo,
          onSelectPrinting: onSelectPrinting,
        ),
      ),
    ));

void main() {
  group('★★ 属性の行は★種別で変わる（§3-14）★★', () {
    test('★ メンバーは★コスト / ブレード / ハートを持つ', () {
      expect(cardAttributeLabels(_card()),
          <String>['レアリティ', '種別', 'コスト', 'ブレード', 'ハート']);
    });

    test('★ ライブは★スコア / 必要ハートを持つ', () {
      expect(cardAttributeLabels(_card(cardType: CardType.live)),
          <String>['レアリティ', '種別', 'スコア', '必要ハート']);
    });

    test('★★ エネルギーは★数値の欄ごと消える（★空欄にしない）★★', () {
      expect(cardAttributeLabels(_card(cardType: CardType.energy)),
          <String>['レアリティ', '種別']);
    });

    testWidgets('★★ エネルギーでは★コストの行が★1 つも出ない ★★', (tester) async {
      await _pump(tester, card: _card(cardType: CardType.energy));
      expect(find.byKey(const ValueKey('cardDetailAttr:コスト')), findsNothing);
      // ★対: ★メンバーなら出る（★★「何も出ない」と区別できる形★★）
      await _pump(tester);
      expect(find.byKey(const ValueKey('cardDetailAttr:コスト')), findsOneWidget);
    });

    testWidgets('★★ レアリティは★刷りから引く（★カードからではない）★★', (tester) async {
      // ★★ レアリティは★刷りの単位である（`CLAUDE.md` §5-(4)）★★
      //   ★**2026-09-04 に測った** —— ★★値を見る対が 1 つも無かった★★（**D-27** の (乙)）。
      await _pump(tester);
      final row = find.byKey(const ValueKey('cardDetailAttr:レアリティ'));
      expect(
          tester
              .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
              .map((t) => t.data),
          containsAll(<String>['レアリティ', 'R']));
    });

    test('★ 種別の字面（総合ルール 2.2.2）', () {
      expect(cardTypeLabel(CardType.member), 'メンバー');
      expect(cardTypeLabel(CardType.live), 'ライブ');
      expect(cardTypeLabel(CardType.energy), 'エネルギー');
    });
  });

  group('★★ 位置（「3 / 25」）★★', () {
    test('★★ 1 始まりで出す（★人が読む数である）★★', () {
      expect(cardPositionLabel(2, 25), '3 / 25');
      expect(cardPositionLabel(0, 1), '1 / 1');
    });

    testWidgets('★ 画面に出る', (tester) async {
      await _pump(tester, index: 2, total: 25);
      expect(
          (tester.widget<Text>(find.byKey(const ValueKey('cardDetailPosition'))))
              .data,
          '3 / 25');
    });
  });

  group('★★ 左右スワイプで隣のカードへ（§3-14）★★', () {
    testWidgets('★ 左へ払うと★次へ', (tester) async {
      var next = 0;
      var prev = 0;
      await _pump(tester, onNext: () => next++, onPrevious: () => prev++);
      await tester.fling(
          find.byKey(const ValueKey('cardDetailPosition')), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(next, 1);
      expect(prev, 0);
    });

    testWidgets('★ 右へ払うと★前へ', (tester) async {
      var next = 0;
      var prev = 0;
      await _pump(tester, onNext: () => next++, onPrevious: () => prev++);
      await tester.fling(
          find.byKey(const ValueKey('cardDetailPosition')), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(prev, 1);
      expect(next, 0);
    });
  });

  group('★★ テキストは折り畳める（§3-14 の ▼）★★', () {
    testWidgets('★★ 既定は開いている（★決めた既定値）★★', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('cardDetailText')), findsOneWidget);
    });

    testWidgets('★ 押すと閉じ、もう一度押すと開く', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('cardDetailTextToggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('cardDetailText')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cardDetailTextToggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('cardDetailText')), findsOneWidget);
    });
  });

  group('★★ 「特徴」の位置はグループ名とユニット（★条文 2.12.2）★★', () {
    testWidgets('★ 2 つとも出る', (tester) async {
      await _pump(tester);
      expect(
          (tester.widget<Text>(find.byKey(const ValueKey('cardDetailFeature'))))
              .data,
          '蓮ノ空 / スリーゼ');
    });

    testWidgets('★★ キャラクター名は入れない（★2.3.2.2 は別の参照である）★★',
        (tester) async {
      await _pump(tester,
          card: _card(groupNames: const [], unitNames: const []));
      expect(
          (tester.widget<Text>(find.byKey(const ValueKey('cardDetailFeature'))))
              .data,
          '');
    });
  });

  group('★★ 枚数（★デッキ編集から入ったときだけ）★★', () {
    testWidgets('★★ 渡さなければ出さない ★★', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('cardDetailCopies')), findsNothing);
    });

    testWidgets('★★ 4 枚に達したら赤字（総合ルール 6.1.1.2）★★', (tester) async {
      await _pump(tester, copies: 4, maxCopies: 4);
      final text =
          tester.widget<Text>(find.byKey(const ValueKey('cardDetailCopies')));
      expect(text.data, 'x4');
      expect(text.style?.color, const Color(0xFFD32F2F));
    });

    testWidgets('★ 対: ★達していなければ赤字にしない', (tester) async {
      await _pump(tester, copies: 3, maxCopies: 4);
      final text =
          tester.widget<Text>(find.byKey(const ValueKey('cardDetailCopies')));
      expect(text.style?.color, isNull);
    });
  });

  group('★★ 差し込み口（★この層は中身を決めない）★★', () {
    testWidgets('★★ 帯は★渡されたときだけ出る ★★', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('bandSlot')), findsNothing);
      await _pump(tester,
          countBand: const SizedBox(key: ValueKey('bandSlot'), height: 8));
      expect(find.byKey(const ValueKey('bandSlot')), findsOneWidget);
    });

    testWidgets('★★ ほかの刷りは★空なら段ごと出さない ★★', (tester) async {
      await _pump(tester);
      expect(find.text('ほかの刷り'), findsNothing);
      await _pump(tester, otherPrintings: <Printing>[
        _printing(id: 'LL-bp1-001-P', rarity: 'P'),
      ]);
      expect(find.text('ほかの刷り'), findsOneWidget);
    });

    testWidgets('★ ほかの刷りを押すと★呼ぶ側へ渡る', (tester) async {
      final picked = <Printing>[];
      await _pump(tester,
          otherPrintings: <Printing>[
            _printing(id: 'LL-bp1-001-P', rarity: 'P'),
          ],
          onSelectPrinting: picked.add);
      await tester.tap(find
          .byKey(const ValueKey('cardDetailOtherPrinting:LL-bp1-001-P')));
      await tester.pump();
      expect(picked.map((p) => p.printingId), <String>['LL-bp1-001-P']);
    });

    testWidgets('★★ 長押しは★呼ぶ側へ渡すだけ（★この層は 1 文字もコピーしない）★★',
        (tester) async {
      var copied = 0;
      await _pump(tester, onCopyInfo: () => copied++);
      await tester.longPress(find.byKey(const ValueKey('cardDetailCopyHint')));
      await tester.pump();
      expect(copied, 1);
    });
  });
}
