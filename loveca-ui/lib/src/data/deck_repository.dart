/// デッキの読み書きと検証（決定 D55 / `docs/UI設計メモ.md` §4-1 / §9）.
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない ★★
/// このクラスが返すのは `loveca_core` の型と UI 用の値だけで、drift の型を返さない。
///
/// ★★ `Deck` を作り直すのは [DeckRepository.save] 1 箇所だけである ★★
/// `docs/UI設計メモ.md` §9-1 の
/// 「編集中はドラフトを Store に持ち、保存時に 1 回だけ組み直す」を
/// **規約ではなく構造で守る。** Store が持つのは [DeckDraft] であって `Deck` ではないので、
/// **編集のたびに `revision` が跳ねる経路が存在しない。**
/// ★M4 でカードの増減と並べ替えが入ったが、**同じ形を保っている**
/// （増減も並べ替えも [DeckDraft] の上で起きる）。
///
/// ★★ 2026-08-24 訂正（`ルール整合性チェック_v1.06.md` D-15 (c)）★★
/// ここには「`Deck.copyWith` を呼ぶのは `save` **1 箇所だけ**」と書いてあったが、
/// 決定 D70 で [DeckRepository.save] を**明示コンストラクタ**にしたので
/// **`loveca-ui/lib` からの `Deck.copyWith` の呼び出しは 0 箇所**である。
/// ★このファイルの下のほう（`save` の doc）が既に「0 件になり」と書いており、
/// **1 ファイルの中で正反対のことを書いていた。**先に読まれるのはこの library doc なので、
/// 片方だけ読んだ人が誤る。**直すときは 2 箇所を必ず同時に見ること。**
///
/// ★★ `Deck.copyWith` の既定値違反そのものは `loveca_core` に残っている（D-14）★★
/// UI から踏む経路が消えただけで、Phase 6 のサーバや Phase 4 の同期は踏みうる。
///
/// ★★ `updatedAt` を必ず明示的に渡す ★★
/// `Deck.copyWith` の既定値は `DateTime.now().toUtc()`（CLAUDE.md §1 の既知違反）。
/// 呼び出し側から渡せばその影響を受けない。供給元は [Clock]（§9-1）。
library;

import 'package:flutter/foundation.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import 'card_list_row.dart';
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
///
/// ★★ [entries] の不変条件: 同じ printingId を 2 行にしない ★★
/// `deck_entries` の主キーが `{deckId, printingId}`（`tables.dart:296`）なので、
/// 2 行あると保存時に主キー衝突で落ちる。増やすときは行を足さず枚数を足す。
/// その一点を守るために、増減は必ずこのクラスのメソッドを通す。
class DeckDraft {
  /// ★★ [entries] を必須にしてある（既定値を持たせない）★★
  /// `DeckDraft(name: ..., memo: ...)` と書けてしまうと、
  /// **名前だけ変えたつもりで中身を空にして保存する**経路ができる。
  /// 保存は `entries` をそのまま書き戻すので、これは痕跡を残さないデータ消失になる。
  /// 既存のデッキから作るときは [DeckDraft.of] か `DeckRepository.draftOf` を使う。
  ///
  /// ★★ [tags] / [coverPrintingId] も「書き戻される」側である（M6 / 決定 D70）★★
  /// `DeckRepository.save` は `copyWith` ではなく明示コンストラクタで畳むので、
  /// **ドラフトが持っていないメタは消える。**
  /// 既定値を許してあるのは、メタの欠落は画面で見えるからであって
  /// 「保存に関係しない」からではない。
  /// ★既存のデッキを編集するときは必ず [DeckDraft.of] / `draftOf` から作ること。
  const DeckDraft({
    required this.name,
    required this.memo,
    required this.entries,
    this.tags = const [],
    this.coverPrintingId,
  });

  DeckDraft.of(Deck deck)
      : name = deck.name,
        memo = deck.memo,
        entries = deck.entries,
        tags = deck.tags,
        coverPrintingId = deck.coverPrintingId;

