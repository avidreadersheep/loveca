/// R3 デッキ編集（M4 / `docs/UI設計メモ.md` §2-4 / §9-1）.
///
/// ★★ ここで見るのは「画面の振る舞い」である ★★
/// `revision` の増え方そのものや、保存の往復・並び順が戻ること・
/// 4 枚制限の判定は**実 DB の `test/data/deck_repository_test.dart`** が固定している。
/// ここで確かめるのは
///
/// - 3 操作（一覧 → デッキ / デッキ内の並べ替え / デッキ → ゴミ箱）が繋がること
/// - ★**行の余白**を押しても掴めること（決定 D46 の再現）
/// - 画面が**編集のたびに保存していない**こと（`Deck.copyWith` を踏む回数）
/// - 「+」の活性が `DeckValidator` の答えどおりであること（決定 D28 / D55）
/// - 縮退が**起きたときだけ**出ること（決定 D65 / D35）
///
/// 役割を混ぜない。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_pane.dart';

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';

Deck _deck({
  String name = 'もとの名前',
  String memo = '',
  List<DeckEntry> entries = const [],
}) =>
    Deck(
      deckId: 'a',
      name: name,
      memo: memo,
      entries: entries,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

Finder _catalogCell(String printingId) =>
    find.byKey(ValueKey('catalogCell:$printingId'));
Finder _deckRow(String printingId) =>
    find.byKey(ValueKey('deckRow:$printingId'));

final _nameField = find.byKey(const Key('deckNameField'));
final _saveButton = find.widgetWithText(FilledButton, '保存');

/// 2 ペインで開く（一覧とデッキが同時に見える）。
Future<FakeDeckRepository> _open(
  WidgetTester tester, {
  required Deck deck,
  double width = 1400,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.reset);

  final decks = FakeDeckRepository(decks: [deck]);
  await pumpInAppScope(tester, DeckEditPage(deck: deck), decks: decks);
  return decks;
}

/// [from] から [to] へ引く。★掴む点は呼び出し側が決める（余白を押す試験のため）。
Future<void> _dragTo(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 行の**余白**（上端のすぐ内側）。★決定 D46 が踏んだ場所そのもの。
Offset _rowPadding(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return Offset(rect.center.dx, rect.top + 3);
}

void main() {
  group('★★ 3 操作が繋がる（M4 の主題）★★', () {
    testWidgets('① 一覧 → デッキ（ドラッグで 1 枚入る）', (tester) async {
      await _open(tester, deck: _deck());

      expect(find.text('カードがまだありません\n一覧から引っぱるか「+」で入れます'), findsOneWidget);

      await _dragTo(
        tester,
        tester.getCenter(_catalogCell('M-1-N')),
        tester.getCenter(find.byType(DeckPane)),
      );

      expect(_deckRow('M-1-N'), findsOneWidget);
      expect(find.text('メンバー 1 / 48'), findsOneWidget);
    });

    testWidgets('② デッキ内の並べ替え', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      // 開いた直後は正規化された並び（決定 D65）。
      expect(
        tester.getRect(_deckRow('M-1-N')).top,
        lessThan(tester.getRect(_deckRow('M-2-N')).top),
      );

      // M-2-N を M-1-N の**上半分**へ落とす（= 手前に差し込む / 決定 D47）。
      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      expect(
        tester.getRect(_deckRow('M-2-N')).top,
        lessThan(tester.getRect(_deckRow('M-1-N')).top),
      );
    });

    testWidgets('③ デッキ → ゴミ箱（行ごと外れる）', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 3)]),
      );
      expect(_deckRow('M-1-N'), findsOneWidget);

      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-1-N')),
        tester.getCenter(find.text('ここへ落とすとデッキから外す')),
      );

      expect(_deckRow('M-1-N'), findsNothing);
      expect(find.text('メンバー 0 / 48'), findsOneWidget);
    });
  });

  group('★★ 決定 D46: 行の余白を押しても掴める ★★', () {
    // ★対照実験（色を持たない素の Draggable では掴めないこと）は
    //   `test/common/card_drag_test.dart` が持っている。ここは本画面での再現。
    testWidgets('デッキ行の余白から並べ替えられる', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        // ★文字にも枚数ボタンにも当たらない、行の上端の余白。
        _rowPadding(tester, _deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      expect(
        tester.getRect(_deckRow('M-2-N')).top,
        lessThan(tester.getRect(_deckRow('M-1-N')).top),
      );
    });

    testWidgets('デッキ行の余白からゴミ箱へ持ち出せる', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 1)]),
      );

      await _dragTo(
        tester,
        _rowPadding(tester, _deckRow('M-1-N')),
        tester.getCenter(find.text('ここへ落とすとデッキから外す')),
      );

      expect(_deckRow('M-1-N'), findsNothing);
    });

    // ★★ ここから下は決定 D72（ライブは横長の枠になった）の受け ★★
    //   絵がタイルを埋めなくなったので、**帯を掴めるかどうかは
    //   外側の `CardDragSource` の `ColoredBox` だけが決めている。**
    //   ★Phase 3b の盤面でライブを掴む場面が必ず来る。ここで崩れていると後で踏む。
    testWidgets('★★ ライブのセルは帯（タイル上端）を掴んでもドラッグが始まる（決定 D72）★★',
        (tester) async {
      await _open(tester, deck: _deck());

      final cell = tester.getRect(_catalogCell('L-1-N'));
      final art = tester.getRect(
        find.descendant(
          of: _catalogCell('L-1-N'),
          matching: find.byType(CardThumb),
        ),
      );
      // ★掴む点が本当に「絵の外」であることを先に確かめる。
      //   ここが偽だと、このテストは**絵の上を掴んでいるだけ**になる。
      expect(art.top, greaterThan(cell.top + 4),
          reason: 'ライブのセルには上下に帯がある（決定 D72）');

      await _dragTo(
        tester,
        Offset(cell.center.dx, cell.top + 4),
        tester.getCenter(find.byType(DeckPane)),
      );

      expect(_deckRow('L-1-N'), findsOneWidget);
    });

    testWidgets('★対: メンバーのセルも同じ位置（タイル上端）で掴める', (tester) async {
      // ★メンバーには帯が無い（枠 == タイル）。**帯の有無に関係なく掴める**ことを示す。
      await _open(tester, deck: _deck());

      final cell = tester.getRect(_catalogCell('M-1-N'));
      await _dragTo(
        tester,
        Offset(cell.center.dx, cell.top + 4),
        tester.getCenter(find.byType(DeckPane)),
      );

      expect(_deckRow('M-1-N'), findsOneWidget);
    });

    testWidgets('★ライブのデッキ行も余白から持ち出せる（34×48 の箱も横長になった）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'L-1-N', count: 1)]),
      );

      await _dragTo(
        tester,
        _rowPadding(tester, _deckRow('L-1-N')),
        tester.getCenter(find.text('ここへ落とすとデッキから外す')),
      );

      expect(_deckRow('L-1-N'), findsNothing);
    });
  });

  group('★★ 増減では revision を跳ねさせない（§9-1）★★', () {
    testWidgets('★カードを増減しても保存は 0 回', (tester) async {
      final decks = await _open(tester, deck: _deck());

      await tester.tap(find.byTooltip('デッキに入れる').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('1 枚増やす').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('1 枚減らす').first);
      await tester.pumpAndSettle();

      // ★★ 3 回いじって保存は 0 回 ★★
      //   操作ごとに保存すると Phase 4 の同期で「大量に更新された」ように見える。
      expect(decks.saveCalls, 0);
      expect(find.text('未保存の変更があります'), findsOneWidget);
    });

    testWidgets('保存を押すとちょうど 1 回だけ保存され、中身が渡る', (tester) async {
      final decks = await _open(tester, deck: _deck());

      await tester.tap(find.byTooltip('デッキに入れる').first);
      await tester.pumpAndSettle();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 1);
      expect(decks.lastSaved!.entries.single.printingId, 'M-1-N');
      expect(find.text('保存しました'), findsOneWidget);
      expect(find.text('未保存の変更があります'), findsNothing);
    });

    testWidgets('★★ 編集しただけでは保存されない（名前）★★', (tester) async {
      final decks = await _open(tester, deck: _deck());

      await tester.enterText(_nameField, 'あ');
      await tester.enterText(_nameField, 'あい');
      await tester.enterText(_nameField, 'あいう');
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 0);
      expect(find.text('未保存の変更があります'), findsOneWidget);
    });

    testWidgets('★変更が無ければ保存ボタンを押させない', (tester) async {
      await _open(tester, deck: _deck());

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    });

    testWidgets('★名前を空にしたら保存させない', (tester) async {
      await _open(tester, deck: _deck());

      await tester.enterText(_nameField, '   ');
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    });

    testWidgets('★保存に失敗したら握らずに画面へ出す（決定 D53）', (tester) async {
      final decks = await _open(tester, deck: _deck());
      decks.failSave = StateError('書き込めません');

      await tester.enterText(_nameField, 'X');
      await tester.pumpAndSettle();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('書き込めません'), findsOneWidget);
      expect(find.text('保存しました'), findsNothing);
      expect(find.text('未保存の変更があります'), findsOneWidget);
    });
  });

  group('★★ 4 枚制限はメインデッキだけ（総合ルール 6.1.1.2）★★', () {
    // ★★ 出る側と出ない側を対で固定する ★★
    //   止まる側だけ見ると「常に止める実装」でも通ってしまう。
    testWidgets('メンバーは 4 枚で「+」が無効になる', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 4)]),
      );

      final add = tester.widget<IconButton>(
        find.descendant(
          of: _deckRow('M-1-N'),
          // ★byTooltip は Tooltip を返す。ボタンそのものを掴む。
          matching: find.widgetWithIcon(IconButton, Icons.add),
        ),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('★エネルギーは 4 枚でも「+」が有効（6.1.1.2 はメインデッキのみ）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'E-1-N', count: 4)]),
      );

      final add = tester.widget<IconButton>(
        find.descendant(
          of: _deckRow('E-1-N'),
          // ★byTooltip は Tooltip を返す。ボタンそのものを掴む。
          matching: find.widgetWithIcon(IconButton, Icons.add),
        ),
      );
      expect(add.onPressed, isNotNull);
    });

    testWidgets('★エネルギーも 12 枚（6.1.1.3）で止まる', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'E-1-N', count: 12)]),
      );

      final add = tester.widget<IconButton>(
        find.descendant(
          of: _deckRow('E-1-N'),
          // ★byTooltip は Tooltip を返す。ボタンそのものを掴む。
          matching: find.widgetWithIcon(IconButton, Icons.add),
        ),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('★★ パラレル違いも合算される（同じ cardNumber）★★', (tester) async {
      // M-1-N を 4 枚持っていると、別刷りの M-1-P も入れられない。
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 4)]),
      );

      final add = tester.widget<IconButton>(
        find.descendant(
          of: _catalogCell('M-1-P'),
          matching: find.byType(IconButton),
        ),
      );
      expect(add.onPressed, isNull);
      // 別のカードは入れられる（出ない側）。
      final other = tester.widget<IconButton>(
        find.descendant(
          of: _catalogCell('M-2-N'),
          matching: find.byType(IconButton),
        ),
      );
      expect(other.onPressed, isNotNull);
    });

    testWidgets('★ドラッグで超えようとしたら理由を出す（黙って何も起きない、にしない）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 4)]),
      );

      await _dragTo(
        tester,
        tester.getCenter(_catalogCell('M-1-P')),
        tester.getCenter(_deckRow('M-1-N')),
      );

      expect(
        find.text('同じカードナンバーは 4 枚までです（別の絵柄も合算されます）。'),
        findsOneWidget,
      );
    });
  });

  group('★★ P1 検証パネルは DeckValidator の結果を出す（決定 D28 / D55）★★', () {
    testWidgets('空のデッキは構築条件を満たさず、内訳が出る', (tester) async {
      await _open(tester, deck: _deck());

      expect(find.text('構築条件を満たしていません'), findsOneWidget);
      // 総合ルール 6.1.1.1 / 6.1.1.3。★期待値は RuleConfig から来ている。
      expect(find.text('メンバー 0 / 48'), findsOneWidget);
      expect(find.text('ライブ 0 / 12'), findsOneWidget);
      expect(find.text('エネルギー 0 / 12'), findsOneWidget);
      expect(find.text('未達 3 件'), findsOneWidget);
    });

    testWidgets('★UI は自分で数え直していない（DeckValidator の数え方がそのまま出る）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 5)]),
      );

      expect(find.text('メンバー 5 / 48'), findsOneWidget);
      // 4 枚超過 + メンバー数不一致 + ライブ + エネルギー = 4 件。
      expect(find.text('未達 4 件'), findsOneWidget);
      expect(find.textContaining('メインデッキの上限4枚'), findsOneWidget);
    });
  });

  group('★★ 縮退は起きたときだけ出す ★★', () {
    testWidgets('★並べ替えると「開き直すとカード番号順に戻ります」が出る（決定 D65）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      // ★出ない側。並べ替える前は出ていない。
      expect(find.textContaining('カード番号順に戻ります'), findsNothing);

      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      expect(
        find.text('並び順はこの画面の中だけです。開き直すとカード番号順に戻ります。'),
        findsOneWidget,
      );
    });

    testWidgets('★並べ替えても保存ボタンは光らない（押せると「保存したのに戻る」になる）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    });

    testWidgets('★★ マスタに無い刷りを黙って落とさない（決定 D35）★★', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: '知らない刷り', count: 1),
        ]),
      );

      // 行として残っている（消えていない）。
      expect(_deckRow('知らない刷り'), findsOneWidget);
      expect(find.text('表示できないカード  1 枚'), findsOneWidget);
      expect(
        find.textContaining('カードデータが未取得の刷りが 1 件あります'),
        findsOneWidget,
      );
      // ★読み取り専用。増減のボタンを出さない（＝黙って消える経路が無い）。
      expect(
        find.descendant(
          of: _deckRow('知らない刷り'),
          matching: find.byTooltip('1 枚減らす'),
        ),
        findsNothing,
      );
    });
  });

  group('★★ 1 ペインでも同じ Widget を出す（§2-1）★★', () {
    testWidgets('狭いとデッキペインは横に出ず、ボタンから開く', (tester) async {
      await _open(tester, deck: _deck(), width: 700);

      // 横には出ていない。
      expect(find.byType(DeckPane), findsNothing);

      await tester.tap(find.byTooltip('デッキを見る'));
      await tester.pumpAndSettle();

      // ★同じ Widget がモーダルで出る。
      expect(find.byType(DeckPane), findsOneWidget);
      expect(find.text('メンバー 0 / 48'), findsOneWidget);
    });

    testWidgets('★広いときは「デッキを見る」ボタンを出さない（横に見えている）',
        (tester) async {
      await _open(tester, deck: _deck());

      expect(find.byType(DeckPane), findsOneWidget);
      expect(find.byTooltip('デッキを見る'), findsNothing);
    });
  });
}
