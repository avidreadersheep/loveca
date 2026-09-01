/// ソースから `import` / `export` の指示行を取り出す（決定 **D115-7** の (c) の道具）.
///
/// ★★ なぜ素の字面の走査ではいけないか（**D-30**）★★
/// 禁止対象を説明する文書は、禁止対象と**同じ字面を必ず含む**。
/// `lib/loveca_server.dart` の境界の宣言がまさにそれで、
/// `package:flutter` も `package:loveca_core` も**その doc の中に実在する。**
/// → ★**素の字面で走ると、境界の宣言そのものが当たる。**
/// → ★**除外を足すと、その除外自身が穴になる**（D-30 が「名乗れば黙らせられる」と書いている）。
/// → ★★**だから字面ではなく `import` / `export` の**指示行**を見る。**★★
///
/// ★★ 走査そのものが同じ罠を踏まないようにする（**D-10** / **D-27**）★★
/// この関数は**純粋関数**にしてある。★合成ソースで
/// 「当たること」と「当たらないこと」を**対で**固定できるからである。
/// ★**0 件は「無い」と「見えていない」の区別がつかない。**
///
/// ★★ 分かっている限界（**D-28** —— 推測で埋めない）★★
/// **文字列リテラルの中に、行頭から `import '…';` の形で書かれたもの**は拾ってしまう。
/// ★`lib` に該当は 0 件である（走査した）。★**手当てしていない。**
/// ★このファイル自身（`test/`）には該当が在るが、★**`test/` は走査対象ではない。**
library;

import 'dart:io';

/// コメントを外す。★**文字列の中の `//` をコメントと読まない**ように、
/// 文字列リテラルを跨いで進む。
///
/// ★改行は残す（★指示行の判定が**行頭**を見るため）。
String stripDartComments(String source) {
  final buf = StringBuffer();
  final n = source.length;
  var i = 0;

  while (i < n) {
    final c = source[i];

    // 行コメント（`//` と `///`）。★改行は次の周回で書かれる。
    if (c == '/' && i + 1 < n && source[i + 1] == '/') {
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // ブロックコメント。★Dart は入れ子を許すので深さを数える。
    if (c == '/' && i + 1 < n && source[i + 1] == '*') {
      var depth = 1;
      i += 2;
      while (i < n && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
          continue;
        }
        if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
          continue;
        }
        if (source[i] == '\n') buf.write('\n'); // ★行を潰さない
        i++;
      }
      continue;
    }

    // 文字列リテラル。★中身はそのまま残す（指示行の URI がここに在る）。
    if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = i + 2 < n && source[i + 1] == c && source[i + 2] == c;
      final quote = triple ? c * 3 : c;
      buf.write(quote);
      i += quote.length;

      while (i < n) {
        // ★0x5C は逆スラッシュ。字面で書くとエスケープの読み違いを生むので符号で書く
        //   （`loveca-ui/test/support/source_scan.dart` と同じ作法 / **D-38**）。
        if (!raw && source.codeUnitAt(i) == 0x5C && i + 1 < n) {
          buf.write(source[i]);
          buf.write(source[i + 1]);
          i += 2;
          continue;
        }
        if (source.startsWith(quote, i)) {
          buf.write(quote);
          i += quote.length;
          break;
        }
        buf.write(source[i]);
        i++;
      }
      continue;
    }

    buf.write(c);
    i++;
  }
  return buf.toString();
}

/// `import` / `export` の指示行。★**両方を見る** ——
/// `export 'package:loveca_core/…'` は**再公開**であり、import と同じだけ線を跨ぐ。
///
/// ★引用符は `\x22` で書く（★字面の `"` をこの raw 文字列に入れないため / **D-38**）。
final _directive = RegExp(
  r"^[ \t]*(?:import|export)[ \t]+r?(['\x22])([^'\x22]*)\1",
  multiLine: true,
);

/// [source] の `import` / `export` の URI を返す。
List<String> directiveUris(String source) => _directive
    .allMatches(stripDartComments(source))
    .map((m) => m.group(2)!)
    .toList();

/// [root] 以下の `.dart` を走査し、**`/` 区切りの相対パス -> URI の列**を返す。
///
/// ★指示行が 1 件も無いファイルは載せない。
Map<String, List<String>> scanDirectives(String root) {
  final hits = <String, List<String>>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final uris = directiveUris(entity.readAsStringSync());
    if (uris.isNotEmpty) hits[entity.path.replaceAll(r'\', '/')] = uris;
  }
  return hits;
}

/// [root] 以下の `.dart` から、指示行の URI を**全部**平らに集める。
List<String> allDirectiveUris(String root) =>
    scanDirectives(root).values.expand((e) => e).toList();

/// YAML のコメント（`#` から行末）を外す。
///
/// ★★ 限界（**D-28**）★★ 引用符の中の `#` も外す。
/// ★`loveca-server/pubspec.yaml` に該当は 0 件である（実読）。★手当てしていない。
String stripYamlComments(String source) => source
    .split('\n')
    .map((line) {
      final at = line.indexOf('#');
      return at < 0 ? line : line.substring(0, at);
    })
    .join('\n');

/// pubspec の**依存のキー行**（`  name:`）に現れる名前。
///
/// ★`dependencies` と `dev_dependencies` を区別しない —— ★**どちらに書いても
/// 「呼べる」状態になる**（**D126-3**）。
final pubspecDependencyKey =
    RegExp(r'^[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*:', multiLine: true);

/// [pubspec] の本体（★コメントを外したもの）に現れる依存のキー名。
Set<String> pubspecDependencyKeys(String pubspec) => pubspecDependencyKey
    .allMatches(stripYamlComments(pubspec))
    .map((m) => m.group(1)!)
    .toSet();