  final String name;
  final String memo;

  /// ★保持は printingId 単位（決定 D11）。**並び順はこのリストが持つ。**
  final List<DeckEntry> entries;

  /// P3 のメタ編集（M6）。★`deck_tags` に `ord` つきで保存される。
  final List<String> tags;

  /// P3 のメタ編集（M6）。★デッキの中のカードから選ぶ。無ければ null。
  final String? coverPrintingId;

  /// ★★ [clearCover] が要る理由 ★★
  /// `coverPrintingId ?? this.coverPrintingId` だけだと**外す手段が無い。**
  /// カバーに選んだカードをデッキから抜いても宙に浮いたまま残る。
  DeckDraft copyWith({
    String? name,
    String? memo,
    List<DeckEntry>? entries,
    List<String>? tags,
    String? coverPrintingId,
    bool clearCover = false,
  }) =>
      DeckDraft(
        name: name ?? this.name,
        memo: memo ?? this.memo,
        entries: entries ?? this.entries,
        tags: tags ?? this.tags,
        coverPrintingId:
            clearCover ? null : (coverPrintingId ?? this.coverPrintingId),
      );

  /// printingId -> 枚数。★保存されるのはこの形であって、並び順ではない（決定 D65）。
  Map<String, int> get countsByPrintingId =>
      {for (final e in entries) e.printingId: e.count};

  int get totalCount => entries.fold(0, (sum, e) => sum + e.count);

  int countOf(String printingId) => entries
      .where((e) => e.printingId == printingId)
      .fold(0, (sum, e) => sum + e.count);

  /// 保存済みの [deck] と違いがあるか。保存ボタンの活性はこれで決める。
  ///
  /// ★★ 並び順を見る（決定 D99）★★
  /// D65 の手当て 4 は「並べ替えでは保存ボタンを光らせない」だった。理由は
  /// **押せると「保存したのに戻る」という最悪の形になる**こと。
  /// `deck_entries` に `ord` が入って**保存されるようになったので、前提が反転した。**
  /// 今度は**光らせないほうが**「並べ替えたのに保存できない」になる。
  ///
  /// ★★ 枚数の Map ではなく「並び + 枚数」の列で比べる ★★
  /// `countsByPrintingId` は `Map` なので順序を落とす。
  bool isDirtyAgainst(Deck deck) =>
      name != deck.name ||
      memo != deck.memo ||
      coverPrintingId != deck.coverPrintingId ||
      !listEquals(tags, deck.tags) ||
      !listEquals(_orderedCounts, DeckDraft.of(deck)._orderedCounts);

  /// 並びと枚数をまとめて比べるための列。★`DeckEntry` に `==` が無いので作る。
  List<String> get _orderedCounts =>
      [for (final e in entries) '${e.printingId}\u0000${e.count}'];

  /// 名前が空白だけなら保存させない（`decks.name` は NOT NULL だが空は入る）。
  bool get isValid => name.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // 増減と並べ替え（★不変条件を守る唯一の入口）
  // ---------------------------------------------------------------------------

  /// 1 枚足す。すでにあれば枚数を +1 する（**行を増やさない**）。
  ///
  /// [before] を渡すとその printingId の**直前**に差し込む。
  /// 新しい行にだけ効く（すでにある行は位置を変えない——枚数が変わっただけなので）。
  DeckDraft addCopy(String printingId, {String? before}) {
    final next = [...entries];
    final i = next.indexWhere((e) => e.printingId == printingId);
    if (i >= 0) {
      next[i] = next[i].copyWith(count: next[i].count + 1);
      return copyWith(entries: next);
    }
    final entry = DeckEntry(printingId: printingId, count: 1);
    final at =
        before == null ? -1 : next.indexWhere((e) => e.printingId == before);
    if (at < 0) {
      next.add(entry);
    } else {
      next.insert(at, entry);
    }
    return copyWith(entries: next);
  }

