/// ★★ 廃止した語がコードに戻っていないこと（決定 D88-1 / 盤面設計メモ §14-6）★★
///
/// D88 は R7 の旧称を**語ごと廃止した。**理由は「語を残すと同じ語が時期によって
/// 別の意味になり、`grep` で新旧を区別できなくなる」ことである。
/// ★**廃止したからこそ、次の走査が検査になる。**
///
/// ★★ この検査は「手で走らせる `grep`」では足りない ★★
/// D-2（`loveca-core` にリントが 1 つも効いていなかった）が前例で、
/// **走らせる人がいなければ何も検知しない。**だからテストに置く。
///
/// ★★ 語そのものをこのファイルに書かない ★★
/// 書くと**この走査自身が 0 件にならない。**
/// → 廃止を記録している文書（`docs/決定事項一覧.md` の D88-1）から**取り出す。**
/// 同じものを 2 箇所に書かないという規約（`ルール整合性チェック_v1.06.md` D-15）に
/// そのまま従っている。
///
/// ★★ 陽性対照を対で置く ★★
/// 取り出した語が**その文書では当たる**ことを先に確かめる。
/// 取り出しに失敗して空文字になっていたら、下の「0 件」は何も証明しない。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 廃止の記録がある文書。★語の正はここ 1 箇所。
final _decisionsDoc = p.join('..', 'docs', '決定事項一覧.md');

/// 「◯◯」という語は使わない。—— の「◯◯」を取り出す。
String _abolishedTerm() {
  final text = File(_decisionsDoc).readAsStringSync();
  final match = RegExp('「([^」]{2,20})」という語は使わない').firstMatch(text);
  expect(match, isNotNull,
      reason: '★D88-1 の書き方が変わった。走査の取り出し元を直すこと');
  return match!.group(1)!;
}

/// [root] 以下の `.dart` のうち [term] を含むもの → 一致数。
Map<String, int> _scan(String root, String term) {
  final hits = <String, int>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    // ★String は Pattern なので、そのまま素の文字列一致で数えられる。
    final count = term.allMatches(entity.readAsStringSync()).length;
    if (count > 0) hits[p.split(entity.path).last] = count;
  }
  return hits;
}

void main() {
  test('★★ 陽性対照: 取り出した語は D88-1 の文書では当たる ★★', () {
    final term = _abolishedTerm();

    // ★空文字なら下の「0 件」は「無い」ではなく「見ていない」。
    expect(term, isNotEmpty);
    expect(File(_decisionsDoc).readAsStringSync(), contains(term));
  });

  test('★★ loveca-ui のコードとテストに 1 件も無い ★★', () {
    final term = _abolishedTerm();

    expect(_scan('lib', term), isEmpty,
        reason: '★廃止した語が戻っている（決定 D88-1）');
    expect(_scan('test', term), isEmpty,
        reason: '★廃止した語が戻っている（決定 D88-1）');
  });

  test('★★ loveca_core のコードとテストにも 1 件も無い ★★', () {
    final term = _abolishedTerm();
    final core = p.join('..', 'loveca-core');

    expect(_scan(p.join(core, 'lib'), term), isEmpty);
    expect(_scan(p.join(core, 'test'), term), isEmpty);
  });

  test('★ 走査の対象そのものが空でない（前提）', () {
    // ★★ ディレクトリ名を間違えていると、上の 0 件は「見ていない」になる ★★
    //   実在するはずの別の語で、同じ走査が当たることを確かめる。
    expect(_scan('lib', 'ローカル対戦'), isNotEmpty);
    expect(_scan('test', 'ローカル対戦'), isNotEmpty);
    expect(_scan(p.join('..', 'loveca-core', 'lib'), 'ソロ'), isNotEmpty);
    expect(_scan(p.join('..', 'loveca-core', 'test'), 'ソロ'), isNotEmpty);
  });
}
