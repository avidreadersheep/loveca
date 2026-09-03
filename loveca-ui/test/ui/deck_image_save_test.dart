/// ★★ **W-84** の 1 —— ★出した画像を★Android の標準機能で保存 / コピーできるか ★★
/// （`docs/Android UI 決定.md` §8 の 1 / §3-12 の「保存 / コピー」）
///
/// ★★ 直していない。★測っただけである ★★
/// ★**§3-12 は「★★Android 固有の機能に任せられるかを確かめる★★」と書いており、★どうするかを 1 文字も決めていない。**
/// → ★**この群は★★いまの挙動を固定する★★。★手当てを入れると落ちる。★それが合図である**（★先例は **D-24** / **W-24** / **W-25**）。
///
/// ## ★★ 何を測るか（★層を分ける / §7-10）★★
///
/// | # | 何 | ★層 |
/// |---|---|---|
/// | ★**1** | ★★**画像を長押しして★何かが出るか**★★ | ★**Flutter の widget**（★測れる） |
/// | ★**2** | ★**アプリに★画像を保存 / 共有する経路が在るか** | ★**このリポジトリのソース**（★測れる） |
/// | ★**3** | ★実機の OS がこの画面に何をするか | ★★**測っていない**★★（★下） |
///
/// ## ★★ 答え —— ★★できない★★ ★★
/// ★**長押ししても★★画面の字面が 1 つも増えない★★**（★下の群が実測する / 2026-09-03）。
/// ★**`RepaintBoundary` も `toImage` も★`lib` に 1 つも無い**ので、★★画像そのものが 1 バイトも作られない★★。
/// → ★**§3-12 の「保存 / コピー」は、★★依存を足すか、★プラットフォームの口を書くかしないと成立しない★★。**
/// ★★**どちらを採るかは★この群では決めない**★★（★§3-13 が「依存を 1 つ増やす」を★★懸念として挙げている★★）。
///
/// ## ★★ この測定が覆わないもの（★言い切る）★★
/// ★**1) 実機**。★★ウィジェット試験は Android を 1 バイトも走らせない★★
///   （★先例は `touch_tooltip_test.dart` —— ★★指の速度・面積は **W-26** の相手である★★）。
/// ★**2) スクリーンショット**。★★端末はいつでも画面を撮れる★★が、
///   ★それは★★画面の写しであって★カードの画像の保存ではない★★（★§3-12 が求めているのは後者）。
/// ★**3) 「依存を足せばできるか」**。★★足して測っていない★★（**D-28**）。
///
/// ## ★★ 陽性対照が要る理由（**D-10**）★★
/// ★**「何も出ない」は★★『出ない』と『見えていない』の区別がつかない★★**。
/// → ★**同じ道具立て（`tester.longPress` ＋ `pumpAndSettle`）で★★出るもの★★を先に見る。**
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/ui/deck/deck_image_sheet.dart';

import '../support/fake_deck_repository.dart';
import '../support/recording_image_source.dart';
import '../support/strip_comments.dart';

const _member = DeckEntry(printingId: 'M-1-N', count: 4);
const _live = DeckEntry(printingId: 'L-1-N', count: 2);

CardListRow? _rowOf(String printingId) {
  for (final row in fakeRows) {
    if (row.printingId == printingId) return row;
  }
  return null;
}

Widget _sheet() => MaterialApp(
      home: Scaffold(
        body: DeckImageSheet(
          deckName: 'テストデッキ',
          sections: const DeckSections(
            members: [_member],
            lives: [_live],
            energies: [],
            unknown: [],
          ),
          imageSource: RecordingImageSource(),
          rowOf: _rowOf,
        ),
      ),
    );

/// ★いま画面に出ている字面。★★「増えたか」を見る唯一の観測点★★。
List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .toList()
  ..sort();

