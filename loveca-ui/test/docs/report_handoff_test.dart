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

/// リポジトリの根（★`loveca-ui` を作業ディレクトリとした相対パス）。
const _repoDir = '..';

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

/// ★★ 規約 4-5-2 —— ★端末へ出した字面を★報告に写す ★★
///
/// ★**README の §4-5-2 が「★報告の★★最後の節★★にそのまま写す」と定めている。**
/// ★★**規約 6 と違って★機械が見ていなかった**★★ —— ★**04 / 05 / 06 は持ち、★★07 が落とした★★**
///   （★2026-09-02 実測 / ★★規約が在るのに★次の回で抜けた ＝ **D-2** の型★★）。
const _terminalSectionMark = '端末へ出した字面';

/// ★★ 免除するファイル（★★理由は 2 種類ある。★混ぜない★★ / ★先例は `CLAUDE.md` §8）★★
///
/// | ★理由 | ★ファイル |
/// |---|---|
/// | ★**書いた時点にこの規約が無かった** | ★`2026-09-01-01` / `-02` / `2026-09-02-01` / `-02` / `-03` |
/// | ★★**規約が在ったのに★落とした**★★ | ★★`2026-09-02-07`★★（★★1 文字も書き換えない★★ / **D-35**） |
/// ★★ 規約 1 ＋ 規約 2 —— ★あとから触られた報告を★免除する ★★
///
/// ★★ 理由は 1 つ —— ★★書いた時点にこの受けが無かった★★ ★★
/// ★**`2026-09-01-02.md` は★★README 4-1 が「★書いたあとに作業を続けた」実物として名指ししている回★★である**
///   （★実測: ★★3 commit★★ —— ★書いた回 ／ ★★追記した回★★ ／ ★数を外した回）。
/// ★★**1 文字も書き換えない**★★（**D-35**）。
const _exemptTouchedTwice = <String>{
  '2026-09-01-02.md',
};

const _exemptTerminalSection = <String>{
  '2026-09-01-01.md',
  '2026-09-01-02.md',
  '2026-09-02-01.md',
  '2026-09-02-02.md',
  '2026-09-02-03.md',
  '2026-09-02-07.md',
};

/// ★[content] に★端末へ出した字面の節が在るか（★★見出しの行で見る★★）。
///
/// ★★ 見出しの字面を★固定しない ★★
/// ★**実物は 2 通りある**（★`§4-5-2 の測定用の記録` / ★`規約 4-5-2 の受け` / ★2026-09-02 実測）。
/// → ★**見るのは★★見出しの行に [_terminalSectionMark] が在ること★★だけである。**
bool hasTerminalSection(String content) {
  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trimLeft();
    if (!line.startsWith('#')) continue;
    if (line.contains(_terminalSectionMark)) return true;
  }
  return false;
}

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

