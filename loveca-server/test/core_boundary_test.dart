/// ★★ 線 α —— サーバーが `loveca_core` から呼んでよいものの許可リスト ★★
/// （決定 **D115-6** / **D115-7** の (c) / **D126-3** / **D126-4** / `docs/同期設計メモ.md` §32-6 の 17）
///
/// **D115-7** は「★機械で見る手段は在る。★**ただし対象が存在しないので今日は書けない**」と
/// 書いていた。★**この回で対象が存在した**（決定 **D126-2** —— サーバーのパッケージ）。
/// → ★★**対象が存在した最初の瞬間に置く。★遅らせると、リストが空で始まらなくなる**★★
///   （§32-7 が 17 を 16 の直後に置いた理由そのもの）。
///
/// ★★ 見張るのは 4 段すべてではない ★★
/// `lib/loveca_server.dart` の境界の宣言は 4 段（禁止 / 空で始まる許可リスト /
/// 決めていない / 許可）。★**このファイルが見るのは上の 3 段だけ**である
/// （4 段目は Dart SDK であり、★見張る相手が無い）。
/// ★★**3 段目（`loveca_db`）を 1 段目（禁止）と同じ文言で書かない**★★ ——
/// 書くと「サーバーは `loveca_db` を呼んではならない」という**決定**を作ってしまう。
/// ★**決めていない**（`docs/同期設計メモ.md` §35-9 / **D126-4**）。
///
/// ★★ 0 件を「無い」と読まないための構え（**D-10** / **D-27**）★★
/// 下の「0 件であること」は、それ単独では**走査が壊れていても通る。**
/// → ★**走査が当たること**を合成ソースで対にし、
/// → ★**実ファイルの走査が空でないこと**も別に固定する。
/// → ★さらに **D-30** の対（★素朴な字面なら当たる / ★指示行なら当たらない）を置く。
///
/// ★★ 走査を守っているものは 2 つある。混ぜないこと（**D-27** で測って分けた）★★
///
/// | 何 | 何を止めるか |
/// |---|---|
/// | ★**行頭の判定**（`^` の直後が `import` / `export`） | ★行コメント・doc・表の中の字面 |
/// | ★**コメント外し** | ★**ブロックコメントの中の、行頭から書かれた指示行** |
///
/// ★★**行コメントは行頭の判定だけで止まる**★★ —— ★`//` で始まる行は
/// どうやっても行頭の判定に当たらない。★**コメント外しを外しても落ちない**
/// （★**実測した**）。→ ★**その群を「コメント外しの対」と呼ばない。**
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:loveca_server/loveca_server.dart';

import 'support/directive_scan.dart';

/// ★走査する木。★このパッケージを作業ディレクトリとした相対パス。
const _libRoot = 'lib';

/// ★境界の宣言そのものが置いてあるファイル（**D-30** の対に使う）。
const _boundaryDoc = 'lib/loveca_server.dart';

/// ★禁止（決定 **D126-4** の 1 段目）。★サーバーに画面は無い。
///
/// ★接尾の `/` を付けない —— ★`package:flutter_test` のような**隣の名前**も
/// 同じ理由で禁止だからである（★どれも画面を持ち込む）。
const _forbidden = <String>[
  'package:flutter',
  'dart:ui',
  'package:loveca_ui',
];

/// ★★ 決めていない（決定 **D126-4** の 3 段目）★★
/// ★**「禁止」ではない。**★今日は依存しないという事実を固定するだけである。
const _undecided = 'package:loveca_db';

/// ★線 α の相手。
const _core = 'package:loveca_core';

/// ★合成ソースは連結で組む（★何を組み立てたかを読み手に見せるため）。
String _importLine(String uri) => "import '$uri';";
String _exportLine(String uri) => "export '$uri';";

/// ★合成に使う `loveca_core` のライブラリ URI。
const _coreLib = '$_core/loveca_core.dart';

