/// R2 デッキ一覧の状態（決定 D53 / `docs/UI設計メモ.md` §3）.
///
/// ★★ 「一覧が読めない」と「操作が失敗した」を同じ型で表さない ★★
/// 削除に失敗したときに一覧ごと [Failed] へ倒すと、読めていた一覧が画面から消える。
/// かといって黙って握ると、押しても何も起きない画面になる（A-3 と同じ型）。
/// → 一覧は [Loadable] のまま、操作の失敗は [DeckListState.actionError] に別枠で持つ。
/// これは §3-4(3) が `notice` を `Loadable` と分けたのと同じ理由である。
library;

import 'package:loveca_core/loveca_core.dart';

import '../data/deck_repository.dart';
import 'store.dart';

class DeckListState {
  const DeckListState({required this.decks, this.busy = false, this.actionError});

  /// ★論理削除済みを含まない一覧（`DeckRepository.all`）。
  final Loadable<List<Deck>> decks;

  /// 作成 / 削除の最中。二重押しを止めるためだけに持つ。
  final bool busy;

  /// ★作成 / 削除が失敗したこと。一覧を消さずに画面へ出す。
  final (Object error, StackTrace stackTrace)? actionError;

  DeckListState copyWith({
    Loadable<List<Deck>>? decks,
    bool? busy,
    bool clearActionError = false,
    (Object, StackTrace)? actionError,
  }) =>
      DeckListState(
        decks: decks ?? this.decks,
        busy: busy ?? this.busy,
        actionError: clearActionError ? null : (actionError ?? this.actionError),
      );
}

class DeckListStore extends Store<DeckListState> {
  DeckListStore(this._repository)
      : super(const DeckListState(decks: Loading()));

  final DeckRepository _repository;

  /// 一覧を読み直す。★失敗は握らず [Failed] へ写す（決定 D53）。
  /// リポジトリ側が空リストで代用しないので、「空」と「失敗」は区別できる。
  Future<void> load() async {
    state = value.copyWith(decks: const Loading(), clearActionError: true);
    try {
      state = value.copyWith(decks: Ready(await _repository.all()));
    } on Object catch (error, stackTrace) {
      state = value.copyWith(decks: Failed(error, stackTrace));
    }
  }

  /// 新規作成して一覧を読み直す。作成した `Deck` を返す（失敗なら null）。
  Future<Deck?> create(String name) => _act(() => _repository.create(name: name));

  /// ★論理削除（P3）。物理削除しないので DB には残る。
  Future<void> softDelete(String deckId) =>
      _act(() => _repository.softDelete(deckId));

  /// P3 のメタ編集を R2 から行う（M6）。
  ///
  /// ★★ R3 と違って「未保存」の器が無い ★★
  /// R3 はドラフトを持ち、保存ボタンで畳む。R2 にはその器が無いので、
  /// ダイアログの OK が保存 1 回に相当する。**どちらも畳むのは 1 回だけ**。
  Future<Deck?> saveMeta(Deck deck, DeckDraft draft) =>
      _act(() => _repository.save(deck, draft));

  /// 複製（決定 D71 / M6）。★刷りを保ったまま写せる唯一の手段。
  Future<Deck?> duplicate(Deck deck, {required String name}) =>
      _act(() => _repository.duplicate(deck, name: name));

  Future<T?> _act<T>(Future<T> Function() body) async {
    if (value.busy) return null;
    state = value.copyWith(busy: true, clearActionError: true);
    try {
      final result = await body();
      // ★書いたあとは必ず読み直す。画面の一覧を手で継ぎ足すと、
      //   DB の並び順（updatedAt 降順）と食い違う経路ができる。
      await load();
      return result;
    } on Object catch (error, stackTrace) {
      state = value.copyWith(actionError: (error, stackTrace));
      return null;
    } finally {
      state = value.copyWith(busy: false);
    }
  }

  /// 画面がエラーを出し終えたら消す（同じ失敗を出し続けないため）。
  void clearActionError() => state = value.copyWith(clearActionError: true);
}