// ★★ 規約 1 / 2 / 3 / 5 に★1 つずつ当てた（2026-09-03 / ★運転指示【0】(3)）★★
//
// ★★ 引き金 —— ★規約 4-5-2 が★機械に見られていなかったから落ちた ★★
// ★**相談役の指示**: 「★規約 4-5-2 は機械が見ていなかったから落ちた。★★他の 4 つも同じ状態である★★。
// ★★1 つずつ当てること —— 機械で見られるか / 見られないか★★。★見られるものは受けを置くこと。
// ★★見られないものは、なぜ見られないかを書くこと★★」。
//
// | ★規約 | ★機械で見られるか | ★この検査が見るもの |
// |---|---|---|
// | ★**1**（★セッションの最後に書く） | ★★**帰結だけ**★★ | ★★報告を触った commit が★2 件以上になっていないこと★★ |
// | ★**2**（★名前 / ★日付 / ★既存を書き換えない） | ★★**見られる**★★ | ★形 ／ ★日ごとの連番 ／ ★未来の日付でない ／ ★追加した commit の日付と一致 ／ ★上と同じ |
// | ★**3**（★動きうる数を書かない） | ★★**見られない**★★ | ★★—— ★理由は下★★ |
// | ★**5**（★端末に要約を書かない） | ★★**見られない**★★ | ★★代理だけ★★ —— ★写された字面が★★2 行を超えないこと★★ |
//
// ★★ 規約 3 が★機械で見られない理由（★★D-30 とは列が違う★★）★★
// ★**D-30 は「★禁止対象を説明する文が★同じ字面を含む」という★★字面の問題★★である。**
// ★**規約 3 は★★意味の問題★★である** —— ★★「動きうる数」と「記録の数」は★字面で 1 ミリも違わない★★。
// ★**README 自身が「★『何をしたか』の表は数ではない。★★行数を書くのが数である★★」と★分けている。**
// ★**「範囲を指す」を★要求として見る形も採らない** —— ★★あれは手段の例であって要求ではない★★
//   （★2026-09-03 実測: ★10 件のうち 4 件が★範囲を 1 つも書いていない。★★4 件とも★数を書いていないだけである★★）。
//
// ★★ 規約 5 の代理が★覆う範囲（**§7-11**）★★
// | ★覆う | ★**報告に★★写された★★字面が★2 行を超えないこと** |
// |---|---|
// | ★★**覆わない**★★ | ★★**端末に★実際に★何を出したか**★★（★★写しが正直であることを★前提にしている★★ / ★型は **D-2**） |
//
// ★★ 規約 1 と 規約 2 は★別の規約だが、★観測できる帰結が 1 つに重なる ★★
// ★**規約 1 は「★いつ書くか」、★規約 2 は「★書き換えないこと」。★★別である★★。**
// ★**それでも★★どちらも「あとから触れば commit が 2 件以上になる」ところに出る★★。**
// ★**実測（2026-09-03）**: ★★10 件のうち 1 件だけが 3 commit★★ ——
//   ★`2026-09-01-02.md`（★★README 4-1 が「書いたあとに作業を続けた」実物として名指ししている回★★）。
/// ★[rel]（★リポジトリ相対）を触った commit の数。
///
/// ★★ 改名は追わない。★報告は改名されない★★（★追うと `--follow` が要り、★引数の形が変わる）。
int commitsTouching(String rel) {
  final r = Process.runSync(
    'git',
    <String>['-c', 'core.quotepath=false', 'log', '--format=%H', '--', rel],
    workingDirectory: _repoDir,
    stdoutEncoding: utf8,
  );
  if (r.exitCode != 0) {
    throw StateError('★`git log` が失敗した: ${r.stderr}');
  }
  return const LineSplitter()
      .convert(r.stdout as String)
      .where((l) => l.trim().isNotEmpty)
      .length;
}

/// ★[rel] を★★追加した★★ commit の日付（`YYYY-MM-DD`）。★まだコミットされていなければ空。
String addedDateOf(String rel) {
  final r = Process.runSync(
    'git',
    <String>[
      '-c', 'core.quotepath=false', 'log', '--diff-filter=A',
      '--format=%ad', '--date=short', '--', rel,
    ],
    workingDirectory: _repoDir,
    stdoutEncoding: utf8,
  );
  if (r.exitCode != 0) {
    throw StateError('★`git log` が失敗した: ${r.stderr}');
  }
  final lines = const LineSplitter()
      .convert(r.stdout as String)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  return lines.isEmpty ? '' : lines.last.trim();
}

