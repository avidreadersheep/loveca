/// ★★ 報告の★渡し方が★1 行目に書かれていること（★★規約 6 / 運転指示【0】(5)★★）★★
///
/// ★★ 引き金 —— ★★規約 4 を足した★次の回も★要約が渡った ★★
/// ★**相談役が「★規約 4 は★誰が読む場所に在るか」と述べた。**
/// ★★**実読したら、★要約された `2026-09-02-02.md` には★★指示の 1 行が★在った★★**★★（★6 行目）。
/// → ★**「読まれる場所に無かった」だけでは★★説明にならない★★。★★在ったのに効かなかった★★。**
/// ★**理由の候補と、★どれが確かめられるかは `docs/相談役への報告/README.md` の 4-4-2 が正である。**
///
/// ★★ この検査が見るもの ★★
/// ★**報告の★★最初の非空行★★が★規約 6 の 2 行であること。**
/// ★★**中身は見ない**★★ —— ★中身の正は★★運転指示【3】の 8 項目★★である（**D-15** の規約 3）。
///
/// ★★ 人の規律に頼らない（**D-2**）★★
/// ★**規約 4 は★★実際に忘れられた★★。★★同じ手を二度打たないために機械へ移す★★。**
///
/// ★★ 既に在る報告は★免除する。★1 文字も書き換えない（**D-35**）★★
/// ★**免除は★★ファイル名で名指しする★★**（★★数で書かない★★）。
/// ★**免除の理由は 1 つ** —— ★★書いた時点にこの規約が無かった★★。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 報告の置き場（★`loveca-ui` を作業ディレクトリとした相対パス）。
const _reportDir = '../docs/相談役への報告';

/// ★★ 1 行目に要る 2 行（★★README.md の規約 6 の写し★★）★★
///
/// ★★ 写しを持つことの代償を隠さない ★★
/// ★**正は `README.md` の規約 6 である。★★ここは写しである★★**（**D-15** の規約 3）。
/// ★**食い違ったら★★下の「写しは正と 1 文字も違わない」が落ちる★★**
/// （★先例は `user_question_test.dart` の受け 2）。
const _banner = <String>[
  '> ★★**このファイルは★★全文をそのまま貼ってください★★。★要約しないでください。**★★',
  '> ★★**節を 1 つも落とさないでください**★★ —— '
      '★★運転指示【3】の 3（既定値の全件）と 7（待ち行列の内訳）は★畳むと空振りします★★。',
];

/// ★★ 免除するファイル（★★書いた時点にこの規約が無かった★★ / **D-35**）★★
///
/// ★★ 数で書かない。★名指しする ★★
/// ★**「4 件」と書くと★★次に足したときに★数だけ合わせる作業になる★★**（★先例は **D-25**）。
const _exempt = <String>{
  '2026-09-01-01.md',
  '2026-09-01-02.md',
  '2026-09-02-01.md',
  '2026-09-02-02.md',
};