  /// 1 枚減らす。0 になったら行ごと消す。
  DeckDraft removeCopy(String printingId) {
    final next = [...entries];
    final i = next.indexWhere((e) => e.printingId == printingId);
    if (i < 0) return this;
    if (next[i].count <= 1) {
      next.removeAt(i);
    } else {
      next[i] = next[i].copyWith(count: next[i].count - 1);
    }
    return copyWith(entries: next);
  }

  /// 行ごと消す（ゴミ箱）。
  DeckDraft removeEntry(String printingId) => copyWith(
        entries: entries.where((e) => e.printingId != printingId).toList(),
      );

  /// [printingId] を [target] の前／後ろへ動かす。
  ///
  /// ★保存されない（決定 D65）。画面の中だけの並び。
  DeckDraft moveEntry(String printingId, String target, {required bool after}) {
    if (printingId == target) return this;
    final next = [...entries];
    final from = next.indexWhere((e) => e.printingId == printingId);
    if (from < 0) return this;
    final moved = next.removeAt(from);
    final to = next.indexWhere((e) => e.printingId == target);
    if (to < 0) return this;
    next.insert(after ? to + 1 : to, moved);
    return copyWith(entries: next);
  }
}

/// カタログから引けるものだけを持つ（決定 D55）.
///
/// ★★ このクラスは `LovecaDatabase` を知らない ★★
/// 「検証と区分は DB へ行かない」を**規約ではなく型で示すために分けてある。**
/// ここに置いたメソッドは、DB を閉じたあとでも必ず答えられる
/// （`test/data/deck_repository_test.dart` がそれを機械的に固定している）。
///
/// ★ウィジェットテストのフェイクもこれをそのまま使う。
/// フェイク側で導出を書き直すと、**本実装と黙って食い違う。**
class DeckCatalogView {
  DeckCatalogView(MasterCatalog catalog)
      : _cards = catalog.cards,
        _printings = catalog.printings,
        _rows = {for (final r in catalog.rows) r.printingId: r},
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

  final Map<String, Card> _cards;
  final Map<String, Printing> _printings;
  final Map<String, CardListRow> _rows;
  final DeckValidator _validator;

  // ---------------------------------------------------------------------------
  // 検証（★すべて同期。DB へ行かない / 決定 D55）
  // ---------------------------------------------------------------------------

  /// 総合ルール 6.1 の検証。
  ///
  /// ★★ 同期メソッドである。DB へ行かない（決定 D55）★★
  /// 材料は起動時に組んだ `MasterCatalog` の中にあり、判定そのものは
  /// `loveca_core` の `DeckValidator`（PC・スマホ・サーバで唯一の実装 / 決定 D28）。
  DeckValidationResult validate(Deck deck) => _validator.validate(deck);

  /// 編集中のドラフトを検証する（M4）。
  ///
  /// ★★ `copyWith` を使わない ★★
  /// 検証は編集のたびに走る。`copyWith` を通すと `revision` がその回数だけ跳ね、
  /// **保存もしていないのに Phase 4 の同期で「大量に更新された」ように見える。**
  /// ここで作る `Deck` は**検証のためだけの一時値**で、`revision` / `updatedAt` は
  /// [base] の値をそのまま持つ。保存はしない。
  DeckValidationResult validateDraft(Deck base, DeckDraft draft) =>
      _validator.validate(_draftView(base, draft));

  /// 追加可能かの事前判定（デッキ編集で「+」を無効化するために使う）。
  /// ★同上、DB へ行かない。
  bool canAdd(Deck deck, String printingId) =>
      _validator.canAdd(deck, printingId);

  /// 同上をドラフトに対して行う（M4）。★`copyWith` を使わない。
  bool canAddToDraft(Deck base, DeckDraft draft, String printingId) =>
      _validator.canAdd(_draftView(base, draft), printingId);

