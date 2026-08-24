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
  /// ★★ 並べ替えただけでは活性にならない ★★
  /// 並び順は保存できない（決定 D65）ので、押せると
  /// 「保存したのに戻る」という最悪の形になる。並べ替えは縮退として別に見せる。
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
  /// 総合ルール 6.1.1.2: メインデッキは同一カードナンバー 4 枚まで
  /// （★パラレル違いも合算される）。
  tooManyCopies,

  /// 総合ルール 6.1.1.3: エネルギーデッキは 12 枚。
  energyDeckFull,

  /// カードマスタに無い刷り（決定 D35）。
  unknownPrinting,
}

class DeckEditStore extends Store<DeckEditState> {
  DeckEditStore(DeckRepository repository, Deck deck)
      : _repository = repository,
        super(_initialState(repository, deck));

  static DeckEditState _initialState(DeckRepository repository, Deck deck) {
    // ★開いた直後の並びを正規化する（決定 D65）。
    //   DeckDao.all は entries に ORDER BY を持たず byId は printing_id 順なので、
    //   経路によって並びが違う（D-11）。画面に持ち込まない。
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
      if (repository.isReordered(draft)) const DeckOrderNotPersisted(),
      if (validation.hasUnknownCards)
        DeckUnknownPrintings(validation.unknownPrintingIds.length),
    ];
  }

  final DeckRepository _repository;

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

  void setName(String name) => _apply(value.draft.copyWith(name: name));

  void setMemo(String memo) => _apply(value.draft.copyWith(memo: memo));

  /// 共有形式から取り込んだ中身で置き換える（M6 / 決定 D67）。
  ///
  /// ★★ 保存しない ★★
  /// ドラフトを差し替えるだけなので、**保存しなければ元に戻せる。**
  /// だからダイアログで「置き換えます」と言い切れる。
  ///
  /// ★合算しない。合算すると 4 枚超過が起きやすく、しかも戻せない。
  void replaceEntries(List<DeckEntry> entries) =>
      _apply(value.draft.copyWith(entries: entries));

  /// P3 のメタ編集（M6）。★`_apply` を通すので `revision` は動かない。
  void applyMeta(DeckDraft meta) => _apply(
        value.draft.copyWith(
          name: meta.name,
          memo: meta.memo,
          tags: meta.tags,
          coverPrintingId: meta.coverPrintingId,
          // ★外すのも編集のうち。渡さないと片道になる。
          clearCover: meta.coverPrintingId == null,
        ),
      );

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
  AddCardRefusal? addCard(
    String printingId, {
    String? before,
    DropEdge edge = DropEdge.leading,
  }) {
    if (_repository.cardTypeOf(printingId) == null) {
      return AddCardRefusal.unknownPrinting;
    }
    if (!canAdd(printingId)) {
      // ★理由を区別する。「4 枚まで」と「エネルギー 12 枚」は対処が違う。
      return _repository.cardTypeOf(printingId) == CardType.energy
          ? AddCardRefusal.energyDeckFull
          : AddCardRefusal.tooManyCopies;
    }

    final existed = value.draft.countOf(printingId) > 0;
    var next = value.draft.addCopy(printingId);
    if (!existed && before != null) {
      next = next.moveEntry(printingId, before, after: edge == DropEdge.trailing);
    }
    _apply(next);
    return null;
  }

  /// 1 枚減らす。0 になったら行ごと消える。
  void removeCopy(String printingId) =>
      _apply(value.draft.removeCopy(printingId));

  /// 行ごと消す（ゴミ箱）。
  void removeEntry(String printingId) =>
      _apply(value.draft.removeEntry(printingId));

  /// デッキの中で並べ替える。
  ///
  /// ★★ 保存されない（決定 D65）★★
  /// 結果として [DeckOrderNotPersisted] が立ち、画面が
  /// 「開き直すとカード番号順に戻る」と予告する。
  void moveEntry(String printingId, String target, DropEdge edge) => _apply(
        value.draft
            .moveEntry(printingId, target, after: edge == DropEdge.trailing),
      );

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
  Future<bool> save() async {
    if (!value.canSave) return false;
    state = value.copyWith(busy: true, clearActionError: true);
    try {
      final saved = await _repository.save(value.saved, value.draft);
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

  /// ★論理削除（P3）。DB には残るが、戻す口はまだ無い（未決 U9）。
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
