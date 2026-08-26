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

/// Dart のソースから「文字列リテラルの中身」だけを取り出す.
///
/// ★★ なぜ素の正規表現では足りないか ★★
/// このリポジトリは doc コメントで記号による強調を多用しており、全文に当てると
/// `lib/src/ui/` だけで 500 行以上が当たる。★コメントを外さないと 0 件に届かない。
/// ★[scanDart] はコメント混入を「ファイル単位の許可リスト」で処理してきたが
/// （`reduce_call_site_test.dart` の `store.dart`）、ほぼ全ファイルが当たる走査では効かない。
///
/// ★追う状態は 4 つ —— 素のコード / 行コメント / ブロックコメント / 文字列。
/// 文字列は `'` `"` と三重引用符、`r` 接頭辞、`\` エスケープを見る。
/// ★補間の中身は文字列の一部として返す。現に該当が無く、分けると状態が増える。
///   誤検知が出たらそのとき分けること。
///
/// ★★ 陽性対照を対で置くこと ★★
/// 「文字列の中は当たる」だけを見ると、何も取り出さない実装でも
/// 「コメントの中は当たらない」が通ってしまう。**両方**を見る。
List<String> dartStringLiterals(String source) {
  final out = <String>[];
  final buf = StringBuffer();
  final n = source.length;
  var i = 0;

  while (i < n) {
    final c = source[i];

    // 行コメント（`//` と `///`）。改行まで捨てる。
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // ブロックコメント。★閉じが無ければ末尾まで捨てる。
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= n ? i + 2 : n;
      continue;
    }

    if (c == "'" || c == '"') {
      // ★`r` 接頭辞。素の識別子が引用符に隣接する形は Dart に無いので、
      //   直前 1 文字を見るだけで足りる。
      final raw = i > 0 && source[i - 1] == 'r';
      final triple =
          i + 2 < n && source[i + 1] == c && source[i + 2] == c;
      final quote = triple ? c * 3 : c;
      i += quote.length;

      buf.clear();
      while (i < n) {
        // ★0x5C は逆スラッシュ。字面で書くとエスケープの読み違いを生むので符号で書く。
        if (!raw && source.codeUnitAt(i) == 0x5C && i + 1 < n) {
          // ★エスケープされた 1 文字は中身に残す（記号としては数えない）。
          buf.write(source[i + 1]);
          i += 2;
          continue;
        }
        if (source.startsWith(quote, i)) {
          i += quote.length;
          break;
        }
        buf.write(source[i]);
        i++;
      }
      out.add(buf.toString());
      continue;
    }

    i++;
  }
  return out;
}

/// [root] 以下の `.dart` の「文字列リテラル」を走査し、
/// [pattern] に当たるものを **ファイル名 -> 当たった中身** で返す。
///
/// ★当たらないファイルは載せない（[scanDart] と同じ作法）。
Map<String, List<String>> scanDartStringLiterals(String root, Pattern pattern) {
  final hits = <String, List<String>>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final bad = dartStringLiterals(entity.readAsStringSync())
        .where((s) => s.contains(pattern))
        .toList();
    if (bad.isNotEmpty) hits[p.split(entity.path).last] = bad;
  }
  return hits;
}