  /// ★検証専用の一時値。**保存しない / `copyWith` を通さない。**
  Deck _draftView(Deck base, DeckDraft draft) => Deck(
        deckId: base.deckId,
        name: draft.name,
        entries: draft.entries,
        memo: draft.memo,
        tags: draft.tags,
        coverPrintingId: draft.coverPrintingId,
        createdAt: base.createdAt,
        // ★動かさない。時刻も版も編集では変わらない。
        updatedAt: base.updatedAt,
        deletedAt: base.deletedAt,
        revision: base.revision,
        lastDeviceId: base.lastDeviceId,
        masterDataVersion: base.masterDataVersion,
      );

  // ---------------------------------------------------------------------------
  // 表示のための導出（★カタログから。DB へ行かない / 決定 D55）
  // ---------------------------------------------------------------------------

  /// 総合ルール 6.1 の区分に分ける（決定 D41: 区分は `card_type` から導出する）。
  ///
  /// ★★ `DeckDao.sections` を呼ばない ★★
  /// あちらは呼ぶたびに `printingsById()` + `cardsByNumber()` を引き直す
  /// （実測 40〜60ms）。編集のたびに走るので、UI isolate で払い続けることになる。
  /// 導出そのものはルールではなく写像なので（判定は `DeckValidator` が唯一 / 決定 D28）、
  /// カタログから同じ写像を引いてよい。**型は `loveca_db` の値型を借りる**
  /// （`CardSearchResult` を UI で使っているのと同じ扱い。drift の型ではない）。
  ///
  /// ★リスト内の順序は [entries] の順を保つ。
  DeckSections sectionsOf(List<DeckEntry> entries) {
    final members = <DeckEntry>[];
    final lives = <DeckEntry>[];
    final energies = <DeckEntry>[];
    final unknown = <DeckEntry>[];

    for (final entry in entries) {
      switch (cardTypeOf(entry.printingId)) {
        case CardType.member:
          members.add(entry);
        case CardType.live:
          lives.add(entry);
        case CardType.energy:
          energies.add(entry);
        case null:
          // ★決定 D35: 黙って捨てない。呼び出し側に見せる。
          unknown.add(entry);
      }
    }

    return DeckSections(
      members: members,
      lives: lives,
      energies: energies,
      unknown: unknown,
    );
  }

  /// 刷りの区分。マスタに無ければ null（決定 D35）。
  CardType? cardTypeOf(String printingId) {
    final printing = _printings[printingId];
    if (printing == null) return null;
    return _cards[printing.cardNumber]?.cardType;
  }

  /// 一覧と同じ投影行（決定 D48）。マスタに無ければ null。
  CardListRow? rowOf(String printingId) => _rows[printingId];

  /// 並びの規則（**決定 D99**）に要る値を引く。
  ///
  /// ★★ 規則そのものはここに書かない ★★
  /// 比較器は `loveca_core` の `compareDeckOrder` 1 つだけで、
  /// `loveca_db` の backfill も**同じものを呼ぶ**（決定 D99）。
  /// ここが持つのは「引き方」だけである。
  DeckOrderKey deckOrderKeyOf(String printingId) {
    final printing = _printings[printingId];
    final card = printing == null ? null : _cards[printing.cardNumber];
    if (card == null) return DeckOrderKey.unknown;
    return DeckOrderKey(
      cardType: card.cardType,
      cost: card.cost,
      score: card.score,
    );
  }

  /// 規則順に並べ替える（決定 D99）。
  ///
  /// ★★ 開いた直後には呼ばない ★★
  /// `ord` が保存されるようになったので（決定 D65 / D99 / `schemaVersion` 3）、
  /// **開いた直後の並びは DB が持っている。** 以前ここにあった
  /// `normalizedEntries` は、順序列が無かった時代に
  /// 「取得経路で並びが違う」（**D-11**）を画面へ持ち込まないための正規化だった。
  /// **経路差は `DeckDao` 側で解消済み**なので、正規化そのものが要らない。
  ///
  /// 呼ぶのは**利用者が「規則順に戻す」を押したとき**だけである。
  List<DeckEntry> sortedByRule(List<DeckEntry> entries) =>
      sortedByDeckOrder(entries, deckOrderKeyOf);

