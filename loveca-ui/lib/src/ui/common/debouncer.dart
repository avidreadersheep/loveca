/// インクリメンタル検索のデバウンス（決定 D44）.
///
/// ★★ 150 ms より短くしないこと ★★
/// **デバウンス値が打鍵間隔以下だと、検索回数は 1 回も減らないまま待ち時間だけ増える。**
/// 打鍵 120 ms で 8 文字を入力したときの実測（`docs/UI技術検証メモ.md` §4-3）。
///
/// | デバウンス | 実行された検索 | 最後の打鍵から結果まで |
/// |---:|---:|---:|
/// | 0 ms | 8 回 | 24 ms |
/// | 100 ms | **8 回**（減っていない） | **128 ms** |
/// | **150 ms** | **1 回** | 179 ms |
///
/// 150 ms を採るのは、日本語入力の実際の `onChanged` 間隔（ローマ字 1 文字ごと・
/// 60〜120 ms 相当）を両方 1 回に畳めて、かつ 179 ms が
/// 「引っかかった」と感じる 200 ms を下回るため。
///
/// ★★ M1 では作らなかった ★★
/// 「使われないコードは腐る」（決定 D51 の `spike/` と同じ性質）ので、
/// 実際に使う M3 で初めて置いている。
///
/// ★Flutter に依存させない。`dart:async` の `Timer` だけで足りるので、
/// テストがウィジェットを立てずに済む。
library;

import 'dart:async';

class Debouncer {
  Debouncer({this.delay = defaultDelay});

  /// 決定 D44 の実測値。★下げるなら §4-3 を測り直すこと。
  static const Duration defaultDelay = Duration(milliseconds: 150);

  final Duration delay;

  Timer? _timer;
  bool _disposed = false;

  /// 保留中の実行があるか。★テストと、画面が「入力を受けたが未検索」を示すために使う。
  bool get isPending => _timer?.isActive ?? false;

  /// [action] を [delay] 後に 1 回だけ実行する。
  /// 待っている間に呼び直されたら、**前の予約は捨てる**（それが目的）。
  void run(void Function() action) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 保留中の実行を捨てる。★実行はしない。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// ★破棄後は `run` を受け付けない。
  /// 画面が閉じたあとにタイマが発火して、既に dispose した Store を触るのを防ぐ。
  void dispose() {
    cancel();
    _disposed = true;
  }
}
