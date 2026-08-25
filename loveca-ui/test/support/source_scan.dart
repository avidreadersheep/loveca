/// ソースの走査（`ルール整合性チェック_v1.06.md` D-15 §12-5 の作法）.
///
/// ★★ 走査そのものが同じ罠を踏まないようにする ★★
/// 最初の走査を `Random(` と `Image(` で書いたために `Random.secure()` と
/// `Image.asset(` を 1 件も拾えず、**0 件を「無い」と読みかけた**という前例がある。
/// → 走査を使うテストは必ず**陽性対照**（同じ走査が当たる場所）を対で置くこと。
/// **0 件は「無い」と「見えていない」の区別がつかない。**
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// [root] 以下の `.dart` を走査し、**ファイル名 -> 一致数**を返す。
///
/// ★一致 0 件のファイルは載せない（「どこに何件あるか」だけを見たいため）。
Map<String, int> scanDart(String root, RegExp pattern) {
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

/// `loveca-core/lib` の場所。★陽性対照に使う。
String get coreLibPath => p.join('..', 'loveca-core', 'lib');