void main() {
  group('★★ 陽性対照 —— ★長押しで出るものは、★この道具立てで見える（**D-10**）★★', () {
    testWidgets('★★ `Tooltip` は長押しで出る（★同じ `longPress` / `pumpAndSettle`）★★',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Tooltip(
                message: '★長押しで出る字面',
                child: SizedBox(
                  key: ValueKey('陽性対照の的'),
                  width: 80,
                  height: 80,
                  child: ColoredBox(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = _texts(tester);
      await tester.longPress(find.byKey(const ValueKey('陽性対照の的')));
      await tester.pumpAndSettle();
      final after = _texts(tester);

      // ★★ 字面が 1 つ増える —— ★観測点そのものが働いている ★★
      expect(after.length, before.length + 1);
      expect(find.text('★長押しで出る字面'), findsOneWidget);
    });
  });

  group('★★ 測定 —— ★画像を長押ししても何も出ない（**W-84** の 1）★★', () {
    testWidgets('★★ 長押ししても★画面の字面が 1 つも増えない ★★', (tester) async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();

      final before = _texts(tester);
      await tester.longPress(find.byKey(const ValueKey('deckImageBlock:member')));
      await tester.pumpAndSettle();

      expect(_texts(tester), before);
    });

    testWidgets('★★ 叩いても★画面の字面が 1 つも増えない（★対）★★', (tester) async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();

      final before = _texts(tester);
      await tester.tap(find.byKey(const ValueKey('deckImageBlock:member')));
      await tester.pumpAndSettle();

      expect(_texts(tester), before);
    });

    testWidgets('★★ 面そのものが `Tooltip` を 1 つも持たない ★★', (tester) async {
      await tester.pumpWidget(_sheet());
      await tester.pumpAndSettle();

      // ★★ 上の陽性対照が「出る」ことを示しているので、★この 0 件は「無い」である ★★
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  group('★★ 測定 —— ★アプリに★画像を保存 / 共有する経路が 1 本も無い ★★', () {
    test('★★ `lib` に `RepaintBoundary` も `toImage` も無い（★コメントを外して見る / **D-30**）★★',
        () {
      final hits = _hitsIn('../loveca-ui/lib', RegExp(r'RepaintBoundary|toImage'));
      expect(hits, isEmpty, reason: '当たった: $hits');
    });

    test('★★ 陽性対照: ★コメントを外さなければ★この doc 自身が当たる（**D-30**）★★', () {
      // ★このファイル（★`lib` ではない）ではなく、★`deck_image_sheet.dart` の doc が持つ。
      final raw = File('lib/src/ui/deck/deck_image_sheet.dart').readAsStringSync();
      expect(RegExp(r'RepaintBoundary').hasMatch(raw), isTrue);
      expect(RegExp(r'RepaintBoundary').hasMatch(stripComments(raw)), isFalse);
    });

    test('★★ 画像をクリップボードへ渡す口が無い ★★', () {
      // ★`Clipboard` は★★字面（テキスト）で 3 か所使われている★★ ——
      //   ★盤面の seed / ★共有形式の書き出し / ★共有形式の取り込み。
      // ★**画像を渡す口は `ClipboardData` に無い**（★Flutter は画像のクリップボードを持たない）。
      // → ★**見るのは「`Clipboard` が 0 件」ではなく「★★画像を作る口が 0 件★★」である**（★上の群）。
      final hits = _hitsIn('../loveca-ui/lib', RegExp(r'Clipboard'));
      expect(hits.keys.toList()..sort(), [
        'board_page.dart',
        'deck_share_export_dialog.dart',
        'deck_share_import_dialog.dart',
      ]);
    });

    test('★★ 共有 / 保存のプラットフォームの口を 1 つも持たない ★★', () {
      expect(
        _hitsIn('../loveca-ui/lib', RegExp(r'MethodChannel|share_plus|SharePlus')),
        isEmpty,
      );
      // ★★ 陽性対照: ★同じ走査が★当たる字面では当たる ★★
      expect(_hitsIn('../loveca-ui/lib', RegExp(r'MaterialApp')), isNotEmpty);
    });
  });
}

/// ★コメントを外してから走査する（**D-30** —— ★禁止を説明した doc が同じ字面を必ず含む）。
Map<String, int> _hitsIn(String root, RegExp pattern) {
  final hits = <String, int>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final count =
        pattern.allMatches(stripComments(entity.readAsStringSync())).length;
    if (count > 0) hits[entity.path.split(RegExp(r'[/\\]')).last] = count;
  }
  return hits;
}
