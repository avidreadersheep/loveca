/// ★★ `reduce` を呼ぶのは `GameStore.dispatch` だけである（決定 D53）★★
///
/// M-B2 で盤面の各所が `GameAction` を組むようになった。
/// 組む場所は増えてよいが、**適用する場所が増えると Phase 6 で困る** ——
/// D53 は「Phase 6 で『サーバへ action を送って state を受け取る』に
/// 差し替える点も 1 箇所になる」ことを理由にこの規約を置いている。
///
/// ★★ 走査そのものが同じ罠を踏まないようにする（`ルール整合性チェック_v1.06.md` D-15 §12-5）★★
/// 最初の走査を `Random(` と `Image(` で書いたために `Random.secure()` と
/// `Image.asset(` を 1 件も拾えず、**0 件を「無い」と読みかけた**という前例がある。
/// → ここでは **(1) 陽性対照**（同じ走査が `loveca_core` では必ず当たること）と
/// **(2) 見つかった側**（`GameSession` は `game_store.dart` にしか無いこと）を対で見る。
///
/// ★`.apply(` を語に含めない。`CardListFilter.apply`（一覧の絞り込み）という
/// **別物の `apply`** があり、語を広げると「許可リスト」が育って検査の意味が薄れる。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// `foo.reduce(` は `Iterable.reduce` なので除く。
final _reduceCall = RegExp(r'(^|[^.\w])reduce(WithReport)?\(');

Map<String, int> _scan(String root, RegExp pattern) {
  final hits = <String, int>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final count = pattern.allMatches(entity.readAsStringSync()).length;
    if (count > 0) {
      hits[p.split(entity.path).last] = count;
    }
  }
  return hits;
}

void main() {
  test('★★ 陽性対照: 同じ走査が loveca_core では当たる ★★', () {
    // ★これが 0 件なら、下の「0 件」は「無い」ではなく「見えていない」。
    final hits = _scan(p.join('..', 'loveca-core', 'lib'), _reduceCall);

    expect(hits.keys, contains('reduce.dart'));
    expect(hits['reduce.dart'], greaterThan(0));
  });

  test('★ UI は `reduce` を直接呼ばない（`GameSession.apply` を通る）', () {
    expect(_scan('lib', _reduceCall), isEmpty);
  });

  test('★★ `GameSession` に触れるのは game_store.dart だけ ★★', () {
    final hits = _scan('lib', RegExp('GameSession'));

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
