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
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_pane.dart';
import 'package:loveca_ui/src/ui/deck/deck_validation_panel.dart';

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

/// ★★ 小さい構築条件（決定 D96 / D97 の軸 2 を見るために要る）★★
///
/// fixture のメンバーは 2 種しかないので、**4 枚制限（6.1.1.2）を守ったまま
/// 48 枚は組めない。**「不足がエネルギーだけ」という状態を作るには
/// 構築条件そのものを小さくするしかない。★6.1.2 が置換を認めている。
const _smallRules = RuleConfig(memberCount: 4, liveCount: 4);

/// 設定と構築条件を差し替えて開く（★軸 2 の文言は設定で変わる / 決定 D97）。
Future<void> _openWithSettings(
  WidgetTester tester, {
  required Deck deck,
  AppSettings settings = AppSettings.defaults,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.reset);

  final catalog = fakeCatalog(config: _smallRules);
  await pumpInAppScope(
    tester,
    DeckEditPage(deck: deck),
    decks: FakeDeckRepository(decks: [deck], catalog: catalog),
    catalog: catalog,
    settings: settings,
  );
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

  group('★★ 4 枚制限では止めない。★止まるのはエネルギー 12 枚だけ（`Android UI 決定` §1-3）★★', () {
    // ★★ 出る側と出ない側を対で固定する ★★
    //   止まる側だけ見ると「常に止める実装」でも通ってしまう。
    //
    // ★★ 2026-09-03: メンバーの 4 枚で「+」が無効になる、を★★覆した★★ ★★
    //   ★総合ルール 6.1.1.2 は 1 文字も変わっていない —— ★検証パネルが今も出す
    //   （★下の検証パネルの群がそれを見ている）。
    testWidgets('★メンバーは 4 枚でも「+」が有効（★以前は無効だった）', (tester) async {
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
      expect(add.onPressed, isNotNull);
    });

    testWidgets('★対: メンバーは 4 枚でも★ライブでも有効（種別で分けていない）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'L-1-N', count: 4)]),
      );

      final add = tester.widget<IconButton>(
        find.descendant(
          of: _deckRow('L-1-N'),
          matching: find.widgetWithIcon(IconButton, Icons.add),
        ),
      );
      expect(add.onPressed, isNotNull);
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

    testWidgets('★★ パラレル違いも★止めない（★以前は合算して止めていた）★★', (tester) async {
      // ★M-1-N を 4 枚持っていても、★別刷りの M-1-P が入る。
      //   ★★合算そのものは 1 ビットも変わっていない★★ ——
      //   ★`DeckValidator.validate` は今も 5 枚として `tooManyCopies` を出す。
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
      expect(add.onPressed, isNotNull, reason: '★以前はここが null だった');
      // 別のカードも入れられる（★対 —— ★「常に無効」でないこと）。
      final other = tester.widget<IconButton>(
        find.descendant(
          of: _catalogCell('M-2-N'),
          matching: find.byType(IconButton),
        ),
      );
      expect(other.onPressed, isNotNull);
    });

    testWidgets('★ドラッグで 5 枚目を落としても★理由を出さない（★入る）', (tester) async {
      // ★★2026-09-03: 覆した★★ ——
      //   ★以前は「同じカードナンバーは 4 枚までです」の SnackBar が出た。
      //   ★いまは**入るので、断る理由が存在しない**（★申し送り §1-3）。
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 4)]),
      );

      await _dragTo(
        tester,
        tester.getCenter(_catalogCell('M-1-P')),
        tester.getCenter(_deckRow('M-1-N')),
      );

      expect(find.textContaining('4 枚までです'), findsNothing);
      // ★★対: 入ったこと自体を見る（★「黙って何も起きない」と区別する）★★
      expect(_deckRow('M-1-P'), findsOneWidget);
    });

    testWidgets('★対: エネルギーは 12 枚でドラッグを断る（★理由を出す）', (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'E-1-N', count: 12)]),
      );

      await _dragTo(
        tester,
        tester.getCenter(_catalogCell('E-1-N')),
        tester.getCenter(_deckRow('E-1-N')),
      );

      expect(find.text('エネルギーデッキは 12 枚までです。'), findsOneWidget);
    });
  });

  group('★★ P1 検証パネルは DeckValidator の結果を出す（決定 D28 / D55）★★', () {
    testWidgets('空のデッキは構築条件を満たさず、内訳が出る', (tester) async {
      await _open(tester, deck: _deck());

      expect(find.text('構築条件を満たしていません'), findsOneWidget);
      // 総合ルール 6.1.1.1 / 6.1.1.3。★期待値は RuleConfig から来ている。
      expect(find.text('メンバー 0 / 48'), findsOneWidget);
      expect(find.text('ライブ 0 / 12'), findsOneWidget);
      // ★★数はそのまま出る。★消したのは「未達」の勘定だけである（★申し送り §1-1）★★
      expect(find.text('エネルギー 0 / 12'), findsOneWidget);
      // ★★2026-09-03: 3 → 2 になった★★（★エネルギー 0 枚を勘定しない）。
      expect(find.text('未達 2 件'), findsOneWidget);
    });

    testWidgets('★UI は自分で数え直していない（DeckValidator の数え方がそのまま出る）',
        (tester) async {
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 5)]),
      );

      expect(find.text('メンバー 5 / 48'), findsOneWidget);
      // ★4 枚超過 + メンバー数不一致 + ライブ = 3 件
      //   （★★エネルギー 0 枚は勘定しない / 2026-09-03★★）。
      expect(find.text('未達 3 件'), findsOneWidget);
      expect(find.textContaining('メインデッキの上限4枚'), findsOneWidget);
    });

    testWidgets('★★ エネルギー 1 枚なら★今も未達に数える（★申し送り §1-1）★★',
        (tester) async {
      // ★★0 だけを外していることの対★★ ——
      //   ★1〜11 枚は盤面でも補われない（`EnergyFillSkip.notNeeded`）ので、
      //   ★★警告が要るのはこちらである★★。
      await _open(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'E-1-N', count: 1)]),
      );

      expect(find.text('エネルギー 1 / 12'), findsOneWidget);
      // ★メンバー + ライブ + エネルギー = 3 件。
      expect(find.text('未達 3 件'), findsOneWidget);
      expect(find.text('構築条件を満たしていません'), findsOneWidget);
    });

    testWidgets('★★ エネルギー 0 / 12 の行は★未達の見た目にならない ★★', (tester) async {
      // ★★この対は★2026-09-03 に新設した★★ ——
      //   ★**`_CountLine` の色には★対が 1 つも無かった**
      //   （★実測: ★★`warn` を無視する仕込みで★1218 件が全部通った★★ / **D-27** の (a)）。
      //   ★見出しが「満たしています」なのにこの 1 行だけ未達の色だと
      //   ★★2 つが食い違って読める★★。
      await _openWithSettings(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 4),
        ]),
      );

      TextStyle? styleOf(String text) =>
          tester.widget<Text>(find.text(text)).style;

      // ★満たしている 2 行と★同じ見た目である。
      expect(styleOf('エネルギー 0 / 12')?.fontWeight, FontWeight.w600);
      expect(styleOf('エネルギー 0 / 12')?.color, styleOf('メンバー 4 / 4')?.color);
    });

    testWidgets('★対: エネルギー 1 / 12 の行は★未達の見た目になる', (tester) async {
      await _openWithSettings(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 4),
          DeckEntry(printingId: 'E-1-N', count: 1),
        ]),
      );

      TextStyle? styleOf(String text) =>
          tester.widget<Text>(find.text(text)).style;

      expect(styleOf('エネルギー 1 / 12')?.fontWeight, isNot(FontWeight.w600));
      expect(
        styleOf('エネルギー 1 / 12')?.color,
        isNot(styleOf('メンバー 4 / 4')?.color),
      );
    });

    testWidgets('★★ エネルギー 0 枚だけが足りないデッキは「満たしています」になる ★★',
        (tester) async {
      // ★★条文には反する（6.1.1.3）。★利用者判断で表示しないことにした★★
      //   —— ★`docs/UI設計メモ.md` §12-3 の読みは 1 ミリも動いていない。
      //   ★`DeckValidator` は今も `energyCountMismatch` を出している（★下で見る）。
      await _openWithSettings(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 4),
        ]),
      );

      expect(find.text('構築条件を満たしています'), findsOneWidget);
      expect(find.text('未達 2 件'), findsNothing);
      expect(find.text('エネルギー 0 / 12'), findsOneWidget);
    });
  });

  test('★★ `DeckValidator` は 1 行も変わっていない（★出さないのは表示だけ）★★', () {
    // ★★この対が要石である★★ ——
    //   ★画面が出さないことと、★検証が出さないことは★★別である★★。
    //   ★同期もサーバーも `DeckValidator` を見る（**D28** / `loveca_core`）。
    const validation = DeckValidationResult(
      issues: [
        DeckIssue(
          code: DeckIssueCode.energyCountMismatch,
          message: 'エネルギーカード 0枚 (12枚ちょうど必要)',
        ),
      ],
      memberCount: 48,
      liveCount: 12,
      energyCount: 0,
      unknownPrintingIds: [],
    );

    expect(validation.isValid, isFalse, reason: '★検証は今も落としている');
    expect(visibleDeckIssues(validation), isEmpty, reason: '★画面には出さない');
  });

  test('★対: エネルギー 1 枚なら★画面にも出す', () {
    const validation = DeckValidationResult(
      issues: [
        DeckIssue(
          code: DeckIssueCode.energyCountMismatch,
          message: 'エネルギーカード 1枚 (12枚ちょうど必要)',
        ),
      ],
      memberCount: 48,
      liveCount: 12,
      energyCount: 1,
      unknownPrintingIds: [],
    );

    expect(visibleDeckIssues(validation), hasLength(1));
  });

  test('★対: 13 枚（超過）は★今も出す', () {
    const validation = DeckValidationResult(
      issues: [
        DeckIssue(
          code: DeckIssueCode.energyCountMismatch,
          message: 'エネルギーカード 13枚 (12枚ちょうど必要)',
        ),
      ],
      memberCount: 48,
      liveCount: 12,
      energyCount: 13,
      unknownPrintingIds: [],
    );

    expect(visibleDeckIssues(validation), hasLength(1));
  });

  test('★対: 0 枚でも★エネルギー以外の未達は落とさない', () {
    const validation = DeckValidationResult(
      issues: [
        DeckIssue(
          code: DeckIssueCode.energyCountMismatch,
          message: 'エネルギー',
        ),
        DeckIssue(code: DeckIssueCode.memberCountMismatch, message: 'メンバー'),
        DeckIssue(code: DeckIssueCode.tooManyCopies, message: '4 枚'),
      ],
      memberCount: 0,
      liveCount: 0,
      energyCount: 0,
      unknownPrintingIds: [],
    );

    expect(
      visibleDeckIssues(validation).map((i) => i.code),
      [DeckIssueCode.memberCountMismatch, DeckIssueCode.tooManyCopies],
    );
  });

  /// ★★ 軸 2 —— 6.1 の判定は曲げず、盤面の挙動を別行で出す（決定 D96-2）★★
  ///
  /// ★上の行（構築条件を満たしていません / エネルギー 0 / 12）は**絶対に変えない。**
  /// 0 枚を「満たしている」と呼ぶことは 6.1.1.3 に反しており、解けない。
  group('★★ エネルギー 0 枚のときの軸 2（決定 D96 / D97）★★', () {
    /// 6.1 を満たすメンバー / ライブを積んだうえで、エネルギーだけ 0 枚にする。
    /// ★4 枚制限（6.1.1.2）は守る —— 破ると「不足がエネルギーだけ」でなくなる。
    Deck energyOnlyShort() => _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 4),
        ]);

    testWidgets('★★ エネルギーだけが不足しているとき、補う旨が出る ★★', (tester) async {
      await _openWithSettings(
        tester,
        deck: energyOnlyShort(),
        settings: const AppSettings(energyFillPrintingId: 'E-1-N'),
      );

      expect(find.byKey(const ValueKey('energyFillNote')), findsOneWidget);
      expect(find.textContaining('開始時にエネルギーを 12 枚'), findsOneWidget);
      // ★★ 2026-09-03: 上の行が「満たしています」に変わった（★申し送り §1-1）★★
      //   ★以前はここが「構築条件を満たしていません」で、
      //   ★★「上の 6.1 の判定はデッキそのものに対するもの」という 1 文を添えていた★★。
      //   ★★あの 1 文は★偽になったので消した★★（**D-25** の型 —— ★字面を残さない）。
      expect(find.text('構築条件を満たしていません'), findsNothing);
      expect(find.text('エネルギー 0 / 12'), findsOneWidget);
      expect(find.textContaining('上の 6.1 の判定はデッキそのものに対するもの'),
          findsNothing);
    });

    testWidgets('★★ メンバーも足りないデッキでは出さない ★★', (tester) async {
      // ★出すと「補完が効かない不足まで補われる」ように読める。
      await _openWithSettings(
        tester,
        deck: _deck(entries: const [DeckEntry(printingId: 'M-1-N', count: 1)]),
        settings: const AppSettings(energyFillPrintingId: 'E-1-N'),
      );

      expect(find.text('構築条件を満たしていません'), findsOneWidget);
      expect(find.byKey(const ValueKey('energyFillNote')), findsNothing);
    });

    testWidgets('★対: 6.1 を満たしているデッキでも出さない', (tester) async {
      await _openWithSettings(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 4),
          DeckEntry(printingId: 'E-1-N', count: 12),
        ]),
        settings: const AppSettings(energyFillPrintingId: 'E-1-N'),
      );

      expect(find.text('構築条件を満たしています'), findsOneWidget);
      expect(find.byKey(const ValueKey('energyFillNote')), findsNothing);
    });

    testWidgets('★★ 補完しない設定なら文言が変わる（「補います」と嘘を書かない）★★',
        (tester) async {
      await _openWithSettings(
        tester,
        deck: energyOnlyShort(),
        settings: AppSettings.defaults.copyWith(clearEnergyFill: true),
      );

      expect(find.byKey(const ValueKey('energyFillNote')), findsOneWidget);
      expect(find.textContaining('補完しません'), findsOneWidget);
      expect(find.textContaining('開始時にエネルギーを 12 枚'), findsNothing);
    });

    testWidgets('★★ 引けない刷りが設定されていても文言が変わる ★★', (tester) async {
      await _openWithSettings(
        tester,
        deck: energyOnlyShort(),
        settings: const AppSettings(energyFillPrintingId: 'GHOST-9-9-X'),
      );

      expect(find.textContaining('補うカードを用意できません'), findsOneWidget);
      expect(find.textContaining('開始時にエネルギーを 12 枚'), findsNothing);
    });
  });

  group('★★ 縮退は起きたときだけ出す ★★', () {
    testWidgets('★★ 並べ替えの予告はもう出ない（決定 D99 で撤去）★★',
        (tester) async {
      // ★★ 2026-08-27: 向きが逆になった ★★
      //   `deck_entries` に `ord` が入り**並びは保存される**ので、
      //   「開き直すとカード番号順に戻ります」という予告は嘘になった。
      //   ★縮退の型ごと撤去した（`DeckOrderNotPersisted`）。
      // ★★ マスタに無い刷りを 1 枚混ぜてある ★★
      //   これが陽性対照である。混ぜないと**この test は findsNothing だけ**になり、
      //   **縮退の描画経路を丸ごと殺しても通る。**
      //   ★2026-08-27 の自己検査で、実際にそうなっていたのを直した
      //   （コメントは「別の縮退はまだ出る」と言っているのに `findsNothing` を
      //     見ていた。フィクスチャに未知の刷りが無いので通っていた）。
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
          DeckEntry(printingId: '知らない刷り', count: 1),
        ]),
      );

      // ★★ 対: 別の縮退が出ている（＝縮退の帯そのものは生きている）★★
      //   ★見るのは `_DeckDegradationLine` が出す文言でなければならない。
      //   「表示できないカード」は**区分の見出し**（`_section`）なので、
      //   縮退の描画を丸ごと殺しても出たままである。**実測で確かめた。**
      expect(find.textContaining('カードデータが未取得の刷りが'), findsOneWidget);
      expect(find.textContaining('カード番号順に戻ります'), findsNothing);

      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      // ★並べ替えても予告は出ない。★対のほうは出たまま。
      expect(find.textContaining('カード番号順に戻ります'), findsNothing);
      expect(find.textContaining('カードデータが未取得の刷りが'), findsOneWidget);
    });

    testWidgets('★★ 並べ替えると保存ボタンが光る（D65 の手当て 4 は前提が反転）★★',
        (tester) async {
      // ★★ D65 は「押せると『保存したのに戻る』という最悪の形になる」ので
      //    光らせなかった。保存されるようになったので、
      //    今度は**光らせないほうが**「並べ替えたのに保存できない」になる。★★
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      // ★出ない側。並べ替える前は光っていない。
      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);

      final target = tester.getRect(_deckRow('M-1-N'));
      await _dragTo(
        tester,
        tester.getCenter(_deckRow('M-2-N')),
        Offset(target.center.dx, target.top + 4),
      );

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);
    });

    testWidgets('★★ 「規則順に戻す」が 1 押しで届く（決定 D99）★★', (tester) async {
      // ★★ 入口は 1 つ・2 段以内（U27 を繰り返さない）★★
      //   ★アイコンだけにしない —— `Tooltip` はマウスを乗せないと出ない（D90-3）。
      //   **ラベルが見えていること**を固定する。
      await _open(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]),
      );

      // ★メニューを開く操作を挟まずに、いきなり見えていること。
      expect(find.text('規則順に戻す'), findsOneWidget);

      // ★M-1 は cost 2 / M-2 は cost 9。規則順では M-2 が先（決定 D99）。
      await tester.tap(find.byKey(const Key('deckSortByRuleButton')));
      await tester.pump();

      // ★画面上の縦位置で見る（並びそのもの）。
      expect(
        tester.getCenter(_deckRow('M-2-N')).dy,
        lessThan(tester.getCenter(_deckRow('M-1-N')).dy),
      );
      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);
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
