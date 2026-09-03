/// ★★ Android のカード検索の一覧の 1 行（`docs/Android UI 決定.md` §3-2 / §3-3）★★
///
/// ★★ 呼ぶ側が 1 つも無い（**D-20** を承知で置いた）★★
/// ★**Android の縦リストそのものが★1 行も無い**（★走査した / 2026-09-03）。
/// ★★**いつ呼ばれる予定か**★★ —— ★**§3-3 の縦の積み方（★件数 / 並び順 → 縦リスト → カテゴリタブ →
/// 絞り込みチップ → 3 本のカウンタ → 下段タブ）が入ったとき**である。
///
/// ★★ §12 の実測が★形を 3 か所直した。★その 3 つを対で固定する ★★
/// ★**1** ★メンバーの所持ハートは★★最大 4 色★★（**W-75**）—— ★数を決め打ちしない。
/// ★**2** ★ライブの必要ハートは★★最大 7 色★★（**W-76**）—— ★同上。
/// ★**3** ★メンバーの DRAW / SCORE は★★実データに 0 種★★（**W-77**）——
///   ★★**出さないのではない。★データが 1 件も無いだけである**★★（★下の群が★合成の入力で確かめる）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_core/loveca_core.dart' as core show Card;
import 'package:loveca_ui/src/ui/browse/card_list_tile.dart';

import '../support/recording_image_source.dart';

core.Card _member({
  int? cost = 3,
  int? bladeCount = 2,
  Map<HeartColor, int> hearts = const {HeartColor.pink: 1},
  Map<HeartColor, int> bladeHearts = const {},
  Map<BladeHeartEffect, int> effects = const {},
  List<String> groupNames = const ['作品A'],
  List<String> unitNames = const ['ユニットA'],
}) =>
    core.Card(
      cardNumber: 'M-1',
      name: 'メンバー1',
      cardType: CardType.member,
      groupNames: groupNames,
      unitNames: unitNames,
      cost: cost,
      bladeCount: bladeCount,
      hearts: hearts,
      bladeHearts: bladeHearts,
      bladeHeartEffects: effects,
    );

core.Card _live({
  int? score = 2,
  Map<HeartColor, int> requiredHearts = const {HeartColor.blue: 2},
  Map<BladeHeartEffect, int> effects = const {},
}) =>
    core.Card(
      cardNumber: 'L-1',
      name: 'ライブ1',
      cardType: CardType.live,
      groupNames: const ['作品A'],
      score: score,
      requiredHearts: requiredHearts,
      bladeHeartEffects: effects,
    );

core.Card _energy({
  Map<HeartColor, int> bladeHearts = const {},
  Map<BladeHeartEffect, int> effects = const {},
}) =>
    core.Card(
      cardNumber: 'E-1',
      name: 'エネルギー1',
      cardType: CardType.energy,
      // ★★ わざと持たせる —— ★「持っていないから空」ではないことを見る ★★
      groupNames: const ['作品A'],
      unitNames: const ['ユニットA'],
      cost: 9,
      bladeCount: 9,
      score: 9,
      hearts: const {HeartColor.red: 3},
      bladeHearts: bladeHearts,
      bladeHeartEffects: effects,
    );

const _printing = Printing(
  printingId: 'X-1-N',
  cardNumber: 'X-1',
  expansion: 'bp1',
  rarity: 'N',
  isParallel: false,
);

Widget _tile(core.Card card) => MaterialApp(
      home: Scaffold(
        body: CardListTile(
          card: card,
          printing: _printing,
          imageSource: RecordingImageSource(),
        ),
      ),
    );

