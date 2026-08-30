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
///
/// ★★ 導出（検証・区分・並びの正規化）は本実装の [DeckCatalogView] をそのまま使う ★★
/// フェイク側で書き直すと**本実装と黙って食い違う。**
/// カタログだけで答えられる部分は DB を要らないので、そのまま持てる（決定 D55）。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';

/// 最小のカタログ。`DeckValidator` の材料（決定 D55: DB へ行かない）。
///
/// ★M4 で 3 区分そろえた。**4 枚制限がメインデッキだけに効く**ことを
/// 確かめるにはエネルギーが要り、**パラレル違いも合算される**（6.1.1.2）ことを
/// 確かめるには同じ cardNumber の 2 刷りが要る。
/// ★[config] を差し替えられる —— 総合ルール **6.1.2** により構築条件は
/// 置換されうるし、fixture のカード種類は少ないので
/// **48 / 12 の標準値では「4 枚制限を守った合法デッキ」を組めない。**
MasterCatalog fakeCatalog({RuleConfig config = RuleConfig.standard}) =>
    MasterCatalog(
      cards: const {
        // ★★ cost / score は「規則順 ≠ printingId 昇順」になるように選んである ★★
        //   M-1 のほうが printingId は小さいが cost は**小さい**ので、
        //   規則順（cost 降順 / 決定 D99）では **M-2 が先**に来る。
        //   値をそろえると、比較器が何もしなくてもテストが通ってしまう。
        'M-1': Card(
            cardNumber: 'M-1', name: 'メンバー1', cardType: CardType.member, cost: 2),
        'M-2': Card(
            cardNumber: 'M-2', name: 'メンバー2', cardType: CardType.member, cost: 9),
        'L-1': Card(
            cardNumber: 'L-1', name: 'ライブ1', cardType: CardType.live, score: 5),
        'E-1':
            Card(cardNumber: 'E-1', name: 'エネルギー1', cardType: CardType.energy),
      },
      printings: const {
        'M-1-N': Printing(
          printingId: 'M-1-N',
          cardNumber: 'M-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        // ★同じ cardNumber の別刷り。4 枚制限はこれと合算される（6.1.1.2）。
        'M-1-P': Printing(
          printingId: 'M-1-P',
          cardNumber: 'M-1',
          expansion: 'bp1',
          rarity: 'PE',
          isParallel: true,
        ),
        'M-2-N': Printing(
          printingId: 'M-2-N',
          cardNumber: 'M-2',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        'L-1-N': Printing(
          printingId: 'L-1-N',
          cardNumber: 'L-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        'E-1-N': Printing(
          printingId: 'E-1-N',
          cardNumber: 'E-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
      },
      config: config,
      rows: fakeRows,
      dataVersion: 1,
    );

/// 一覧の投影行（決定 D48）。★`imageHash` は空なのでプレースホルダのままになる。
const List<CardListRow> fakeRows = [
  CardListRow(
    printingId: 'M-1-N',
    cardNumber: 'M-1',
    name: 'メンバー1',
    cardType: CardType.member,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    cost: 1,
  ),
  CardListRow(
    printingId: 'M-1-P',
    cardNumber: 'M-1',
    name: 'メンバー1',
    cardType: CardType.member,
    expansion: 'bp1',
    rarity: 'PE',
    isParallel: true,
    imageHash: '',
    cost: 1,
  ),
  CardListRow(
    printingId: 'M-2-N',
    cardNumber: 'M-2',
    name: 'メンバー2',
    cardType: CardType.member,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    cost: 2,
  ),
  CardListRow(
    printingId: 'L-1-N',
    cardNumber: 'L-1',
    name: 'ライブ1',
    cardType: CardType.live,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    // ★ライブに cost は無い（`normalize.py:362-363` はメンバーの分岐でしか入れない）。
    cost: null,
  ),
  CardListRow(
    printingId: 'E-1-N',
    cardNumber: 'E-1',
    name: 'エネルギー1',
    cardType: CardType.energy,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    cost: null,
  ),
];

DateTime fakeNow() => DateTime.utc(2026, 8, 24, 12);

class FakeDeckRepository implements DeckRepository {
  /// [catalog] を渡すと導出（検証・区分・行）の材料が差し替わる。
  /// ★M5 は実データから写した `realShapedCatalog()` を渡す。
  FakeDeckRepository({List<Deck> decks = const [], MasterCatalog? catalog})
      : _decks = [...decks],
        _view = DeckCatalogView(catalog ?? fakeCatalog());

  final List<Deck> _decks;

  /// ★本実装の導出をそのまま使う（書き直さない）。
  final DeckCatalogView _view;

  /// ★呼ばれた回数。画面が「編集のたびに保存していない」ことの確認に使う。
  int saveCalls = 0;
  int duplicateCalls = 0;
  Deck? lastDuplicated;
  int createCalls = 0;
  int softDeleteCalls = 0;

  /// 直近に保存されたデッキ。★保存した中身を画面のテストから覗く用。
  Deck? lastSaved;

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

  /// ★★ [ops] を数えも保持もしない（★意図的である）★★
  /// このフェイクは**ログの行を持たない**（`DeckDao` が持つ）。
  /// ★**ここで数えると「フェイクは覚えているが DB には無い」状態を作れてしまう**ので、
  /// ★実際にログが残ることを見るテストは**実 DB** を使う
  /// （`test/data/deck_delete_log_test.dart` が **D110-3** で採ったのと同じ形）。
  @override
  Future<Deck> save(
    Deck base,
    DeckDraft draft, {
    required List<DeckEditOpRecord> ops,
  }) async {
    saveCalls++;
    if (failSave case final error?) throw error;
    // ★本実装と同じく明示コンストラクタで畳む（決定 D70）。
    //   `copyWith` のままにすると、フェイクだけカバーを外せず、
    //   **本実装と黙って食い違う。**
    final next = Deck(
      deckId: base.deckId,
      name: draft.name,
      entries: draft.entries,
      memo: draft.memo,
      tags: draft.tags,
      coverPrintingId: draft.coverPrintingId,
      createdAt: base.createdAt,
      updatedAt: fakeNow(),
      deletedAt: base.deletedAt,
      revision: base.revision + 1,
      lastDeviceId: base.lastDeviceId,
      masterDataVersion: base.masterDataVersion,
    );
    _decks
      ..removeWhere((d) => d.deckId == base.deckId)
      ..add(next);
    lastSaved = next;
    return next;
  }

  @override
  Future<Deck> duplicate(Deck source, {required String name}) async {
    duplicateCalls++;
    final copy = Deck(
      deckId: 'copy-$duplicateCalls',
      name: name,
      entries: source.entries,
      memo: source.memo,
      tags: source.tags,
      coverPrintingId: source.coverPrintingId,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
      revision: 0,
      lastDeviceId: source.lastDeviceId,
      masterDataVersion: source.masterDataVersion,
    );
    _decks.add(copy);
    lastDuplicated = copy;
    return copy;
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

  // --- 以下は本実装と同じ導出。★書き直さず [DeckCatalogView] へ通す。 ---

  @override
  DeckCatalogView get catalogView => _view;

  @override
  DeckValidationResult validate(Deck deck) => _view.validate(deck);

  @override
  DeckValidationResult validateDraft(Deck base, DeckDraft draft) =>
      _view.validateDraft(base, draft);

  @override
  bool canAdd(Deck deck, String printingId) => _view.canAdd(deck, printingId);

  @override
  bool canAddToDraft(Deck base, DeckDraft draft, String printingId) =>
      _view.canAddToDraft(base, draft, printingId);

  @override
  DeckSections sectionsOf(List<DeckEntry> entries) => _view.sectionsOf(entries);

  @override
  CardType? cardTypeOf(String printingId) => _view.cardTypeOf(printingId);

  @override
  CardListRow? rowOf(String printingId) => _view.rowOf(printingId);

  @override
  DeckDraft draftOf(Deck deck) => _view.draftOf(deck);

  @override
  List<DeckEntry> sortedByRule(List<DeckEntry> entries) =>
      _view.sortedByRule(entries);

  @override
  int insertionIndexOf(List<DeckEntry> entries, String printingId) =>
      _view.insertionIndexOf(entries, printingId);
}