/// ★ファイル名が `YYYY-MM-DD-NN.md` の形か。
///
/// ★★ 正規表現を使わない ★★
/// ★**このファイルには★★逆斜線を 1 つも書かない★★**（**D-38** —— ★上の [_basename] の断り書き）。
bool isReportName(String name) {
  if (!name.endsWith('.md')) return false;
  final stem = name.substring(0, name.length - 3);
  final parts = stem.split('-');
  if (parts.length != 4) return false;
  const widths = <int>[4, 2, 2, 2];
  for (var i = 0; i < 4; i++) {
    if (parts[i].length != widths[i]) return false;
    for (final c in parts[i].codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
  }
  return true;
}

/// ★ファイル名から日付の部分（`YYYY-MM-DD`）を取る。★形でなければ空。
String dateOfReportName(String name) =>
    isReportName(name) ? name.substring(0, 10) : '';

/// ★ファイル名から連番（`NN`）を取る。★形でなければ -1。
int serialOfReportName(String name) =>
    isReportName(name) ? int.parse(name.substring(11, 13)) : -1;

/// ★連番が 1 から欠けずに並んでいるか。
///
/// ★★ 純粋関数にする —— ★合成の入力で対を作るため（**D-27**）★★
/// ★**実物は★今日 1 件も欠けていない**ので、★★ファイルからしか見えない形だと対が届かない★★。
bool serialsAreDense(List<int> serials) {
  final sorted = <int>[...serials]..sort();
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i] != i + 1) return false;
  }
  return true;
}

/// ★[date]（`YYYY-MM-DD`）が [today] より後か。
///
/// ★★ 同上 —— ★実物に★未来の日付は 1 件も無い ★★
bool isFutureDate(String date, DateTime today) =>
    DateTime.parse(date)
        .isAfter(DateTime(today.year, today.month, today.day));

/// ★ファイル名の日付と、★追加した commit の日付が一致するか。
///
/// ★★ 同上 —— ★実物は★今日 10/10 で一致している ★★
/// ★**[addedDate] が空（★★まだコミットされていない★★）なら★比べようが無いので真を返す。**
bool addedDateMatches(String name, String addedDate) =>
    addedDate.isEmpty || addedDate == dateOfReportName(name);

/// ★写された字面が★★規約 5 の上限（★パスと 1 文）に収まっているか★★。
///
/// ★★ 純粋関数にする —— ★★上限そのものに対が届くようにするため★★（**D-27**）★★
/// ★**実物は★今日★4 件とも 2 行である**ので、★★上限を緩めても★1 件も落ちない★★。
bool isTerminalQuoteWithinLimit(List<String> lines) =>
    lines.isNotEmpty && lines.length <= 2;

