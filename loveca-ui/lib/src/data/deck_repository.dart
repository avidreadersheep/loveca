/// デッキの読み書きと検証（決定 D55 / `docs/UI設計メモ.md` §4-1 / §9）.
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない ★★
/// このクラスが返すのは `loveca_core` の型と UI 用の値だけで、drift の型を返さない。
///
/// ★★ `Deck.copyWith` を呼ぶのは [DeckRepository.save] 1 箇所だけである ★★
/// `docs/UI設計メモ.md` §9-1 の
/// 「編集中はドラフトを Store に持ち、保存時に 1 回だけ `copyWith` する」を
/// **規約ではなく構造で守る。** Store が持つのは [DeckDraft]（文字列 2 本）であって
/// `Deck` ではないので、**キー入力のたびに `revision` が跳ねる経路が存在しない。**
/// 跳ねると Phase 4 の同期で「大量に更新された」ように見える。
///
/// ★★ `updatedAt` を必ず明示的に渡す ★★
/// `Deck.copyWith` の既定値は `DateTime.now().toUtc()`（CLAUDE.md §1 の既知違反）。
/// 呼び出し側から渡せばその影響を受けない。供給元は [Clock]（§9-1）。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import 'clock.dart';
import 'deck_id.dart';
import 'master_catalog.dart';
import 'repository_exception.dart';

/// 編集中の下書き（`docs/UI設計メモ.md` §9-1）.
///
/// ★★ ここに `Deck` を持たせない ★★
/// 持たせると「編集のたびに `copyWith` する」書き方が自然に見えてしまい、
/// `revision` が編集操作の回数だけ跳ねる。ドラフトは**保存されていない値**であり、
/// `Deck` になるのは [DeckRepository.save] を通った瞬間だけである。
class DeckDraft {
  const DeckDraft({required this.name, required this.memo});

  DeckDraft.of(Deck deck) : name = deck.name, memo = deck.memo;

  final String name;
  final String memo;

  DeckDraft copyWith({String? name, String? memo}) =>
      DeckDraft(name: name ?? this.name, memo: memo ?? this.memo);

  /// 保存済みの [deck] と違いがあるか。保存ボタンの活性はこれで決める。
  bool isDirtyAgainst(Deck deck) => name != deck.name || memo != deck.memo;

  /// 名前が空白だけなら保存させない（`decks.name` は NOT NULL だが空は入る）。
  bool get isValid => name.trim().isNotEmpty;
}

class DeckRepository {
  DeckRepository(
    this._db, {
    required MasterCatalog catalog,
    required Clock clock,
    DeckIdGenerator newDeckId = randomDeckIdV4,
  })  : _clock = clock,
        _newDeckId = newDeckId,
        _dataVersion = catalog.dataVersion,
        // ★★ DeckValidator は 1 個だけ作って持ち回る（決定 D55）★★
        // DeckDao.validate / canAdd は呼ぶたびに cardsByNumber() +
        // printingsById() を引き直す（実測 40〜60ms）。UI からセルごとに
        // 呼ぶとその回数分が UI isolate で走る。
        // カタログはセッション中ずっと不変（決定 D56: 取り込みは起動ゲートでしか
        // 走らない）なので、**無効化処理そのものが要らない。**
        _validator = DeckValidator(
          cards: catalog.cards,
          printings: catalog.printings,
          config: catalog.config,
        );

  final LovecaDatabase _db;
  final Clock _clock;
  final DeckIdGenerator _newDeckId;
  final int _dataVersion;
  final DeckValidator _validator;

  // ---------------------------------------------------------------------------
  // 読み出し
  // ---------------------------------------------------------------------------

  /// 一覧。★論理削除済みは含まない。並びは `updatedAt` 降順。
  ///
  /// ★決定 D53: 例外を握らない。`catch` して空リストを返す経路を作らない。
  /// 「空」と「失敗」を同じ型で表すと、利用者は「デッキが 1 つも無い」と誤解する。
  Future<List<Deck>> all() =>
      guardRepository('deck.all', () => DeckDao(_db).all());

