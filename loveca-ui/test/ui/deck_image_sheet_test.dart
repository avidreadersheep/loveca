/// ★★ 画像出力の面（`docs/Android UI 決定.md` §3-12）★★
///
/// ★★ 呼ぶ側が 1 つも無い（**D-20** を承知で置いた）★★
/// ★**置いたのは★★**W-84** の 1 を測るためである★★**（★§8 の 1 —— ★★Android の標準機能で保存できるか★★）。
/// ★**測定そのものは `deck_image_save_test.dart`。★ここは★出すものの形を固定する。**
/// ★★**いつ呼ばれる予定か**★★ —— ★**§3-10 のデッキ詳細画面が入ったとき**（★そこが画像出力の口である）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/ui/browse/card_type_tabs.dart';
import 'package:loveca_ui/src/ui/deck/deck_image_sheet.dart';

import '../support/fake_deck_repository.dart';
import '../support/recording_image_source.dart';

DeckSections _sections({
  List<DeckEntry> members = const [],
  List<DeckEntry> lives = const [],
  List<DeckEntry> energies = const [],
  List<DeckEntry> unknown = const [],
}) =>
    DeckSections(
      members: members,
      lives: lives,
      energies: energies,
      unknown: unknown,
    );

CardListRow? _rowOf(String printingId) {
  for (final row in fakeRows) {
    if (row.printingId == printingId) return row;
  }
  return null;
}

Widget _sheet(DeckSections sections, {String name = 'テストデッキ'}) => MaterialApp(
      home: Scaffold(
        body: DeckImageSheet(
          deckName: name,
          sections: sections,
          imageSource: RecordingImageSource(),
          rowOf: _rowOf,
        ),
      ),
    );

const _member = DeckEntry(printingId: 'M-1-N', count: 4);
const _live = DeckEntry(printingId: 'L-1-N', count: 2);
const _energy = DeckEntry(printingId: 'E-1-N', count: 12);
const _unknown = DeckEntry(printingId: 'X-9-N', count: 1);

void main() {
  group('★★ 塊の並びと有無（§3-12 の「区切り」）★★', () {
    test('★★ 並びは★カテゴリタブの種別の並びと一致する（★★別の定数から導く★★）★★', () {
      // ★★ ここが (C) の受けである（**D-27** の (a) 対の形）★★
      //   ★下の群は `kDeckImageBlockOrder` を★★両側で読む★★ので、
      //   ★★定数を書き換えると期待も一緒に動き、★入れ替えを 1 件も見ない★★（★実測 0 件 / 2026-09-03）。
      //   → ★**独立の出どころと突き合わせる** —— ★`kCardTypeTabs`（`card_type_tabs.dart`）は
      //     ★★「すべて」＋ 3 種別の並びの正である★★。★§3-3 のカウンタの並びとも同じ。
      final fromTabs = [
        for (final (type, _) in kCardTypeTabs)
          if (type != null) type.name,
      ];
      expect(kDeckImageBlockOrder.take(fromTabs.length).toList(), fromTabs);
      // ★★ マスタに無い刷りは★最後である（★種別ではないので★タブには無い / D35）★★
      expect(kDeckImageBlockOrder.last, 'unknown');
      expect(kDeckImageBlockOrder.length, fromTabs.length + 1);
    });

    test('★ 出す順は `kDeckImageBlockOrder` に従う', () {
      final blocks = deckImageBlocksOf(_sections(
        members: [_member],
        lives: [_live],
        energies: [_energy],
        unknown: [_unknown],
      ));
      expect(blocks.map((b) => b.key).toList(), kDeckImageBlockOrder);
    });

    test('★★ エネルギー 0 枚なら★エネルギーの塊を出さない（§3-12）★★', () {
      final blocks = deckImageBlocksOf(
        _sections(members: [_member], lives: [_live]),
      );
      expect(blocks.map((b) => b.key), isNot(contains('energy')));
      expect(blocks.map((b) => b.key).toList(), ['member', 'live']);
    });

    test('★★ 対: ★エネルギーが 1 枚でも在れば出す ★★', () {
      final blocks = deckImageBlocksOf(
        _sections(members: [_member], energies: [DeckEntry(printingId: 'E-1-N', count: 1)]),
      );
      expect(blocks.map((b) => b.key), contains('energy'));
    });

    test('★★ 空の塊は★種別を問わず作らない（★§3-12 の帰結。★差し替え点はこの関数）★★', () {
      expect(deckImageBlocksOf(_sections()).isEmpty, isTrue);
      expect(
        deckImageBlocksOf(_sections(lives: [_live])).map((b) => b.key).toList(),
        ['live'],
      );
    });

    test('★★ マスタに無い刷りを黙って捨てない（決定 D35）★★', () {
      final blocks = deckImageBlocksOf(_sections(unknown: [_unknown]));
      expect(blocks.map((b) => b.key).toList(), ['unknown']);
    });
  });

  group('★★ 画面（★出すものと出さないもの）★★', () {
    testWidgets('★ デッキ名を出す（§3-12 の「中身」）', (tester) async {
      await tester.pumpWidget(_sheet(_sections(members: [_member])));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deckImageSheet:name')), findsOneWidget);
      expect(find.text('テストデッキ'), findsOneWidget);
    });

    testWidgets('★★ 枚数を各カードに出す（§3-12 の「枚数」）★★', (tester) async {
      await tester.pumpWidget(
        _sheet(_sections(members: [_member], lives: [_live])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deckImageCount:M-1-N')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('★★ エネルギー 0 枚なら★その塊の widget も出ない ★★', (tester) async {
      await tester.pumpWidget(
        _sheet(_sections(members: [_member], lives: [_live])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deckImageBlock:member')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckImageBlock:live')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckImageBlock:energy')), findsNothing);
    });

    testWidgets('★★ 対: ★エネルギーが在れば★その塊の widget が出る ★★', (tester) async {
      await tester.pumpWidget(
        _sheet(_sections(members: [_member], energies: [_energy])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deckImageBlock:energy')), findsOneWidget);
    });

    testWidgets('★★ 統計を入れない（§3-12 —— ★★カウンタの帯も棒グラフも出さない★★）★★',
        (tester) async {
      await tester.pumpWidget(
        _sheet(_sections(members: [_member], lives: [_live], energies: [_energy])),
      );
      await tester.pumpAndSettle();

      // ★`DeckCountersBand` の字面（`メンバー 4 / 48`）は 1 つも出ない。
      expect(find.textContaining('/ 48'), findsNothing);
      expect(find.textContaining('/ 12'), findsNothing);
    });

    testWidgets('★★ マスタに無い刷りも★画面に出る（★黙って消えない / D35）★★',
        (tester) async {
      await tester.pumpWidget(_sheet(_sections(unknown: [_unknown])));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('deckImageBlock:unknown')), findsOneWidget);
      expect(find.byKey(const ValueKey('deckImageCount:X-9-N')), findsOneWidget);
    });
  });
}