void main() {
  group('★★ 走査が当たること（★これが無いと下の 0 件は何も証明しない / D-10）★★', () {
    test('★ import の指示行を拾う', () {
      expect(directiveUris(_importLine(_coreLib)), [_coreLib]);
    });

    test('★★ export の指示行も拾う（★再公開は import と同じだけ線を跨ぐ）★★', () {
      expect(directiveUris(_exportLine(_coreLib)), [_coreLib]);
    });

    test('★★ 実ファイルの走査が空でない（★根を間違えていたら 0 件になる）★★', () {
      expect(allDirectiveUris(_libRoot), isNotEmpty);
    });
  });

  group('★★ 行頭の判定 —— 字面が在っても指示行でなければ拾わない（D-30）★★', () {
    // ★★ この群は**コメント外しを外しても落ちない**（実測）★★
    //   `//` で始まる行は、行頭の判定だけで止まっている。
    //   → ★それでも置く。**走査を「行頭」から「字面」に変えた人がここで落ちる。**

    test('★ 行コメントに書かれた指示行は拾わない', () {
      expect(directiveUris('// ${_importLine(_coreLib)}'), isEmpty);
    });

    test('★ doc コメントに書かれた指示行は拾わない', () {
      expect(directiveUris('/// ${_importLine(_coreLib)}'), isEmpty);
    });

    test('★ 表の中の字面（`package:…` だけ）は拾わない', () {
      expect(directiveUris('/// | 禁止 | `$_core` | 入れない |'), isEmpty);
    });

    test('★★ 文字列リテラルの中の指示行は拾わない（★行の途中に在る場合）★★', () {
      // ★★ この 1 件だけが**行頭の判定**を見ている（★実測して足した / D-27）★★
      //   コメント外しは**文字列を残す**ので、この字面は走査に届く。
      //   ★止めているのは行頭の判定だけである。
      //   ★★ 分かっている限界（`support/directive_scan.dart` の doc）★★
      //     **行頭から**書かれた文字列リテラルなら拾ってしまう。
      //     ★`lib` に該当は 0 件（走査した）。★手当てしていない。
      final src = 'const a = "${_importLine(_coreLib)}";';
      expect(directiveUris(src), isEmpty);
    });
  });

  group('★★ コメント外し —— 行頭から書かれた指示行をブロックコメントが囲む場合 ★★', () {
    // ★★ この群だけが `stripDartComments` を実際に見ている（実測で分けた / D-27）★★

    test('★★ ブロックコメントの中の、行頭から書かれた指示行を拾わない ★★', () {
      final src = '/*\n${_importLine(_coreLib)}\n*/\n';
      expect(directiveUris(src), isEmpty);
    });

    test('★★ 入れ子のブロックコメントも外す（Dart は入れ子を許す）★★', () {
      final src = '/*\n/*\n${_importLine(_coreLib)}\n*/\n*/\n'
          '${_importLine('dart:io')}';
      expect(directiveUris(src), ['dart:io']);
    });

    test('★★ 文字列の中の `//` をコメントと読まない ★★', () {
      // ★これを誤ると、URI の途中で行が切れて**指示行を丸ごと落とす。**
      expect(
        directiveUris(_importLine('package:a/b//c.dart')),
        ['package:a/b//c.dart'],
      );
    });
  });

  group('★★ D-30 の対 —— 素朴な字面なら当たる。指示行なら当たらない ★★', () {
    // ★この 3 件は組で 1 つの主張である。
    //   ★片方だけだと「境界の宣言に字面が無いから 0 件」でも通ってしまう。
    final doc = File(_boundaryDoc).readAsStringSync();

    test('★ 境界の宣言は許可リスト対象の字面を実際に含む', () {
      expect(doc.contains(_core), isTrue,
          reason: '★この字面が無いなら、下の「指示行では 0 件」は何も証明しない');
    });

    test('★ 境界の宣言は禁止対象の字面も実際に含む', () {
      for (final f in _forbidden) {
        expect(doc.contains(f), isTrue, reason: '★$f');
      }
    });

    test('★★ それでも `package:` の指示行は 1 件も無い ★★', () {
      expect(directiveUris(doc).where((u) => u.startsWith('package:')), isEmpty);
    });
  });

  group('★★ 線 α（決定 D115-6）★★', () {
    test('★★ 許可リストは空である（★空で始まる）★★', () {
      expect(allowedCoreLibraries, isEmpty,
          reason: '★1 件目を足すときは pubspec と理由も一緒に足すこと'
              '（`lib/src/boundary.dart` の 3 つ）');
    });

    test('★★ lib の loveca_core への指示行は許可リストと完全一致する ★★', () {
      // ★件数ではなく**集合**で見る。★件数だけだと入れ替わりが通る。
      final actual =
          allDirectiveUris(_libRoot).where((u) => u.startsWith(_core)).toSet();

      expect(actual, allowedCoreLibraries);
    });
  });

  group('★★ 禁止（決定 D126-4 の 1 段目）—— サーバーに画面は無い ★★', () {
    test('★ lib に flutter / dart:ui / loveca_ui の指示行が 1 件も無い', () {
      final bad = scanDirectives(_libRoot).map(
        (path, uris) => MapEntry(
          path,
          uris.where((u) => _forbidden.any(u.startsWith)).toList(),
        ),
      )..removeWhere((_, uris) => uris.isEmpty);

      expect(bad, isEmpty);
    });
  });

  group('★★ 決めていない（決定 D126-4 の 3 段目）★★', () {
    test('★★ lib に loveca_db の指示行が 1 件も無い（★「禁止だから 0」ではない）★★', () {
      // ★★ この 0 件は**事実の固定**であって禁止ではない ★★
      //   サーバーが何で保管するかは未決である（`docs/同期設計メモ.md` §35-9）。
      //   → ★足すことになったら、この test を**消すのではなく**
      //     `docs/同期設計メモ.md` §35-9 を先に閉じること。
      final actual =
          allDirectiveUris(_libRoot).where((u) => u.startsWith(_undecided));

      expect(actual, isEmpty);
    });
  });

  group('★★ pubspec —— 「書かないこと」が線 α の一部である（決定 D126-3）★★', () {
    final raw = File('pubspec.yaml').readAsStringSync();

    // ★★ 2 つの検査は見ているものが違う。1 つにまとめない（D-27 で測って分けた）★★
    //   ★**キー行**の検査 … 構造で見る。★**コメント外しは効かない**（実測 ——
    //     行頭が `#` の行は「字下げ ＋ 識別子 ＋ コロン」に当たらない）。
    //   ★**本体の字面**の検査 … 広く見る。★**コメント外しが効く**（実測 ——
    //     pubspec の doc は `loveca_core` の字面を実際に含む）。

    test('★★ 陽性対照: コメントを外す前の pubspec は loveca_core の字面を含む ★★', () {
      expect(raw.contains('loveca_core'), isTrue,
          reason: '★この字面が無いなら、下の「本体に無い」は何も証明しない');
    });

    test('★★ 陽性対照: 依存のキーの取り出しが働く ★★', () {
      const synthetic = 'dependencies:\n'
          '  loveca_core:\n'
          '    path: ../loveca-core\n';

      expect(pubspecDependencyKeys(synthetic), contains('loveca_core'));
    });

    test('★★ 依存のキーに loveca_core / loveca_db / loveca_ui / flutter が無い ★★', () {
      final keys = pubspecDependencyKeys(raw);

      // ★取り出しが空でないことを先に確かめる（0 件は何も証明しない / D-10）。
      expect(keys, isNotEmpty);
      expect(
        keys.intersection({'loveca_core', 'loveca_db', 'loveca_ui', 'flutter'}),
        isEmpty,
        reason: '★書けば「呼べる」状態になり、線 α が空であることを構造で守れなくなる',
      );
    });

    test('★★ コメントを外した本体に loveca_* の字面が 1 つも無い ★★', () {
      // ★キー行の検査より**広い** —— ★`path:` の値や、
      //   キーとして書かれていない参照も当たる。
      final body = stripYamlComments(raw);

      for (final name in ['loveca_core', 'loveca_db', 'loveca_ui']) {
        expect(body.contains(name), isFalse, reason: '★$name');
      }
    });
  });
}