  /// [printingId] を規則順に差し込む位置（決定 D99）。
  ///
  /// ★手動順が混ざったデッキでは「規則順の正しい位置」とは限らない
  /// （`deckOrderInsertionIndex` の doc）。
  int insertionIndexOf(List<DeckEntry> entries, String printingId) =>
      deckOrderInsertionIndex(entries, printingId, deckOrderKeyOf);

  /// 開いた直後のドラフト。★並びは DB から来たものをそのまま使う（上記）。
  DeckDraft draftOf(Deck deck) => DeckDraft(
        name: deck.name,
        memo: deck.memo,
        entries: deck.entries,
        tags: deck.tags,
        coverPrintingId: deck.coverPrintingId,
      );
}

/// デッキの読み書き。★カタログだけで済む分は [DeckCatalogView] へ預ける。
class DeckRepository {
  DeckRepository(
    this._db, {
    required MasterCatalog catalog,
    required Clock clock,
    DeckIdGenerator newDeckId = randomDeckIdV4,
  })  : _clock = clock,
        _newDeckId = newDeckId,
        _dataVersion = catalog.dataVersion,
        _view = DeckCatalogView(catalog);

  final LovecaDatabase _db;
  final Clock _clock;
  final DeckIdGenerator _newDeckId;
  final int _dataVersion;
  final DeckCatalogView _view;

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
  /// 編集操作の回数では増えない。ドラフトは `Deck` を持たないので、
  /// **編集のたびに版が跳ねる経路が構造的に存在しない**（§9-1）。
  ///
  /// ★★ `copyWith` を使わない（決定 D70 / M6）★★
  /// `Deck.copyWith` は `coverPrintingId ?? this.coverPrintingId`
  /// （`loveca-core/lib/src/entities/deck.dart:94`）なので
  /// **カバーを外せない。** P3（M6）でカバーの編集口を作る以上、外す口が要る。
  ///
  /// 明示コンストラクタにしても §9-1 の性質は全部残る——
  /// 保存 1 回 = `revision` +1 / `updatedAt` は [Clock] から /
  /// 畳む場所はここ 1 箇所。★副次的に **`Deck.copyWith` の呼び出し元が
  /// UI から 0 件になり**、CLAUDE.md §1 の既知違反（既定値の
  /// `DateTime.now().toUtc()`）に**触れる経路そのものが消える。**
  ///
  /// ★★ ただし違反は `loveca_core` に残っている ★★
  /// Phase 6 のサーバや将来の呼び出し元は踏みうる。**解消済みではない**
  /// （`ルール整合性チェック_v1.06.md` D-14 / D-9・D-5 と同じ扱い）。
  ///
  /// ★★ コンストラクタの代償は「フィールドの書き漏らし」である ★★
  /// `copyWith` は書かなかったフィールドを自動で引き継ぐが、
  /// コンストラクタは書き忘れると既定値になる。
  /// → `test/data/deck_repository_test.dart` が **`Deck.toJson()` の
  /// キー集合を凍結**しており、`Deck` にフィールドが増えると落ちる。
  ///
  /// ★★ 並び順は保存されない（決定 D65）★★
  /// `deck.entries` の順で書き込むが、`deck_entries` に順序列が無く
  /// `DeckDao.byId` が `ORDER BY printing_id` で読み戻すため、開き直すと戻る。
  /// **画面がそれを予告している**（`DeckOrderNotPersisted`）。
  Future<Deck> save(Deck base, DeckDraft draft) =>
      guardRepository('deck.save', () async {
        final next = Deck(
          deckId: base.deckId,
          name: draft.name,
          entries: draft.entries,
          memo: draft.memo,
          tags: draft.tags,
          coverPrintingId: draft.coverPrintingId,
          createdAt: base.createdAt,
          // ★Clock から供給する（§9-1）。既定値の DateTime.now() を踏まない。
          updatedAt: _clock(),
          deletedAt: base.deletedAt,
          // ★保存 1 回につき 1 度だけ。ここが唯一の +1 である（P2）。
          revision: base.revision + 1,
          lastDeviceId: base.lastDeviceId,
          masterDataVersion: base.masterDataVersion,
        );
        await DeckDao(_db).save(next);
        return next;
      });

