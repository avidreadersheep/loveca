/// R3 デッキ編集の状態（★M2 最小版 / 決定 D53 / `docs/UI設計メモ.md` §9-1）.
///
/// ★★ 編集中はドラフトだけを持ち、`Deck` に触れない ★★
/// `Deck.copyWith` は `revision: revision ?? this.revision + 1` なので、
/// キー入力のたびに呼ぶと `revision` が跳ね、Phase 4 の同期で
/// 「大量に更新された」ように見える。
/// この Store が持つのは [DeckDraft]（文字列 2 本）であり、`Deck` になるのは
/// `DeckRepository.save` を通った瞬間だけである。
///
/// ★M2 でカードの増減は扱わない（M4）。`entries` は保存済みの `Deck` のまま動かない。
library;

import 'package:loveca_core/loveca_core.dart';

import '../data/deck_repository.dart';
import 'store.dart';

class DeckEditState {
  const DeckEditState({
    required this.saved,
    required this.draft,
    required this.validation,
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
  /// ★`DeckRepository.validate` は同期で DB へ行かない（決定 D55）。
  /// 材料は起動時に組んだ `MasterCatalog` にある。
  final DeckValidationResult validation;

  final bool busy;
  final (Object error, StackTrace stackTrace)? actionError;

  /// 論理削除済み。画面はこれを見て閉じる。
  final bool deleted;

  bool get isDirty => draft.isDirtyAgainst(saved);

  /// 保存ボタンの活性。★変更が無ければ押させない（無意味な `revision` +1 を防ぐ）。
  bool get canSave => isDirty && draft.isValid && !busy;

  DeckEditState copyWith({
    Deck? saved,
    DeckDraft? draft,
    DeckValidationResult? validation,
    bool? busy,
    bool clearActionError = false,
    (Object, StackTrace)? actionError,
    bool? deleted,
  }) =>
      DeckEditState(
        saved: saved ?? this.saved,
        draft: draft ?? this.draft,
        validation: validation ?? this.validation,
        busy: busy ?? this.busy,
        actionError:
            clearActionError ? null : (actionError ?? this.actionError),
        deleted: deleted ?? this.deleted,
      );
}

class DeckEditStore extends Store<DeckEditState> {
  DeckEditStore(this._repository, Deck deck)
      : super(DeckEditState(
          saved: deck,
          draft: DeckDraft.of(deck),
          validation: _repository.validate(deck),
        ));

  final DeckRepository _repository;

  /// ★★ 保存しない。`copyWith` も呼ばない ★★
  /// ここで `Deck` を作ると `revision` が 1 文字ごとに +1 される。
  void setName(String name) =>
      state = value.copyWith(draft: value.draft.copyWith(name: name));

  void setMemo(String memo) =>
      state = value.copyWith(draft: value.draft.copyWith(memo: memo));

  /// ★ここが `Deck.copyWith` を踏む唯一の入口（`DeckRepository.save` の中）。
  /// 何回編集していても、保存 1 回につき `revision` は +1 しか増えない。
  Future<bool> save() async {
    if (!value.canSave) return false;
    state = value.copyWith(busy: true, clearActionError: true);
    try {
      final saved = await _repository.save(value.saved, value.draft);
      state = value.copyWith(
        saved: saved,
        draft: DeckDraft.of(saved),
        validation: _repository.validate(saved),
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

  /// ★論理削除（P3）。DB には残るが、M2 には戻す口が無い（未決 U9）。
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