void main() {
  group('★★ 絵に重ねるもの（§3-2 の「絵の左上」と「その下」）★★', () {
    test('★ メンバー = コスト / ライブ = スコア', () {
      expect(cardArtOverlayOf(_member(cost: 7)).corner, 7);
      expect(cardArtOverlayOf(_live(score: 4)).corner, 4);
    });

    test('★★ エネルギーには 1 つも重ねない（★持っていても出さない）★★', () {
      final overlay = cardArtOverlayOf(_energy(
        bladeHearts: const {HeartColor.pink: 1},
        effects: const {BladeHeartEffect.draw: 1},
      ));
      expect(overlay.corner, isNull);
      expect(overlay.bladeHearts, isEmpty);
      expect(overlay.effects, isEmpty);
    });

    test('★★ メンバーも★色付きブレードハートを持つ（**W-77** —— ★55.6 %）★★', () {
      final overlay =
          cardArtOverlayOf(_member(bladeHearts: const {HeartColor.red: 1}));
      expect(overlay.bladeHearts, {HeartColor.red: 1});
    });
  });

  group('★★ 1 行目（作品名, ユニット）★★', () {
    test('★ 作品名とユニットを並べる', () {
      expect(cardSubtitleOf(_member()), '作品A, ユニットA');
    });

    test('★★ エネルギーは出さない（§3-2 —— ★右はカード名だけ）★★', () {
      expect(cardSubtitleOf(_energy()), isNull);
    });

    test('★ どちらも無ければ null', () {
      expect(
        cardSubtitleOf(_member(groupNames: const [], unitNames: const [])),
        isNull,
      );
    });
  });

  group('★★ 画面 —— ★メンバー ★★', () {
    testWidgets('★ 名前 / 作品名 / ブレード / ハート を出す', (tester) async {
      await tester.pumpWidget(_tile(_member()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cardListTile:name')), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:subtitle')), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:blade')), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:hearts')), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:corner')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('★★ 所持ハートは 4 色まで並ぶ（**W-75** —— ★数を決め打ちしない）★★',
        (tester) async {
      await tester.pumpWidget(_tile(_member(hearts: const {
        HeartColor.purple: 1,
        HeartColor.pink: 2,
        HeartColor.green: 1,
        HeartColor.blue: 3,
      })));
      await tester.pumpAndSettle();

      for (final label in ['桃2', '緑1', '青3', '紫1']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('★★ 並びは `heartDisplayOrder` である（★Map の順ではない）★★',
        (tester) async {
      await tester.pumpWidget(_tile(_member(hearts: const {
        // ★★ わざと逆順に入れる ★★
        HeartColor.purple: 1,
        HeartColor.pink: 1,
      })));
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.descendant(
            of: find.byKey(const ValueKey('cardListTile:hearts')),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();
      expect(texts, ['桃1', '紫1']);
    });

    testWidgets('★★ 色付きブレードハートを★絵に重ねる（**W-77** —— ★★画面の側の対★★）★★',
        (tester) async {
      // ★★ ここが (K) の受けである（**D-27** の (a) 対の形）★★
      //   ★純粋関数の対だけでは★★重ねているかを 1 つも見ていなかった★★（★実測 0 件 / 2026-09-03）。
      await tester
          .pumpWidget(_tile(_member(bladeHearts: const {HeartColor.red: 1})));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cardListTile:bladeHeart:red')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cardListTile:bladeHeart:blue')),
        findsNothing,
      );
    });

    testWidgets('★★ 対: ★メンバーが必要ハートを持っていても★出さない ★★', (tester) async {
      // ★★ ここが (H) の受けである（**D-27** の (a) 対の形）★★
      //   ★他の対はメンバーに `requiredHearts` を 1 つも入れておらず、
      //   ★★種別の判定を外しても★描くものが無かった★★（★実測 0 件 / 2026-09-03）。
      //   ★実データのメンバーは持たない（`CLAUDE.md` §5-(1)）が、★★形で守る★★。
      await tester.pumpWidget(_tile(core.Card(
        cardNumber: 'M-9',
        name: 'メンバー9',
        cardType: CardType.member,
        cost: 1,
        requiredHearts: const {HeartColor.gray: 5},
      )));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('cardListTile:requiredHearts')),
        findsNothing,
      );
      expect(find.text('必要ハート'), findsNothing);
    });

    testWidgets('★★ ドロー / スコアは★出さないのではない —— ★データが 0 種なだけである ★★',
        (tester) async {
      // ★★ 合成の入力（**W-77** —— ★実データのメンバーは 0 種）★★
      await tester.pumpWidget(
        _tile(_member(effects: const {BladeHeartEffect.draw: 1})),
      );
      await tester.pumpAndSettle();

      expect(find.text('ドロー'), findsOneWidget);
    });
  });

  group('★★ 画面 —— ★ライブ ★★', () {
    testWidgets('★ スコアと必要ハートを出す（★ブレードは出さない）', (tester) async {
      await tester.pumpWidget(_tile(_live()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cardListTile:corner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cardListTile:requiredHearts')),
        findsOneWidget,
      );
      expect(find.text('必要ハート'), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:blade')), findsNothing);
      expect(find.byKey(const ValueKey('cardListTile:hearts')), findsNothing);
    });

    testWidgets('★★ 必要ハートは 7 色まで並ぶ（**W-76**）★★', (tester) async {
      await tester.pumpWidget(_tile(_live(requiredHearts: const {
        HeartColor.pink: 1,
        HeartColor.red: 1,
        HeartColor.yellow: 1,
        HeartColor.green: 1,
        HeartColor.blue: 1,
        HeartColor.purple: 1,
        HeartColor.gray: 12,
      })));
      await tester.pumpAndSettle();

      for (final label in ['桃1', '赤1', '黄1', '緑1', '青1', '紫1', '無12']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('★★ 画面 —— ★エネルギーは★カード名だけ（§3-2）★★', () {
    testWidgets('★★ 重ねるものも★右の 1〜3 行目も 1 つも出ない ★★', (tester) async {
      await tester.pumpWidget(_tile(_energy(
        bladeHearts: const {HeartColor.pink: 1},
        effects: const {BladeHeartEffect.score: 1},
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cardListTile:name')), findsOneWidget);
      expect(find.byKey(const ValueKey('cardListTile:corner')), findsNothing);
      expect(find.byKey(const ValueKey('cardListTile:subtitle')), findsNothing);
      expect(find.byKey(const ValueKey('cardListTile:blade')), findsNothing);
      expect(find.byKey(const ValueKey('cardListTile:hearts')), findsNothing);
      expect(
        find.byKey(const ValueKey('cardListTile:requiredHearts')),
        findsNothing,
      );
      expect(find.text('ドロー'), findsNothing);
      expect(find.text('スコア'), findsNothing);
    });
  });

  group('★★ 作品名は 1 行のまま切る（§3-2 —— ★折り返さない）★★', () {
    testWidgets('★★ `maxLines` は 1 で `ellipsis` である ★★', (tester) async {
      await tester.pumpWidget(_tile(_member(
        groupNames: const ['とても長い作品名がここに入る', 'もう 1 つの作品名'],
        unitNames: const ['ユニットの名前'],
      )));
      await tester.pumpAndSettle();

      final text = tester
          .widget<Text>(find.byKey(const ValueKey('cardListTile:subtitle')));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('★ カード名も 1 行で切る', (tester) async {
      await tester.pumpWidget(_tile(_member()));
      await tester.pumpAndSettle();

      final text =
          tester.widget<Text>(find.byKey(const ValueKey('cardListTile:name')));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
