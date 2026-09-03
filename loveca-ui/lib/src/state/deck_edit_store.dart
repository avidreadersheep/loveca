/// R3 デッキ編集の状態（決定 D53 / `docs/UI設計メモ.md` §9-1）.
///
/// ★★ 編集中はドラフトだけを持ち、`Deck` に触れない ★★
/// `Deck.copyWith` は `revision: revision ?? this.revision + 1` なので、
/// 操作のたびに呼ぶと `revision` が跳ね、Phase 4 の同期で
/// 「大量に更新された」ように見える。
/// この Store が持つのは [DeckDraft] であり、`Deck` になるのは
/// `DeckRepository.save` を通った瞬間だけである。
///
/// ★★ M4 でカードの増減と並べ替えが入ったが、同じ形を保っている ★★
/// 増減も並べ替えも [DeckDraft] の上で起きる。**枚数を 1 枚増やしても
/// `revision` は動かない。** 検証（`validateDraft`）も `copyWith` を通さない。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import '../data/card_list_row.dart';
import '../data/deck_repository.dart';
import '../ui/common/card_drag.dart';
import 'deck_edit_degradation.dart';
import 'store.dart';

class DeckEditState {
  const DeckEditState({
    required this.saved,
    required this.draft,
    required this.validation,
    required this.sections,
    required this.degradations,
    this.busy = false,
    this.actionError,
    this.deleted = false,
  });

  /// ★DB に入っている姿。保存が通った時点で差し替わる。
  final Deck saved;

  /// ★まだ保存されていない値。
  final DeckDraft draft;

  /// 総合ルール 6.1 の検証結果。
  ///
  /// ★`DeckRepository.validateDraft` は同期で DB へ行かない（決定 D55）。
  /// 材料は起動時に組んだ `MasterCatalog` にある。
  final DeckValidationResult validation;

  /// 区分（決定 D41: `card_type` から導出）。★並びは [draft] の順を保つ。
  final DeckSections sections;

  /// ★エラーではないが結果が完全でないこと（決定 D65 / D35）。
  final List<DeckEditDegradation> degradations;

  final bool busy;
  final (Object error, StackTrace stackTrace)? actionError;

  /// 論理削除済み。画面はこれを見て閉じる。
  final bool deleted;

  bool get isDirty => draft.isDirtyAgainst(saved);

  /// 保存ボタンの活性。★変更が無ければ押させない（無意味な `revision` +1 を防ぐ）。
  ///
  /// ★★ 並べ替えただけでも活性になる（決定 D99）★★
  /// `deck_entries` に `ord` が入って**並びが保存される**ようになったので、
  /// `DeckDraft.isDirtyAgainst` は**並びを見る**。
  ///
  /// ★★ ここには 2026-08-29 まで逆のことが書いてあった ★★
  /// 「並べ替えただけでは活性にならない」「並び順は保存できない（決定 D65）」
  /// 「並べ替えは縮退として別に見せる」の 3 つで、**書かれた時点では正しかった。**
  /// 決定 D99（`schemaVersion` 3 / 2026-08-27）で前提が反転し、予告の縮退も
  /// 撤去された（`state/deck_edit_degradation.dart` が記録している）。
  /// ★経緯の正は `data/deck_repository.dart` の `save` の doc（2026-08-28 の訂正）。
  /// ★★ 同じ型が同時に 5 箇所あり、2026-08-28 はそのうち 1 箇所だけを直していた ★★
  /// ★型は `ルール整合性チェック_v1.06.md` **D-15 (l)**。★**走査では出ない。**
  bool get canSave => isDirty && draft.isValid && !busy;

  DeckEditState copyWith({
    Deck? saved,
    DeckDraft? draft,
    DeckValidationResult? validation,
    DeckSections? sections,
    List<DeckEditDegradation>? degradations,
    bool? busy,
    bool clearActionError = false,
    (Object, StackTrace)? actionError,
    bool? deleted,
  }) =>
      DeckEditState(
        saved: saved ?? this.saved,
        draft: draft ?? this.draft,
        validation: validation ?? this.validation,
        sections: sections ?? this.sections,
        degradations: degradations ?? this.degradations,
        busy: busy ?? this.busy,
        actionError:
            clearActionError ? null : (actionError ?? this.actionError),
        deleted: deleted ?? this.deleted,
      );
}

