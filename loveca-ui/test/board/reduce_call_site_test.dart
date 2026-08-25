/// ★★ `reduce` を呼ぶのは `GameStore.dispatch` だけである（決定 D53 / D86）★★
///
/// M-B2 で盤面の各所が `GameAction` を組むようになった。
/// 組む場所は増えてよいが、**適用する場所が増えると Phase 6 で困る** ——
/// D53 は「Phase 6 で『サーバへ action を送って state を受け取る』に
/// 差し替える点も 1 箇所になる」ことを理由にこの規約を置いている。
///
/// ★★ M-B3 で「lib に 0 件」から「game_store.dart にちょうど 1 件」へ改めた ★★
/// `GameStore.dispatch` が `GameSession.apply` ではなく `reduceWithReport` を
/// 直接呼ぶようになったため（決定 D86 / 10.2.1 の割り込みリフレッシュ回数と
/// 10.3 / 10.6 の警告を出すのに [ReduceReport] が要る）。
///
/// ★★ 検査を緩めていない ★★
/// **総数を数えるだけにしない。** 総数だけだと 2 件目がどこにできても
/// 「2 になった」としか分からない。
/// → (1) `game_store.dart` が**ちょうど 1 件**であること、
///    (2) ★**それ以外のファイルは 1 つも無い**こと、を**別々に**固定する。
///
/// ★★ 走査そのものが同じ罠を踏まないようにする（D-15 §12-5）★★
/// **陽性対照**（同じ走査が `loveca_core` では当たること）を対で置く。
/// 0 件は「無い」と「見えていない」の区別がつかない。
///
/// ★`.apply(` を語に含めない。`CardListFilter.apply`（一覧の絞り込み）という
/// **別物の `apply`** があり、語を広げると「許可リスト」が育って検査の意味が薄れる。
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// `foo.reduce(` は `Iterable.reduce` なので除く。
final _reduceCall = RegExp(r'(^|[^.\w])reduce(WithReport)?\(');

void main() {
  test('★★ 陽性対照: 同じ走査が loveca_core では当たる ★★', () {
    // ★これが 0 件なら、下の「0 件」は「無い」ではなく「見えていない」。
    final hits = scanDart(coreLibPath, _reduceCall);

    expect(hits.keys, contains('reduce.dart'));
    expect(hits['reduce.dart'], greaterThan(0));
  });

  test('★★ `reduce` を呼ぶのは game_store.dart にちょうど 1 件 ★★', () {
    final hits = scanDart('lib', _reduceCall);

    expect(hits['game_store.dart'], 1,
        reason: '★dispatch が唯一の呼び出し口である（決定 D53 / D86）');
  });

  test('★★ game_store.dart 以外に 1 件も無い ★★', () {
    final hits = scanDart('lib', _reduceCall)
      ..remove('game_store.dart');

    expect(hits, isEmpty,
        reason: '★盤面の状態を進める場所が増えている。Phase 6 の差し替え点が割れる');
  });

  test('★★ `GameSession` に触れるのは game_store.dart だけ ★★', () {
    final hits = scanDart('lib', RegExp('GameSession'));

    // ★見つかっていることを先に確かめる（0 件は何も証明しない）。
    expect(hits, isNotEmpty);
    expect(
      hits.keys.toSet(),
      // ★`store.dart` は D53 の規約を **doc に書いている**だけで呼ばない。
      {'game_store.dart', 'store.dart'},
      reason: '★盤面の状態を進める場所が増えている。Phase 6 の差し替え点が割れる',
    );
  });
}