  /// 1 件。
  ///
  /// ★★ 論理削除済みでも返す ★★
  /// `DeckDao.byId` の意味をそのまま通す。ここで隠すと
  /// 「DB には残っている」ことを確かめる手段が UI 側から消える。
  Future<Deck?> byId(String deckId) =>
      guardRepository('deck.byId', () => DeckDao(_db).byId(deckId));

  // ---------------------------------------------------------------------------
  // 書き込み
  // ---------------------------------------------------------------------------

  /// 新規作成して保存し、保存した `Deck` を返す。
  ///
  /// ★`copyWith` を通さない。コンストラクタで作るので既定値の
  /// `DateTime.now()` を踏む余地が無い。
  Future<Deck> create({required String name}) =>
      guardRepository('deck.create', () async {
        final now = _clock();
        final deck = Deck(
          deckId: _newDeckId(), // ★UUID v4（P1 / 決定 D62）
          name: name,
          createdAt: now,
          updatedAt: now,
          revision: 0,
          // ★P5: 作成時のカードマスタ版。未知カード検出に使う（決定 D35）。
          masterDataVersion: _dataVersion,
        );
        await DeckDao(_db).save(deck);
        return deck;
      });

  /// ドラフトを 1 回だけ `Deck` に畳んで保存する。
  ///
  /// ★★ `revision` が +1 されるのは保存 1 回につき 1 度だけである ★★
  /// `Deck.copyWith` の `revision: revision ?? this.revision + 1` を
  /// **ここでしか踏まない**。編集操作の回数では増えない。
  Future<Deck> save(Deck base, DeckDraft draft) =>
      guardRepository('deck.save', () async {
        final next = base.copyWith(
          name: draft.name,
          memo: draft.memo,
          // ★Clock から供給する（§9-1）。既定値の DateTime.now() を踏まない。
          updatedAt: _clock(),
        );
        await DeckDao(_db).save(next);
        return next;
      });

  /// 論理削除（P3）。物理削除すると削除が同期で伝播しない。
  ///
  /// ★★ `revision` は上がらない ★★
  /// `DeckDao.softDelete` は `deletedAt` / `updatedAt` だけを書き、
  /// `revision` に触れない（`loveca-db/lib/src/dao/deck_dao.dart:121-128`）。
  /// `tables.dart:255` が revision を「更新のたびに +1（P2）。同期の差分検出に使う」と
  /// 定めているので食い違うが、直す先は `loveca_db` 側であり、
  /// UI 側で `save()` に迂回すると DAO の意図と二重になる。
  /// → `ルール整合性チェック_v1.06.md` **D-9** に記録し、判断は Phase 4。
  ///
  /// [at] は呼び出し側から渡す形の DAO なので、[Clock] をそのまま通す。
  Future<void> softDelete(String deckId) =>
      guardRepository('deck.softDelete', () => DeckDao(_db).softDelete(deckId, _clock()));

  // ---------------------------------------------------------------------------
  // 検証
  // ---------------------------------------------------------------------------

  /// 総合ルール 6.1 の検証。
  ///
  /// ★★ 同期メソッドである。DB へ行かない（決定 D55）★★
  /// 材料は起動時に組んだ `MasterCatalog` の中にあり、判定そのものは
  /// `loveca_core` の `DeckValidator`（PC・スマホ・サーバで唯一の実装 / 決定 D28）。
  DeckValidationResult validate(Deck deck) => _validator.validate(deck);

  /// 追加可能かの事前判定（M4 のデッキ編集で「+」を無効化するために使う）。
  /// ★同上、DB へ行かない。
  bool canAdd(Deck deck, String printingId) =>
      _validator.canAdd(deck, printingId);
}