/// カードを足せなかった理由（★黙って何も起きない状態にしない）。
///
/// ドラッグで落としたときは「+」と違ってボタンの活性で止められないので、
/// **受け取ったうえで理由を返す。**
enum AddCardRefusal {
  /// 総合ルール 6.1.1.3: エネルギーデッキは 12 枚。
  ///
  /// ★★ 2026-09-03: `tooManyCopies` を消した ★★
  /// `docs/Android UI 決定.md` §1-3 —— ★4 枚制限（6.1.1.2）で**止めなくなった**ので、
  /// ★★この値を返す経路が 1 本も残らなかった★★（**D-20** —— ★消費者の居ない値を置かない）。
  /// ★**警告は `DeckValidator.validate` の `tooManyCopies` が出す**（★そちらは 1 文字も動いていない）。
  energyDeckFull,

  /// カードマスタに無い刷り（決定 D35）。
  unknownPrinting,
}

class DeckEditStore extends Store<DeckEditState> {
  DeckEditStore(DeckRepository repository, Deck deck)
      : _repository = repository,
        super(_initialState(repository, deck));

  static DeckEditState _initialState(DeckRepository repository, Deck deck) {
    // ★★ 開いた直後の並びは DB のものをそのまま使う（決定 D99）★★
    //   以前はここで正規化していた。`DeckDao.all` が entries に ORDER BY を
    //   持たず、経路で並びが違ったため（**D-11**）。
    //   `ord` の導入（`schemaVersion` 3）で**経路差が DAO 側で解消された**ので、
    //   画面で並べ直す理由が無くなった。
    //   ★並べ直すと、利用者が保存した手動順が**開くたびに消える。**
    final draft = repository.draftOf(deck);
    return DeckEditState(
      saved: deck,
      draft: draft,
      validation: repository.validateDraft(deck, draft),
      sections: repository.sectionsOf(draft.entries),
      degradations: _degradationsOf(repository, deck, draft),
    );
  }

  static List<DeckEditDegradation> _degradationsOf(
    DeckRepository repository,
    Deck saved,
    DeckDraft draft,
  ) {
    final validation = repository.validateDraft(saved, draft);
    return [
      // ★★ 起きたときだけ出す ★★
      //   常に出すと「なんか出てる」で無視される。
      // ★2026-08-27: 並べ替えの縮退は撤去した（決定 D99）。並びは保存される。
      if (validation.hasUnknownCards)
        DeckUnknownPrintings(validation.unknownPrintingIds.length),
    ];
  }

  final DeckRepository _repository;

  // ---------------------------------------------------------------------------
  // 編集ログ（決定 **D110-1** / 記録点は **D110-2** / `docs/同期設計メモ.md` §17-9-2）
  // ---------------------------------------------------------------------------

  /// まだ保存されていない操作の列。
  ///
  /// ★★ なぜ [DeckEditState] に置かないか ★★
  /// 画面はこれを 1 度も読まない。状態に置くと**消費者が 1 人もいない公開フィールド**が
  /// できる（**D-20** の型）。★**読むのは [save] だけ**なので private に閉じる。
  ///
  /// ★★ いつ書くか —— **保存の時点**である（§17-9-2 の 3）★★
  /// 9 操作は `_apply` でドラフトを差し替えるだけで **DB に 1 行も書かない**ので、
  /// ★**ログも同じ時点に揃える。**→ `DeckDao.save` が本体と**同じトランザクション**で
  /// 書く（**D110-3** が `softDelete` で採ったのと同じ形）。
  /// ★**「操作のたびに書く」は採らなかった** —— ★保存前に閉じた編集が DB に残り、
  /// ★**ドラフトの性質（保存しなければ元に戻せる）と食い違う**（`replaceEntries` の doc）。
  ///
  /// ★★ いつ捨てるか —— **保存が通ったときだけ**である ★★
  /// 失敗したら **DAO のトランザクションごと巻き戻る**ので、ログも本体も残らない。
  /// ★そこで捨てると、★**やり直した保存が本体だけを書いてログを落とす** ——
  /// ★**穴 (c) と同じ形**（`decks` は動いたのに検出層が見ない）を自分で作ることになる。
  /// → ★**捨てない。★次の保存が持っていく。**
  ///
  /// ★★ 保存を通らなかった操作は載らない ★★
  /// [save] は `canSave`（変更が在り、名前が空でない）で門を張る。
  /// ★**名前を変えて戻すと `isDirty` が false になり、記録は書かれないまま残る。**
  /// ★**これは「いつ書くか」の帰結であって、新しい判断ではない** ——
  /// 画面を閉じればドラフトごと消える（★R3 には巻き戻しの口が無い。★下の [save] の doc）。
  final List<DeckEditOpRecord> _pendingOps = [];

