/// R2 デッキ一覧の状態（決定 D53 / `docs/UI設計メモ.md` §3）.
///
/// ★★ 「一覧が読めない」と「操作が失敗した」を同じ型で表さない ★★
/// 削除に失敗したときに一覧ごと [Failed] へ倒すと、読めていた一覧が画面から消える。
/// かといって黙って握ると、押しても何も起きない画面になる（A-3 と同じ型）。
/// → 一覧は [Loadable] のまま、操作の失敗は [DeckListState.actionError] に別枠で持つ。
/// これは §3-4(3) が `notice` を `Loadable` と分けたのと同じ理由である。
///
/// ★★ メタ編集の口はここに無い（2026-08-30 / 決定 **D110-2** の A-i）★★
/// 2026-08-30 まで `saveMeta` が在り、`DeckRepository.save` へ**直行**していた。
/// ★それが**穴 (a)** である（`docs/同期設計メモ.md` §15-7-1 の 2）——
/// この経路は `DeckEditStore` の 9 つの名前つき操作を**1 つも通らない**ので、
/// ★**渡せる操作が無く、編集ログに 1 件も残らなかった。**
/// → ★**R2 のメタ編集そのものを `DeckEditStore` 経由にした**（`ui/deck/deck_list_page.dart`）。
/// ★**意図を採る層が 1 つに揃う**（A-ii は記録点を 2 か所に増やす形で、
/// ★次に入口が増えたとき同じ穴が開く / §15-7-3）。
///
/// ★★ ここに書き戻さないこと ★★
/// メタを書く口をこの Store に足すと、それは **A-ii そのもの**である。
/// ★`lib` に `DeckRepository.save` の呼び出し点が 1 つしか無いことは
/// `test/data/deck_save_call_site_test.dart` が機械で見ている。
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

  /// ★論理削除（決定 D102）。物理削除しないので DB には残る。
  Future<void> softDelete(String deckId) =>
      _act(() => _repository.softDelete(deckId));

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