/// ★★ 端末へ出した字面の節の中の★★囲みの中身★★（★非空行だけ）★★
///
/// ★★ 純粋関数にする —— ★合成の入力で対を作るため（**D-27** の (甲)）★★
/// ★**見出しの行から★次の見出しまでを切り、★その中の★★最初の囲み★★を返す。**
List<String> terminalQuoteLines(String content) {
  final lines = const LineSplitter().convert(content);
  var i = 0;
  while (i < lines.length) {
    final line = lines[i].trimLeft();
    if (line.startsWith('#') && line.contains(_terminalSectionMark)) break;
    i++;
  }
  if (i >= lines.length) return const <String>[];
  final fence = '${String.fromCharCode(96)}${String.fromCharCode(96)}'
      '${String.fromCharCode(96)}';
  final out = <String>[];
  var inside = false;
  for (var k = i + 1; k < lines.length; k++) {
    final raw = lines[k];
    final line = raw.trimLeft();
    if (!inside && line.startsWith('#')) break;
    if (line.startsWith(fence)) {
      if (inside) break;
      inside = true;
      continue;
    }
    if (inside && raw.trim().isNotEmpty) out.add(raw.trim());
  }
  return out;
}

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

  group('★★ 規約 4-5-2 —— ★端末へ出した字面が★報告に在る ★★', () {
    test('★★ 免除したファイルは 1 つ残らず実在する（★綴りの受け / D-10）★★', () {
      final actual = _reports().map(_basename).toSet();

      expect(actual.containsAll(_exemptTerminalSection), isTrue,
          reason: '★免除に★実在しない名前が混じっている: '
              '${_exemptTerminalSection.difference(actual)}');
    });

    test('★★ 免除したファイルは★実際に節を持っていない（★陽性対照）★★', () {
      for (final f in _reports()) {
        if (!_exemptTerminalSection.contains(_basename(f))) continue;

        expect(hasTerminalSection(f.readAsStringSync()), isFalse,
            reason: '★★免除が空振りしている★★: ${_basename(f)}');
      }
    });

    test('★★ 免除されていない報告は★節を持つ ★★', () {
      for (final f in _reports()) {
        if (_exemptTerminalSection.contains(_basename(f))) continue;

        expect(hasTerminalSection(f.readAsStringSync()), isTrue,
            reason: '★★README の §4-5-2 —— ★端末へ出した字面を★最後の節に写すこと★★: '
                '${_basename(f)}');
      }
    });

    test('★★ 合成の入力 —— ★見出しの行でだけ数える ★★', () {
      expect(hasTerminalSection('## ★ 10. 端末へ出した字面'), isTrue);
      expect(hasTerminalSection('★本文に 端末へ出した字面 と書いただけ'), isFalse);
      expect(hasTerminalSection('## ★ 別の見出し'), isFalse);
    });
  });

  // ★★ 規約 1 ＋ 規約 2 —— ★観測できる帰結が 1 つに重なる（★上の断り書きが正）★★
  group('★★ 規約 1 ＋ 規約 2 —— ★報告は★あとから触られていない ★★', () {
    test('★★ 免除したファイルは 1 つ残らず実在する（★綴りの受け / D-10）★★', () {
      final actual = _reports().map(_basename).toSet();

      expect(actual.containsAll(_exemptTouchedTwice), isTrue,
          reason: '★免除に★実在しない名前が混じっている: '
              '${_exemptTouchedTwice.difference(actual)}');
    });

    test('★★ 免除したファイルは★実際に 2 件以上である（★陽性対照）★★', () {
      // ★★ 免除が空振りしていないことを見る ★★
      //   ★**もし 1 件だったら、★★免除は何も免除していない★★。**
      for (final name in _exemptTouchedTwice) {
        expect(commitsTouching('docs/相談役への報告/$name'), greaterThan(1),
            reason: '★★免除が空振りしている★★: $name');
      }
    });

    test('★★ 履歴が読める（★陽性対照 —— ★★0 件を「無い」と読ませない★★）★★', () {
      final counted = _reports()
          .map((f) => commitsTouching('docs/相談役への報告/${_basename(f)}'))
          .where((n) => n > 0)
          .length;

      expect(counted, greaterThan(0), reason: '★★`git log` が全件 0 なら★この群は何も見ていない★★');
    });

    test('★★ 免除されていない報告は★2 件以上になっていない ★★', () {
      // ★★ 0 件は通る。★隠さない ★★
      //   ★**まだコミットされていない報告（★★書いている最中のもの★★）が 0 件である。**
      //   ★**「1 件ちょうど」を要求すると★★その回の報告が必ず落ちる★★。**
      final bad = <String, int>{};
      for (final f in _reports()) {
        final name = _basename(f);
        if (_exemptTouchedTwice.contains(name)) continue;
        final n = commitsTouching('docs/相談役への報告/$name');
        if (n > 1) bad[name] = n;
      }

      expect(bad, isEmpty,
          reason: '★★報告は★書いたあとに触らない★★'
              '（★規約 1: ★セッションの最後に書く ／ ★規約 2: ★既存を書き換えない）');
    });
  });

  group('★★ 規約 2 —— ★ファイル名 ★★', () {
    test('★★ 形は `YYYY-MM-DD-NN.md` である ★★', () {
      final bad = _reports().map(_basename).where((n) => !isReportName(n));

      expect(bad, isEmpty);
    });

    test('★★ 日ごとの連番は 01 から欠けない ★★', () {
      final byDate = <String, List<int>>{};
      for (final f in _reports()) {
        final name = _basename(f);
        byDate.putIfAbsent(dateOfReportName(name), () => <int>[])
            .add(serialOfReportName(name));
      }
      final bad = <String, List<int>>{};
      byDate.forEach((date, serials) {
        serials.sort();
        if (!serialsAreDense(serials)) bad[date] = serials;
      });

      expect(bad, isEmpty, reason: '★★`NN` は 01 から連番である★★');
    });

    test('★★ 未来の日付を名乗っていない（★★日付は確かめてから書く★★）★★', () {
      final today = DateTime.now();
      final bad = <String>[];
      for (final f in _reports()) {
        final name = _basename(f);
        if (isFutureDate(dateOfReportName(name), today)) bad.add(name);
      }

      expect(bad, isEmpty, reason: '★★`date` で確かめてから書くこと★★');
    });

    test('★★ コミット済みの報告は★名前の日付 ＝ 追加した commit の日付 ★★', () {
      // ★★ 覆わないものを書く ★★
      //   ★**まだコミットされていない報告は★★比べる相手が無い★★**（★0 件 ＝ 空文字）。
      final bad = <String, String>{};
      for (final f in _reports()) {
        final name = _basename(f);
        final added = addedDateOf('docs/相談役への報告/$name');
        if (!addedDateMatches(name, added)) bad[name] = added;
      }

      expect(bad, isEmpty,
          reason: '★★名前の日付と★実際に置いた日が食い違っている★★');
    });

    test('★★ 合成の入力 —— ★連番の欠けを見分ける ★★', () {
      expect(serialsAreDense(<int>[1, 2, 3]), isTrue);
      expect(serialsAreDense(<int>[3, 1, 2]), isTrue);
      expect(serialsAreDense(<int>[1, 3]), isFalse, reason: '★★02 が欠けている★★');
      expect(serialsAreDense(<int>[2, 3]), isFalse, reason: '★★01 から始まっていない★★');
      expect(serialsAreDense(<int>[1, 1]), isFalse, reason: '★★同じ番号が 2 つ★★');
      expect(serialsAreDense(<int>[]), isTrue);
    });

    test('★★ 合成の入力 —— ★未来の日付を見分ける ★★', () {
      final today = DateTime(2026, 9, 3);

      expect(isFutureDate('2026-09-03', today), isFalse, reason: '★今日は未来ではない');
      expect(isFutureDate('2026-09-02', today), isFalse);
      expect(isFutureDate('2026-09-04', today), isTrue);
    });

    test('★★ 合成の入力 —— ★名前の日付と★置いた日の食い違いを見分ける ★★', () {
      expect(addedDateMatches('2026-09-03-01.md', '2026-09-03'), isTrue);
      expect(addedDateMatches('2026-09-03-01.md', '2026-09-04'), isFalse);
      expect(addedDateMatches('2026-09-03-01.md', ''), isTrue,
          reason: '★★まだコミットされていなければ★比べる相手が無い★★');
    });

    test('★★ 合成の入力 —— ★名前の判定そのものを当てる ★★', () {
      expect(isReportName('2026-09-03-01.md'), isTrue);
      expect(isReportName('README.md'), isFalse);
      expect(isReportName('2026-09-03-1.md'), isFalse);
      expect(isReportName('2026-9-03-01.md'), isFalse);
      expect(isReportName('20xx-09-03-01.md'), isFalse);
      expect(isReportName('2026-09-03-01.txt'), isFalse);
      expect(dateOfReportName('2026-09-03-07.md'), '2026-09-03');
      expect(serialOfReportName('2026-09-03-07.md'), 7);
      expect(serialOfReportName('README.md'), -1);
    });
  });

  group('★★ 規約 5 の★代理 —— ★写された字面は★2 行を超えない ★★', () {
    // ★★ これは規約 5 そのものではない（★上の断り書きが正）★★
    //   ★**覆うのは「★写しが★パスと 1 文だけか」まで。**
    //   ★★**端末に実際に何を出したかは★1 バイトも観測していない**★★（★型は **D-2**）。
    test('★★ 節を持つ報告は★写しが 2 行以下である ★★', () {
      final bad = <String, int>{};
      for (final f in _reports()) {
        final name = _basename(f);
        if (_exemptTerminalSection.contains(name)) continue;
        final lines = terminalQuoteLines(f.readAsStringSync());
        if (!isTerminalQuoteWithinLimit(lines)) bad[name] = lines.length;
      }

      expect(bad, isEmpty,
          reason: '★★端末に出すのは★パスと 1 文だけである★★'
              '（★正は `docs/相談役への報告/README.md` の 4-5）');
    });

    test('★★ 合成の入力 —— ★上限そのものを当てる ★★', () {
      expect(isTerminalQuoteWithinLimit(<String>['パス', '1 文']), isTrue);
      expect(isTerminalQuoteWithinLimit(<String>['パス']), isTrue);
      expect(isTerminalQuoteWithinLimit(<String>['パス', '1 文', '要約']), isFalse);
      expect(isTerminalQuoteWithinLimit(<String>[]), isFalse,
          reason: '★★節は在るのに★囲みが無い形も★通さない★★');
    });

    test('★★ 合成の入力 —— ★囲みの中身を取る ★★', () {
      final fence = String.fromCharCode(96) * 3;
      String join(List<String> l) => l.join(String.fromCharCode(10));

      final ok = join(<String>[
        '## ★ 10. ★端末へ出した字面',
        '',
        fence,
        'docs/相談役への報告/2026-09-99-01.md',
        '',
        'このファイルを開いて、全文をそのまま貼ってください。',
        fence,
      ]);

      expect(terminalQuoteLines(ok), hasLength(2));
    });

    test('★★ 合成の入力 —— ★要約を出すと★3 行以上になる ★★', () {
      final fence = String.fromCharCode(96) * 3;
      String join(List<String> l) => l.join(String.fromCharCode(10));

      final summary = join(<String>[
        '## ★ 10. ★端末へ出した字面',
        fence,
        'この回でやったこと: 1) ... 2) ... 3) ...',
        '件数は 53 / 564 / 280 / 1180 / 349 である。',
        'docs/相談役への報告/2026-09-99-01.md',
        fence,
      ]);

      expect(terminalQuoteLines(summary).length, greaterThan(2));
    });

    test('★★ 合成の入力 —— ★閉じの囲みで止まる（★★後ろの行を拾わない★★）★★', () {
      // ★★ この対は★測って足した（**D-27** の (a) 対の形）★★
      //   ★**「閉じの囲みで break する」を外しても★★0 件だった★★**（★2026-09-03 実測）——
      //   ★**実物の報告は★★節の最後が囲みで終わっており、★後ろに行が 1 つも無い★★。**
      final fence = String.fromCharCode(96) * 3;
      String join(List<String> l) => l.join(String.fromCharCode(10));

      final trailing = join(<String>[
        '## ★ 10. ★端末へ出した字面',
        fence,
        'docs/相談役への報告/2026-09-99-01.md',
        fence,
        '★この行は★節の中だが★囲みの外である',
        '★これも拾ってはならない',
      ]);

      expect(terminalQuoteLines(trailing), <String>[
        'docs/相談役への報告/2026-09-99-01.md',
      ]);
    });

    test('★★ 合成の入力 —— ★節が無ければ★空である ★★', () {
      expect(terminalQuoteLines('# 見出しだけ'), isEmpty);
    });

    test('★★ 合成の入力 —— ★次の見出しで切れる（★★別の節の囲みを拾わない★★）★★', () {
      final fence = String.fromCharCode(96) * 3;
      String join(List<String> l) => l.join(String.fromCharCode(10));

      final other = join(<String>[
        '## ★ 10. ★端末へ出した字面',
        '',
        '## ★ 11. ★別の節',
        fence,
        'ここは別の節である',
        fence,
      ]);

      expect(terminalQuoteLines(other), isEmpty);
    });
  });
}