  /// 操作を 1 件貯める。
  ///
  /// ★★ `_apply` の中に置かない ★★
  /// `_apply` は「何をしたか」を知らない（ドラフトを丸ごと受け取るだけ）。
  /// ★**種類は呼び出し元だけが持っている**ので、9 箇所から名指しで呼ぶ。
  /// → ★**1 つ書き忘れると、その 1 つだけが記録されなくなる**（★テストが 1 件ずつ見る）。
  ///
  /// ★★ 引数は持たせない（§17-9-2 の 2 / 4 は未決）★★
  /// [DeckEditOpRecord] は `kind` と `at` だけを持つ。★とくに [sortByRule] は
  /// ★**「規則順に戻した」という事実だけ**で、★**どの規則かは書かない**
  /// （★書くと (f-3) の軸 B を倒す / §13-5）。
  void _record(DeckEditOpKind kind) =>
      // ★時刻は [Clock] から（§9-1）。★操作が起きた時刻であって保存時刻ではない。
      _pendingOps.add((kind: kind, at: _repository.now()));

  // ---------------------------------------------------------------------------
  // ドラフトの差し替え（★ここを通さない書き換えを作らない）
  // ---------------------------------------------------------------------------

  /// ★★ 保存しない。`Deck.copyWith` も呼ばない ★★
  /// ここで `Deck` を作ると `revision` が操作 1 回ごとに +1 される。
  void _apply(DeckDraft next) {
    state = value.copyWith(
      draft: next,
      validation: _repository.validateDraft(value.saved, next),
      sections: _repository.sectionsOf(next.entries),
      degradations: _degradationsOf(_repository, value.saved, next),
    );
  }

  void setName(String name) {
    _record(DeckEditOpKind.setName);
    _apply(value.draft.copyWith(name: name));
  }

  void setMemo(String memo) {
    _record(DeckEditOpKind.setMemo);
    _apply(value.draft.copyWith(memo: memo));
  }

  /// 共有形式から取り込んだ中身で置き換える（M6 / 決定 D67）。
  ///
  /// ★★ 保存しない ★★
  /// ドラフトを差し替えるだけなので、**保存しなければ元に戻せる。**
  /// だからダイアログで「置き換えます」と言い切れる。
  ///
  /// ★合算しない。合算すると 4 枚超過が起きやすく、しかも戻せない。
  void replaceEntries(List<DeckEntry> entries) {
    _record(DeckEditOpKind.replaceEntries);
    _apply(value.draft.copyWith(entries: entries));
  }