  /// デッキを複製する（決定 D71 / M6）。
  ///
  /// ★★ 共有形式の代わりにはならない ★★
  /// 共有形式は `Map<cardNumber, 枚数>` なので**刷りの違いが潰れる**
  /// （同じ cardNumber の `-SD` と `-SD2` が合算される / 決定 D67）。
  /// 複製は**刷りを保ったまま写せる唯一の手段**である。
  ///
  /// ★★ `masterDataVersion`（P5）は元の値を引き継ぐ ★★
  /// P5 は「作成時のカードマスタ版。未知カード検出に使う」。
  /// 現在版を打つと、元デッキが持つ**未知の刷り**が
  /// 「今の版で作ったのに未知」という説明不能な状態になり、P5 の用途を壊す。
  /// ★[create] が現在版を打つのは**中身が空だから**であって、矛盾しない。
  ///
  /// ★★ 未知の刷りもそのまま写す（決定 D35）★★
  /// 落とすと、元デッキを消したときに未知カードが消える。
  Future<Deck> duplicate(Deck source, {required String name}) =>
      guardRepository('deck.duplicate', () async {
        final now = _clock();
        final copy = Deck(
          deckId: _newDeckId(),
          name: name,
          entries: source.entries,
          memo: source.memo,
          tags: source.tags,
          coverPrintingId: source.coverPrintingId,
          createdAt: now,
          updatedAt: now,
          // ★新しく作ったデッキ。create と揃える。
          revision: 0,
          lastDeviceId: source.lastDeviceId,
          masterDataVersion: source.masterDataVersion,
        );
        await DeckDao(_db).save(copy);
        return copy;
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
  Future<void> softDelete(String deckId) => guardRepository(
        'deck.softDelete',
        () => DeckDao(_db).softDelete(deckId, _clock()),
      );

  // ---------------------------------------------------------------------------
  // 検証と導出（★[DeckCatalogView] へそのまま通す。DB へ行かない / 決定 D55）
  // ---------------------------------------------------------------------------

  /// カタログだけで答えられる部分。★DB を閉じても動くことの実体。
  DeckCatalogView get catalogView => _view;

  DeckValidationResult validate(Deck deck) => _view.validate(deck);

  DeckValidationResult validateDraft(Deck base, DeckDraft draft) =>
      _view.validateDraft(base, draft);

  bool canAdd(Deck deck, String printingId) => _view.canAdd(deck, printingId);

  bool canAddToDraft(Deck base, DeckDraft draft, String printingId) =>
      _view.canAddToDraft(base, draft, printingId);

  DeckSections sectionsOf(List<DeckEntry> entries) => _view.sectionsOf(entries);

  CardType? cardTypeOf(String printingId) => _view.cardTypeOf(printingId);

  CardListRow? rowOf(String printingId) => _view.rowOf(printingId);

  DeckDraft draftOf(Deck deck) => _view.draftOf(deck);

  /// 決定 D99。★呼ぶのは「規則順に戻す」を押したときだけ。
  List<DeckEntry> sortedByRule(List<DeckEntry> entries) =>
      _view.sortedByRule(entries);

  /// 決定 D99。★カードを足すときの挿入位置。
  int insertionIndexOf(List<DeckEntry> entries, String printingId) =>
      _view.insertionIndexOf(entries, printingId);
}
