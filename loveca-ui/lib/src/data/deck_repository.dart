/// デッキの読み書きと検証（決定 D55 / `docs/UI設計メモ.md` §4-1 / §9）.
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない ★★
/// このクラスが返すのは `loveca_core` の型と UI 用の値だけで、drift の型を返さない。
///
/// ★★ `Deck.copyWith` を呼ぶのは [DeckRepository.save] 1 箇所だけである ★★
/// `docs/UI設計メモ.md` §9-1 の
/// 「編集中はドラフトを Store に持ち、保存時に 1 回だけ `copyWith` する」を
/// **規約ではなく構造で守る。** Store が持つのは [DeckDraft] であって `Deck` ではないので、
/// **編集のたびに `revision` が跳ねる経路が存在しない。**
/// ★M4 でカードの増減と並べ替えが入ったが、**同じ形を保っている**
/// （増減も並べ替えも [DeckDraft] の上で起きる）。
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
  const DeckDraft({
    required this.name,
    required this.memo,
    required this.entries,
  });

  DeckDraft.of(Deck deck)
      : name = deck.name,
        memo = deck.memo,
        entries = deck.entries;

  final String name;
  final String memo;

  /// ★保持は printingId 単位（決定 D11）。**並び順はこのリストが持つ。**
  final List<DeckEntry> entries;

  DeckDraft copyWith({String? name, String? memo, List<DeckEntry>? entries}) =>
      DeckDraft(
        name: name ?? this.name,
        memo: memo ?? this.memo,
        entries: entries ?? this.entries,
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
  /// ★★ 並び順を見ない ★★
  /// `deck_entries` に順序列が無いため**並び順は保存できない**（決定 D65）。
  /// 見てしまうと「並べ替えただけで保存ボタンが光り、押しても何も変わらない」
  /// ——**保存したのに戻る**という最悪の形になる。
  /// 並べ替えたこと自体は縮退（`DeckOrderNotPersisted`）として別に見せる。
  bool isDirtyAgainst(Deck deck) =>
      name != deck.name ||
      memo != deck.memo ||
      !mapEquals(countsByPrintingId, DeckDraft.of(deck).countsByPrintingId);

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
        tags: base.tags,
        coverPrintingId: base.coverPrintingId,
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

  /// ★★ 開き直したときの並び（決定 D65）★★
  /// 区分順（メンバー → ライブ → エネルギー → 未知）、各区分内は `printingId` 昇順。
  ///
  /// 2 つの役目がある。
  /// 1. **開いた直後の並びを決定的にする。** `DeckDao.all` は entries に
  ///    `ORDER BY` を持たず、`DeckDao.byId` は `ORDER BY printing_id`。
  ///    R2 は `all()` の `Deck` を R3 へ渡すので、**経路で並びが違う**
  ///    （`ルール整合性チェック_v1.06.md` D-11）。ここで正規化して画面に持ち込まない。
  /// 2. **「開き直すとこうなる」を先に言うため。** `printing_id` 昇順という
  ///    `byId` の並びを区分ごとに再現しているので、予告が実際と一致する。
  List<DeckEntry> normalizedEntries(List<DeckEntry> entries) {
    int rank(DeckEntry e) => switch (cardTypeOf(e.printingId)) {
          CardType.member => 0,
          CardType.live => 1,
          CardType.energy => 2,
          null => 3,
        };
    return [...entries]..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.printingId.compareTo(b.printingId);
      });
  }

  /// 開いた直後のドラフト。★並びを正規化する（上記）。
  DeckDraft draftOf(Deck deck) => DeckDraft(
        name: deck.name,
        memo: deck.memo,
        entries: normalizedEntries(deck.entries),
      );

  /// ドラフトの**画面に見えている並び**が「開き直したときの並び」と違うか（決定 D65）。
  ///
  /// ★★ 平坦なリストを比べてはいけない ★★
  /// 画面は区分ごとに分けて出す（）ので、
  /// **区分をまたいで足しただけでは見た目の並びは変わらない。**
  /// 平坦なリストで比べると、エネルギーの次にメンバーを足した瞬間に
  /// 「並べ替えました」と出てしまう。★実機確認（M4）で実際に出た。
  /// 比べるのは**各区分の中が printingId 昇順かどうか**である。
  bool isReordered(DeckDraft draft) {
    final sections = sectionsOf(draft.entries);
    bool ascending(List<DeckEntry> entries) {
      final ids = entries.map((e) => e.printingId).toList();
      return listEquals(ids, [...ids]..sort());
    }

    return !(ascending(sections.members) &&
        ascending(sections.lives) &&
        ascending(sections.energies) &&
        ascending(sections.unknown));
  }
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
  /// `Deck.copyWith` の `revision: revision ?? this.revision + 1` を
  /// **ここでしか踏まない**。編集操作の回数では増えない。
  ///
  /// ★★ 並び順は保存されない（決定 D65）★★
  /// `deck.entries` の順で書き込むが、`deck_entries` に順序列が無く
  /// `DeckDao.byId` が `ORDER BY printing_id` で読み戻すため、開き直すと戻る。
  /// **画面がそれを予告している**（`DeckOrderNotPersisted`）。
  Future<Deck> save(Deck base, DeckDraft draft) =>
      guardRepository('deck.save', () async {
        final next = base.copyWith(
          name: draft.name,
          memo: draft.memo,
          entries: draft.entries,
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

  List<DeckEntry> normalizedEntries(List<DeckEntry> entries) =>
      _view.normalizedEntries(entries);

  DeckDraft draftOf(Deck deck) => _view.draftOf(deck);

  bool isReordered(DeckDraft draft) => _view.isReordered(draft);
}