  /// P3 のメタ編集（M6）。★`_apply` を通すので `revision` は動かない。
  void applyMeta(DeckDraft meta) {
    _record(DeckEditOpKind.applyMeta);
    _apply(
      value.draft.copyWith(
        name: meta.name,
        memo: meta.memo,
        tags: meta.tags,
        coverPrintingId: meta.coverPrintingId,
        // ★外すのも編集のうち。渡さないと片道になる。
        clearCover: meta.coverPrintingId == null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // カードの増減（M4）
  // ---------------------------------------------------------------------------

  /// 行の表示に使う投影（決定 D48）。マスタに無ければ null（決定 D35）。
  ///
  /// ★画面が `MasterCatalog` を直接持たないための口。
  /// リポジトリより下（DAO / drift）へは行かない（決定 D55）。
  CardListRow? rowOf(String printingId) => _repository.rowOf(printingId);

  /// 追加できるか（「+」の活性）。★DB へ行かない（決定 D55）。
  bool canAdd(String printingId) =>
      _repository.canAddToDraft(value.saved, value.draft, printingId);

  /// 1 枚足す。足せなければ**理由を返す**（null なら成功）。
  ///
  /// [before] を渡すと、**新しく入る行だけ**その手前／後ろへ差し込む。
  /// すでにある行は位置を変えない（枚数が変わっただけなので）。
  ///
  /// ★★ [before] が無いときは規則順の位置へ挿入する（決定 D99）★★
  /// 末尾に足すと、区分をまたいで
  /// 「メンバーの列の下にライブが来て、その下にまたメンバー」になる。
  /// ★**落とし先が指定されているときは利用者の指示が勝つ。**
  /// ★手動順が混ざったデッキでは規則順の正しい位置とは限らない
  /// （`deckOrderInsertionIndex` の doc / 決定 D99）。
  AddCardRefusal? addCard(
    String printingId, {
    String? before,
    DropEdge edge = DropEdge.leading,
  }) {
    if (_repository.cardTypeOf(printingId) == null) {
      return AddCardRefusal.unknownPrinting;
    }
    if (!canAdd(printingId)) {
      // ★★ 2026-09-03: ここへ来るのはエネルギーだけである ★★
      //   ★4 枚制限（6.1.1.2）は `canAdd` が止めなくなった（★申し送り §1-3）。
      //   ★**メンバー / ライブは★何枚でも入り、★検証パネルが警告を出す。**
      return AddCardRefusal.energyDeckFull;
    }

    final existed = value.draft.countOf(printingId) > 0;
    var next = value.draft.addCopy(printingId);
    if (!existed) {
      if (before != null) {
        next =
            next.moveEntry(printingId, before, after: edge == DropEdge.trailing);
      } else {
        // ★規則順の位置 = 「自分より後ろに来る最初の札」。末尾なら動かさない
        //   （`addCopy` が既に末尾へ足している）。
        final entries = value.draft.entries;
        final at = _repository.insertionIndexOf(entries, printingId);
        if (at < entries.length) {
          next = next.moveEntry(printingId, entries[at].printingId, after: false);
        }
      }
    }
    // ★★ 断られたときは記録しない（★上の 2 つの early return より後ろに置く）★★
    //   起きていない編集を履歴に残すと、検出層がそれを配る
    //   （`DeckDao.softDelete` の「当たる行が無ければ記録しない」と同じ形）。
    _record(DeckEditOpKind.addCard);
    _apply(next);
    return null;
  }

  /// 1 枚減らす。0 になったら行ごと消える。
  void removeCopy(String printingId) {
    _record(DeckEditOpKind.removeCopy);
    _apply(value.draft.removeCopy(printingId));
  }

  /// 行ごと消す（ゴミ箱）。
  void removeEntry(String printingId) {
    _record(DeckEditOpKind.removeEntry);
    _apply(value.draft.removeEntry(printingId));
  }

  /// デッキの中で並べ替える。
  ///
  /// ★★ 保存される（決定 D99）★★
  /// `deck_entries.ord` に入るので、`isDirtyAgainst` が並びを見て
  /// **保存ボタンが光る。** 予告（`DeckOrderNotPersisted`）は撤去した。
  void moveEntry(String printingId, String target, DropEdge edge) {
    _record(DeckEditOpKind.moveEntry);
    _apply(
      value.draft
          .moveEntry(printingId, target, after: edge == DropEdge.trailing),
    );
  }

  /// 並び順を規則順に戻す（決定 D99）.
  ///
  /// ★★ これが無いと、一度並べ替えたデッキは二度と規則順に戻らない ★★
  /// `ord` が保存される以上、手動順は永続する。
  /// ★入口は 1 つ・2 段以内（決定 D99。**U27 を繰り返さない**）。
  ///
  /// ★保存はしない。ほかの編集と同じくドラフトを差し替えるだけで、
  /// `revision` は保存 1 回につき +1 のままである（§9-1）。
  void sortByRule() {
    // ★★ 「規則順に戻した」という事実だけを残す。★どの規則かは書かない ★★
    //   規則の名前で残して再生すると `deckOrderKeyOf` がカードマスタを引くので、
    //   ★受け取った端末の取り込み状態に結果が依存する（§13-5 / §17-9-2 の追記）。
    //   ★**(f-3) の軸 B は未決である。★ここで倒さない。**
    _record(DeckEditOpKind.sortByRule);
    _apply(
      value.draft
          .copyWith(entries: _repository.sortedByRule(value.draft.entries)),
    );
  }

  // ---------------------------------------------------------------------------
  // 保存
  // ---------------------------------------------------------------------------

  /// ★ここが `Deck` を組み直す唯一の入口（`DeckRepository.save` の中）。
  /// 何回編集していても、保存 1 回につき `revision` は +1 しか増えない。
  ///
  /// ★★ 2026-08-24 訂正（`ルール整合性チェック_v1.06.md` D-15 (d)）★★
  /// ここには「`Deck.copyWith` を踏む唯一の入口」と書いてあったが、
  /// 決定 D70 で `save` を明示コンストラクタにしたので**踏んでいない**。
  /// `revision` +1 と `updatedAt` を `Clock` から取ることは変わっていない。
  ///
  /// ★★ 貯めた操作をここで渡す（決定 **D110-1** / **D110-2**）★★
  /// ★**保存 1 回 = ログ N 件**である（`revision` が +1 しか増えないのと同じ形で、
  /// ★**操作の粒度は失わない** —— それが案 6 を採った理由そのものである / §13-2）。
  ///
  /// ★★ 捨てるのは成功したときだけ ★★
  /// 失敗すると `DeckDao.save` のトランザクションごと巻き戻り、**本体もログも残らない。**
  /// ★そこで捨てると、★やり直した保存が**本体だけを書いてログを落とす。**
  /// → ★`_pendingOps` の doc に理由の全文が在る。
  ///
  /// ★★ R3 に巻き戻しの口は無い（★走査で確かめた）★★
  /// `undo` / `redo` は**盤面の Store（`GameStore`）にしか無く**、
  /// デッキ編集には 1 つも無い。★画面を閉じればドラフトごと消える。
  /// ★★ 盤面側のクラス名をここに書かない（**D-30**）★★ ——
  /// `test/board/reduce_call_site_test.dart` が `lib` をその字面で走査しており、
  /// ★**説明のために書くと、許可リストに自分を載せることになる。**
  /// → ★**「戻した操作がログに残るか」という問いは、いまの実装には立たない。**
  ///   ★立つとしたら R3 に巻き戻しを足すときで、★そのとき決めること。
  Future<bool> save() async {
    if (!value.canSave) return false;
    state = value.copyWith(busy: true, clearActionError: true);
    try {
      final saved = await _repository.save(
        value.saved,
        value.draft,
        // ★★ 写しを渡す —— 渡した先が保持しても、こちらの `clear` で空にならない ★★
        ops: List<DeckEditOpRecord>.unmodifiable(_pendingOps),
      );
      // ★★ ここまで来たら DB に入っている（★同じトランザクション）★★
      _pendingOps.clear();
      // ★★ ドラフトの並びを保つ（正規化し直さない）★★
      //   保存直後に並べ替えを巻き戻すと、利用者には「保存したら並びが戻った」に見え、
      //   **開き直したときに戻るという予告と区別がつかない。**
      state = value.copyWith(
        saved: saved,
        validation: _repository.validateDraft(saved, value.draft),
        degradations: _degradationsOf(_repository, saved, value.draft),
      );
      return true;
    } on Object catch (error, stackTrace) {
      // ★握らない。画面に出す（決定 D53 / §3-4）。
      state = value.copyWith(actionError: (error, stackTrace));
      return false;
    } finally {
      state = value.copyWith(busy: false);
    }
  }

  /// ★論理削除（決定 D102）。DB には残るが、戻す口はまだ無い（未決 U9）。
  Future<bool> softDelete() async {
    if (value.busy) return false;
    state = value.copyWith(busy: true, clearActionError: true);
    try {
      await _repository.softDelete(value.saved.deckId);
      state = value.copyWith(deleted: true);
      return true;
    } on Object catch (error, stackTrace) {
      state = value.copyWith(actionError: (error, stackTrace));
      return false;
    } finally {
      state = value.copyWith(busy: false);
    }
  }

  void clearActionError() => state = value.copyWith(clearActionError: true);
}
