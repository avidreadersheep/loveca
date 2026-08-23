/// 状態の器（決定 D53）.
///
/// ★★ 状態管理パッケージを入れない ★★
/// 単一の不変状態・アクション・スナップショット履歴という仕組みは
/// `loveca_core` に既にある（`GameState` / `GameAction` / `reduce` /
/// `GameSession`）。パッケージはその上に器を被せるだけになる。
/// bloc の `Event` は `GameAction` と二重定義になり、D-D
/// 「Phase 6 の権威サーバが同じ `reduce` を再利用する」の唯一性を濁す。
///
/// 再描画粒度の懸念は実測で否定されている（最小盤面 build p50 0.1ms /
/// 一覧 2,527 セル 0.3〜0.4ms に対し観測フレーム予算 6.9ms。
/// `docs/UI技術検証メモ.md` §7-1 / §3-1 / §1-3）。
///
/// ★見直す条件は `docs/UI設計メモ.md` §3-6 に具体値で置いてある。
library;

import 'package:flutter/foundation.dart';

/// 単一の不変状態を持つ器。
///
/// ★[value] は外から差し替えられない★
/// `ValueNotifier` をそのまま使うと `store.value = ...` がどこからでも書ける。
/// 遷移の入口を 1 つに保つため、書き込みは [state] セッタ（`@protected`）だけにする。
/// Phase 3b では `GameStore.dispatch` が `reduce` を呼ぶ唯一の場所になり、
/// Phase 6 で「サーバへ action を送って state を受け取る」に差し替える点もそこ 1 箇所になる。
abstract class Store<S> extends ChangeNotifier implements ValueListenable<S> {
  Store(this._value);

  S _value;

  @override
  S get value => _value;

  /// ★同一インスタンスなら通知しない。
  /// 状態は不変オブジェクトなので、遷移があれば必ず別インスタンスになる。
  @protected
  set state(S next) {
    if (identical(_value, next)) return;
    _value = next;
    notifyListeners();
  }
}

/// 非同期に読むものの 3 状態（決定 D53）.
///
/// ★★ `sealed` にする理由は網羅性検査である ★★
/// 枝を足したとき、拾い漏らした `switch` が**コンパイルエラーになる**。
/// `T? data` / `Object? error` / `bool loading` の 3 本で表すと網羅性が緩み、
/// **それは A-3（痕跡を残さずデータを落とす）と同じ「無言」を招く。**
///
/// ★「空」と「失敗」を同じ型で表さないこと。
/// リポジトリは例外を握らず投げ、Store が [Failed] へ写す。
sealed class Loadable<T> {
  const Loadable();
}

final class Loading<T> extends Loadable<T> {
  const Loading();
}

final class Failed<T> extends Loadable<T> {
  const Failed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class Ready<T> extends Loadable<T> {
  const Ready(this.value);

  final T value;
}
