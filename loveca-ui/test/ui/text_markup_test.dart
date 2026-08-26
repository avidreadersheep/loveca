/// ★★ 表示文字列に Markdown の装飾記号を書かない（決定 D94-1）★★
///
/// `loveca_ui` は Markdown の描画器を持たない（`pubspec.yaml` に依存が無い）。
/// `Text` に渡した強調記号は ★装飾されず、記号のまま画面に出る。
/// M-B6 の実機確認で 4 行 5 対が実際に画面へ出ていた
/// （マリガン 6.2.1.6 の説明 / ライブ勝敗 8.4.6・8.4.7 の注記）。
///
/// ★★ 部分文字列一致のアサートでは捕まらない ★★
/// `board_live_judgement_test.dart` は `find.textContaining` で見ており、
/// 部分文字列が記号の ★直前で終わっていたため通っていた。
/// マリガンの側はその文字列に対するアサート自体が無かった。
/// → 個々のアサートを厳密一致へ直すのでは足りない（次に増える文字列を守れない）。
///
/// ★★ 走査の範囲は依頼より広い ★★
/// 「その文字列が `Text` へ届くか」はテキスト走査では決定不能なので、
/// ★届きうるもの（`lib` の文字列リテラル全部）を禁じる。
/// 現時点で誤検知は 0 件なので追加の費用が無い。
/// 将来ほんとうに要る用途が出たら、ファイル単位の許可リストで抜く
/// （`reduce_call_site_test.dart` が `store.dart` でやっている作法）。
/// ★`spike/` は走査しない —— `lib/` の外にあり、テストが無く、
///   Phase 3b 完了時に削除を再判断する（決定 D51）。
///
/// ★★ この文書とテスト本文に記号の字面を書かない ★★
/// 走査は本文一致なので、書くと ★この検査自身が当たる。
/// 走査対象は `lib` だけなので今は自己一致しないが、
/// 範囲を `test` へ広げた人が踏む（`board_player_access_test.dart` の戒め）。
/// → 記号は組み立てて作る。強調には ★ を使う。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/source_scan.dart';

void main() {
  // ★字面を書かずに組み立てる（上記）。
  final emphasis = '*' * 2;

  group('★★ 陽性対照 —— 抽出器が効いていること ★★', () {
    // ★これが落ちるなら、下の「0 件」は「無い」ではなく「見えていない」。

    test('★ 文字列リテラルの中の記号は当たる', () {
      final found = dartStringLiterals("Text('a${emphasis}b');");
      expect(found, ['a${emphasis}b']);
    });

    // ★★ コメントの中に引用符を入れてある。飾りではない ★★
    //   引用符を含まないコメントで書くと、★コメント処理を丸ごと外しても
    //   同じ結果になり、この対は何も証明しない。
    //   ★実際に最初はそう書いてしまい、外して走らせたら 7 件とも通った。
    //   引用符があると、コメントを外せていない実装は
    //   コメントの途中から文字列を読み始めて記号を拾う（＝落ちる）。
    //   D-10「検知手段自身が同じ罠を踏む」の実例なので、この形を崩さないこと。

    test('★ 対: doc コメントの中の同じ記号は当たらない', () {
      final source = "/// don't $emphasis強調$emphasis isn't\n"
          "const x = 'ふつうの文字列';\n";
      final found = dartStringLiterals(source);

      expect(found, ['ふつうの文字列']);
      expect(found.where((s) => s.contains(emphasis)), isEmpty,
          reason: '★コメントを外せていない。外せていなければ本編は 0 件にならない');
    });

    test('★ 対: 行コメントとブロックコメントの中も当たらない', () {
      final source = "// it's $emphasis行$emphasis isn't\n"
          "/* it's $emphasisブロック$emphasis isn't */\n"
          "const y = 'ok';\n";

      expect(dartStringLiterals(source), ['ok']);
    });

    test('★ 文字列の中の // と /* は文字列のまま扱う', () {
      // ★コメントの判定を文字列より先に走らせると、ここで途中まで捨ててしまう。
      const source = "const u = 'https://example.com/*x*/';";

      expect(dartStringLiterals(source), ['https://example.com/*x*/']);
    });

    test('★ 三重引用符と raw 文字列', () {
      final source = "const a = '''$emphasis三重$emphasis''';\n"
          "const b = r'raw $emphasis です';\n";

      expect(dartStringLiterals(source),
          ['$emphasis三重$emphasis', 'raw $emphasis です']);
    });
  });

  test('★ 走査の対象そのものが空でない（前提）', () {
    // ★★ 実ファイルから表示文字列を取り出せることを先に見る ★★
    //   ディレクトリ名か抽出器が壊れていると、下の 0 件は「見ていない」になる。
    final literals = dartStringLiterals(
        File(p.join('lib', 'src', 'ui', 'board', 'board_progress.dart'))
            .readAsStringSync());

    expect(literals, contains('整理する 10.4 / 10.5'),
        reason: '★実ファイルから表示文字列を取り出せていない');
  });

  test('★★ lib の文字列リテラルに装飾記号を書かない ★★', () {
    expect(scanDartStringLiterals('lib', emphasis), isEmpty,
        reason: '★表示文字列に装飾記号が混ざっている。'
            '`Text` は Markdown を解釈しないので記号のまま画面に出る（決定 D94-1）');
  });
}
