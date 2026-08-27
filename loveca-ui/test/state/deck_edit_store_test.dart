/// `DeckEditStore` の並びの扱い（決定 D99）.
///
/// ★★ ここはドラフトの上の話であって、保存の意味ではない ★★
/// 保存の往復は `test/data/deck_repository_test.dart` が実 DB で固定している。
/// 役割を混ぜないため、ここではフェイクを使う
/// （フェイクも導出は本実装の `DeckCatalogView` をそのまま使う）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/state/deck_edit_store.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';

import '../support/fake_deck_repository.dart';

Deck _deck({List<DeckEntry> entries = const []}) => Deck(
      deckId: 'd1',
      name: 'テスト',
      entries: entries,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

DeckEditStore _store({List<DeckEntry> entries = const []}) {
  final deck = _deck(entries: entries);
  return DeckEditStore(FakeDeckRepository(decks: [deck]), deck);
}

List<String> _ids(DeckEditStore store) =>
    [for (final e in store.value.draft.entries) e.printingId];

void main() {
  test('★前提: 規則順と printingId 昇順が食い違う', () {
    // ★★ これが以下すべての土台である ★★
    //   `fakeCatalog()` は M-1 が cost 2 / M-2 が cost 9。
    //   一致していると、挿入位置を計算しない実装でも通ってしまう。
    final repository = FakeDeckRepository();
    expect(
      repository.sortedByRule(const [
        DeckEntry(printingId: 'M-1-N', count: 1),
        DeckEntry(printingId: 'M-2-N', count: 1),
      ]).map((e) => e.printingId),
      ['M-2-N', 'M-1-N'],
      reason: '★ここが printingId 昇順と同じでは、以下のテストは何も証明しない',
    );
  });

  group('★★ 追加は規則順の位置に入る（決定 D99）★★', () {
    test('末尾ではなく cost の位置に入る', () {
      final store = _store()
        ..addCard('M-2-N') // cost 9
        ..addCard('L-1-N') // ライブ
        ..addCard('M-1-N'); // cost 2 → ★M-2 の後・L-1 の前

      expect(_ids(store), ['M-2-N', 'M-1-N', 'L-1-N']);
    });

    test('★ 区分をまたいで正しい側に入る（末尾に足す実装なら落ちる）', () {
      final store = _store()
        ..addCard('E-1-N')
        ..addCard('M-1-N');

      // ★末尾に足す実装だと ['E-1-N', 'M-1-N'] になる。
      expect(_ids(store), ['M-1-N', 'E-1-N']);
    });

    test('★対: 落とし先が指定されていれば利用者の指示が勝つ', () {
      final store = _store()
        ..addCard('M-2-N')
        ..addCard('L-1-N');
      // ★規則順なら M-1-N は M-2-N の直後だが、L-1-N の後ろへ落とす。
      store.addCard('M-1-N', before: 'L-1-N', edge: DropEdge.trailing);

      expect(_ids(store), ['M-2-N', 'L-1-N', 'M-1-N']);
    });

    test('★ すでにある行に足すと位置は変わらない（枚数が増えるだけ）', () {
      final store = _store()
        ..addCard('M-1-N')
        ..addCard('M-2-N');
      // ★★ 手で規則順を崩してから足す ★★
      //   規則順のままだと「位置が変わらない」と「規則順に入れ直した」の
      //   区別がつかない。
      store.moveEntry('M-1-N', 'M-2-N', DropEdge.leading);
      expect(_ids(store), ['M-1-N', 'M-2-N']);

      store.addCard('M-2-N');

      expect(_ids(store), ['M-1-N', 'M-2-N'],
          reason: '★すでにある行は枚数が増えるだけで、位置は動かない');
      expect(store.value.draft.countOf('M-2-N'), 2);
    });
  });

  group('★★ 規則順に戻す（決定 D99）★★', () {
    test('手で並べ替えたあとでも規則順に戻る', () {
      final store = _store()
        ..addCard('M-2-N')
        ..addCard('M-1-N')
        ..addCard('L-1-N');
      // ★規則順ではない並びを手で作る。
      store.moveEntry('L-1-N', 'M-2-N', DropEdge.leading);
      expect(_ids(store), ['L-1-N', 'M-2-N', 'M-1-N']);

      store.sortByRule();

      expect(_ids(store), ['M-2-N', 'M-1-N', 'L-1-N']);
    });

    test('★ 枚数を落とさない', () {
      final store = _store()
        ..addCard('M-1-N')
        ..addCard('M-1-N')
        ..addCard('M-2-N');
      store.sortByRule();

      expect(store.value.draft.countOf('M-1-N'), 2);
      expect(store.value.draft.countOf('M-2-N'), 1);
    });

    test('★ 保存はしない（ドラフトを差し替えるだけ）', () {
      final deck = _deck();
      final repository = FakeDeckRepository(decks: [deck]);
      DeckEditStore(repository, deck)
        ..addCard('M-1-N')
        ..sortByRule();

      expect(repository.saveCalls, 0);
    });

    test('★ 規則順に戻すと保存ボタンが光る（並べ替えは保存される）', () async {
      final deck = _deck(entries: const [
        DeckEntry(printingId: 'M-1-N', count: 1),
        DeckEntry(printingId: 'M-2-N', count: 1),
      ]);
      final store = DeckEditStore(FakeDeckRepository(decks: [deck]), deck);
      expect(store.value.isDirty, isFalse);

      store.sortByRule();

      expect(_ids(store), ['M-2-N', 'M-1-N']);
      expect(store.value.isDirty, isTrue);
    });

    test('★対: すでに規則順なら押しても何も変わらない', () {
      final deck = _deck(entries: const [
        DeckEntry(printingId: 'M-2-N', count: 1),
        DeckEntry(printingId: 'M-1-N', count: 1),
      ]);
      final store = DeckEditStore(FakeDeckRepository(decks: [deck]), deck);

      store.sortByRule();

      expect(_ids(store), ['M-2-N', 'M-1-N']);
      expect(store.value.isDirty, isFalse);
    });
  });
}
