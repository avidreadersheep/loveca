/// ウィジェットテスト用の `DeckRepository` 差し替え.
///
/// ★★ 実 DB の往復は `test/data/deck_repository_test.dart` が固定している ★★
/// ここでフェイクを使うのは**画面の振る舞い**を見るためであって、
/// 保存の意味を検証するためではない。役割を混ぜない。
///
/// ★このフェイクは `revision` の増え方を真似しない。
/// 真似すると「revision が保存回数で増える」ことをフェイクに対して確かめる
/// 無意味なテストになる。画面側で見るのは
/// **`save` が何回呼ばれたか**（＝編集では呼ばれないこと）である。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';

/// 最小のカタログ。`DeckValidator` の材料（決定 D55: DB へ行かない）。
MasterCatalog fakeCatalog() => MasterCatalog(
      cards: const {
        'M-1': Card(cardNumber: 'M-1', name: 'メンバー1', cardType: CardType.member),
      },
      printings: const {
        'M-1-N': Printing(
          printingId: 'M-1-N',
          cardNumber: 'M-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
      },
      config: RuleConfig.standard,
      rows: const [],
      dataVersion: 1,
    );

DateTime fakeNow() => DateTime.utc(2026, 8, 24, 12);

class FakeDeckRepository implements DeckRepository {
  FakeDeckRepository({List<Deck> decks = const []})
      : _decks = [...decks],
        _validator = DeckValidator(
          cards: fakeCatalog().cards,
          printings: fakeCatalog().printings,
          config: RuleConfig.standard,
        );

  final List<Deck> _decks;
  final DeckValidator _validator;

  /// ★呼ばれた回数。画面が「編集のたびに保存していない」ことの確認に使う。
  int saveCalls = 0;
  int createCalls = 0;
  int softDeleteCalls = 0;

  /// 投げさせたい操作。★リポジトリは例外を握らないので、画面まで届くはず。
  Object? failAll;
  Object? failCreate;
  Object? failSoftDelete;
  Object? failSave;

  @override
  Future<List<Deck>> all() async {
    if (failAll case final error?) throw error;
    return _decks.where((d) => !d.isDeleted).toList();
  }

  @override
  Future<Deck?> byId(String deckId) async =>
      _decks.where((d) => d.deckId == deckId).firstOrNull;

  @override
  Future<Deck> create({required String name}) async {
    createCalls++;
    if (failCreate case final error?) throw error;
    final deck = Deck(
      deckId: 'deck-$createCalls',
      name: name,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );
    _decks.add(deck);
    return deck;
  }

  @override
  Future<Deck> save(Deck base, DeckDraft draft) async {
    saveCalls++;
    if (failSave case final error?) throw error;
    final next = base.copyWith(
      name: draft.name,
      memo: draft.memo,
      updatedAt: fakeNow(),
    );
    _decks
      ..removeWhere((d) => d.deckId == base.deckId)
      ..add(next);
    return next;
  }

  @override
  Future<void> softDelete(String deckId) async {
    softDeleteCalls++;
    if (failSoftDelete case final error?) throw error;
    final i = _decks.indexWhere((d) => d.deckId == deckId);
    if (i < 0) return;
    final d = _decks[i];
    _decks[i] = d.copyWith(deletedAt: fakeNow(), updatedAt: fakeNow());
  }

  @override
  DeckValidationResult validate(Deck deck) => _validator.validate(deck);

  @override
  bool canAdd(Deck deck, String printingId) =>
      _validator.canAdd(deck, printingId);
}