List<File> _reports() {
  final dir = Directory(_reportDir);
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md'))
      .where((f) => !f.path.endsWith('README.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

// ★★ D-38 を踏んだ —— ★道具の経路で★逆斜線が畳まれ、★正規表現の文字クラスが閉じなくなった ★★
//   → ★**このファイルには★★逆斜線を 1 つも書かない★★**（★区切りは `String.fromCharCode(92)` で作る）。
String _basename(File f) {
  final sep = String.fromCharCode(92);
  return f.path.split('/').last.split(sep).last;
}

// ★★ 純粋関数にする —— ★★合成の入力で対を作れるようにするため★★ ★★
// ★**今日、★1 行目を持つ報告は★★1 つも無い★★**（★4 件とも免除）。
// → ★**ファイルからしか読めない形だと、★★下の 3 つの守りに対が 1 つも届かない★★**
//   （★実測: ★「どこかに在ればよい」に緩めても ★「空行を飛ばさない」に変えても★★0 件だった★★ / **D-27**）。
List<String> firstNonEmptyLinesOf(String content, int n) {
  final out = <String>[];
  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    out.add(line);
    if (out.length == n) break;
  }
  return out;
}

/// ★[content] の★最初の 2 行が★規約 6 の文言か。
bool hasHandoffBanner(String content) {
  final head = firstNonEmptyLinesOf(content, 2);
  return head.length == 2 && head[0] == _banner[0] && head[1] == _banner[1];
}

List<String> _firstNonEmptyLines(File f, int n) =>
    firstNonEmptyLinesOf(f.readAsStringSync(), n);

void main() {
  test('★★ 報告の置き場が実在する（★★綴りの受け / D-10★★）★★', () {
    expect(Directory(_reportDir).existsSync(), isTrue,
        reason: '★置き場が無ければ★下の 0 件は何も証明しない');
  });

  test('★★ 報告が 1 つ以上見つかる（★陽性対照）★★', () {
    expect(_reports(), isNotEmpty);
  });

  test('★★ 免除したファイルは 1 つ残らず実在する（★綴りの受け / D-10）★★', () {
    final actual = _reports().map(_basename).toSet();

    expect(actual.containsAll(_exempt), isTrue,
        reason: '★免除に★実在しない名前が混じっている: '
            '${_exempt.difference(actual)}');
  });

  test('★★ 免除したファイルは★実際に 1 行目を持っていない（★陽性対照）★★', () {
    // ★★ 免除が★意味を持つことを見る ★★
    //   ★**もし免除したファイルが★既に 1 行目を持っていたら、★★免除は空振りである★★。**
    final stillNeeded = <String>[];
    for (final f in _reports()) {
      if (!_exempt.contains(_basename(f))) continue;
      final head = _firstNonEmptyLines(f, 1);
      if (head.isEmpty || head.first != _banner.first) {
        stillNeeded.add(_basename(f));
      }
    }

    expect(stillNeeded, hasLength(_exempt.length),
        reason: '★★免除したファイルは★1 つ残らず★1 行目を持っていないこと★★');
  });

  test('★★ 免除されていない報告は★最初の 2 行が★規約 6 の文言である ★★', () {
    final bad = <String, List<String>>{};
    for (final f in _reports()) {
      if (_exempt.contains(_basename(f))) continue;
      if (!hasHandoffBanner(f.readAsStringSync())) {
        bad[_basename(f)] = _firstNonEmptyLines(f, 2);
      }
    }

    expect(bad, isEmpty,
        reason: '★★1 行目に規約 6 の 2 行を置くこと★★'
            '（★正は `docs/相談役への報告/README.md` の 4-6）。'
            '★見出しより★前★に置く');
  });

  test('★★ 写しは★正と 1 文字も違わない（★★README.md と突き合わせる★★）★★', () {
    // ★★ 写しを持つ以上、★食い違いを機械で見る ★★
    //   ★**先例は `user_question_test.dart` の受け 2**（★人の規律では忘れられる / **D-2**）。
    final readme = File('$_reportDir/README.md').readAsStringSync();

    for (final line in _banner) {
      expect(readme.contains(line), isTrue,
          reason: '★★README.md の規約 6 に★この行が字面のまま無い★★: $line');
    }
  });

  test('★★ 対: ★突き合わせは★1 文字の違いを見分ける（★陽性対照）★★', () {
    final readme = File('$_reportDir/README.md').readAsStringSync();
    final tampered = '${_banner.first}★';

    expect(readme.contains(tampered), isFalse);
  });

  // ★★ 合成の入力で当てる（★★今日 1 行目を持つ報告が 1 つも無いため★★）★★
  //
  // ★★ 3 つの守りに★対が 1 つも届いていなかった（**D-27**）★★
  // ★**「どこかに在ればよい」に緩めても ★「空行を飛ばさない」に変えても★★0 件だった★★**（★実測）。
  // ★**原因は★★対の形★★である** —— ★★見る相手（★1 行目を持つ報告）が★存在しない★★。
  //   ★**(b) 本命は空振りしていない**（★免除を 1 件外すと 3 件落ちる）／
  //   ★**(c) 仕込みは弱くない**（★守りを丸ごと緩めている）。
  group('★★ 合成の入力 —— ★1 行目の判定そのものを当てる ★★', () {
    String join(List<String> lines) => lines.join(String.fromCharCode(10));

    test('★★ 1 行目に在れば★通る ★★', () {
      final ok = join(<String>[..._banner, '', '# 相談役への報告 —— 2026-09-99']);

      expect(hasHandoffBanner(ok), isTrue);
    });

    test('★★ 6 行目に在っても★通らない（★★2026-09-02-02.md がその形である★★）★★', () {
      // ★★ この対が★この回の引き金そのものである ★★
      //   ★**あのファイルは 6 行目に指示を持っていた。★★それでも要約が渡った★★。**
      final late = join(<String>[
        '# 相談役への報告 —— 2026-09-99',
        '',
        '★この日の 2 回目である。',
        '★このセッションの範囲は X..HEAD である。',
        '',
        ..._banner,
      ]);

      expect(hasHandoffBanner(late), isFalse,
          reason: '★★見出しと段落のあとでは★1 行目ではない★★');
    });

    test('★★ 先頭の空行は★飛ばす（★★改行だけで落とさない★★）★★', () {
      final padded = join(<String>['', '   ', ..._banner, '', '# 見出し']);

      expect(hasHandoffBanner(padded), isTrue);
    });

    test('★★ 2 行目が違えば★通らない（★★1 行だけでは足りない★★）★★', () {
      final half = join(<String>[_banner.first, '# 見出し']);

      expect(hasHandoffBanner(half), isFalse);
    });

    test('★★ 順が逆なら★通らない ★★', () {
      final swapped = join(<String>[_banner.last, _banner.first, '# 見出し']);

      expect(hasHandoffBanner(swapped), isFalse);
    });
  });

}
