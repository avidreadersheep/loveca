/// ★★ 試験を消したときの記録が★★コミット本文に残っているか★★を見る ★★
///
/// ★★ 引き金 —— ★相談役の指示（運転指示【0】(2) / 2026-09-02）★★
/// ★**「★『消してよい条件』の 3 つ目に★受けを置くこと。**
/// ★**　★条件 3（件数の増減とともに記録する）が★★`CLAUDE.md` §3 という★人が書く表に依存している★★
/// ★**　（**D-2** の型）。★案 —— ★★消すコミットの本文に条件 1 / 2 / 3 を当てた結果を書く★★。
/// ★**　★コミットは後から直せない（**D-36**）ので★記録が確実に残る」。**
///
/// ★★ 何を見るか ★★
/// ★**本文に [markerPrefix] の行が在るコミットは、★★3 つの条件の行も持たねばならない★★。**
/// ★**中身が空の行は★★持っていないものとして数える★★**（★見出しだけ書いて通せない）。
///
/// ★★ 何を見ないか（★★言い切る★★）★★
///
/// | # | ★見ないもの | ★理由 |
/// |---|---|---|
/// | ★**1** | ★★**記録を★書かなかったこと**★★ | ★**★消したことが★★どこにも現れないなら、★機械には見えない★★**（★下の「測った」） |
/// | ★**2** | ★**条件 1 / 2 の★★中身が正しいか★★** | ★**「この試験と★あの試験が★★同じものを見ているか★★」を問う口は★どこにも無い**（**D-27** の本文と同じ理由） |
/// | ★**3** | ★**行の途中に書かれた記録** | ★**行頭で見る**（★先例は `core_boundary_test.dart` の行頭の判定）。★★対で固定した★★ |
///
/// ★★ 件数の増減から★機械で見つける形は★★成り立たない（★測った / 2026-09-02）★★ ★★
/// ★**先に「`CLAUDE.md` §3 の件数が★★減った commit★★を探し、★そこに記録を要求する」形を測った。**
///
/// | ★何 | ★実測（2026-09-02 / ★`git log -p -- CLAUDE.md` / ★205 commit） |
/// |---|---|
/// | ★件数が減った commit | ★★**1 件だけ**★★（`09c1054` / ★`loveca-ui` 875 → 874） |
/// | ★★**この規約を生んだ commit**★★（`642d66c` / §89 で 1 件消した） | ★★**減っていない**★★ —— ★`loveca-server` 335 → **349**（★★差し引き +14★★） |
///
/// → ★★**消したその回に★14 件足していたので、★件数は★増えている**★★。
/// → ★★**件数の増減では★★狙った 1 件がそもそも見えない★★。★この形は採らない。**★★
/// ★**さらに、★★§3 を更新しなければ★何も起きない★★** —— ★**D-2 は★この受けでは閉じない**（★上の 1）。
///
/// ★★ 今日は★実際のコミットに 1 件も当たらない（★★隠さない★★）★★
/// ★**この規約より前のコミットは★★1 つも記録を持たない★★**（**D-36** —— ★本文は後から直せない）。
/// → ★**[invalidCommits] に★★合成の入力で対を置いた★★**（**D-27** の (乙) —— ★上流に主体が 0 のとき）。
/// ★**§89 の 1 件の記録は★`CLAUDE.md` §3 に在る**（★2026-09-02 に★あとから当てて足した分）。
///
/// ★★ 総合ルールの条番号は 1 つも引かない ★★
/// ★これはゲームの規則ではなく★★文書の保守★★である。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

final _repoRoot = Directory('..');

/// ★★ 記録の見出し（★★行頭に置くこと★★）★★
const markerPrefix = '試験を消した:';

/// ★★ 3 つの条件（**D-27** の 3 つ目の追記）★★
const conditionPrefixes = <String>[
  '条件 1（別の守り）:',
  '条件 2（実測で落ちた）:',
  '条件 3（件数の増減）:',
];

/// ★行頭に `prefix` の行が在るか（★中身は問わない）。
bool _hasPrefix(String body, String prefix) {
  for (final line in const LineSplitter().convert(body)) {
    if (line.trimLeft().startsWith(prefix)) return true;
  }
  return false;
}

/// ★行頭に `prefix` の行が在り、★★続きが空でない★★か。
bool _hasFilled(String body, String prefix) {
  for (final line in const LineSplitter().convert(body)) {
    final text = line.trimLeft();
    if (!text.startsWith(prefix)) continue;
    if (text.substring(prefix.length).trim().isNotEmpty) return true;
  }
  return false;
}

/// ★★ 本文に足りない見出しを返す ★★
///
/// ★**`null`** —— ★★記録が 1 つも無い★★（★これは誤りではない。★消していないだけである）。
/// ★**空の列** —— ★記録が揃っている。
/// ★**空でない列** —— ★足りない見出し。
///
/// ★★ 見出しだけ書いて通せない ★★
/// ★**[markerPrefix] の行が在っても★★続きが空なら★足りないものとして返す★★。**
List<String>? missingConditions(String body) {
  if (!_hasPrefix(body, markerPrefix)) return null;
  final missing = <String>[];
  if (!_hasFilled(body, markerPrefix)) missing.add(markerPrefix);
  for (final prefix in conditionPrefixes) {
    if (!_hasFilled(body, prefix)) missing.add(prefix);
  }
  return missing;
}

/// ★★ コミット 1 件 ★★
typedef Commit = ({String hash, String body});

/// ★★ 記録が欠けているコミットを返す（★本番も対も★この関数を通す / **D-27** の (甲)）★★
List<String> invalidCommits(Iterable<Commit> commits) {
  final out = <String>[];
  for (final commit in commits) {
    final missing = missingConditions(commit.body);
    if (missing == null || missing.isEmpty) continue;
    out.add('${commit.hash}: 足りない見出し $missing');
  }
  return out;
}

/// ★リポジトリの全コミットの本文を読む。
///
/// ★**区切りは★★制御文字である★★**（★本文に現れない）。
List<Commit> _commitsFromGit() {
  // ★★ 制御文字を★★字面で書かない★★（**D-38** —— ★見えない 1 バイトは★経路で化ける）★★
  final recordSeparator = String.fromCharCode(30);
  final fieldSeparator = String.fromCharCode(31);
  final result = Process.runSync(
    'git',
    <String>['log', '--format=$recordSeparator%H$fieldSeparator%B'],
    workingDirectory: _repoRoot.path,
    stdoutEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('★`git log` が失敗した: ${result.stderr}');
  }
  final out = <Commit>[];
  for (final chunk in (result.stdout as String).split(recordSeparator)) {
    if (chunk.trim().isEmpty) continue;
    final at = chunk.indexOf(fieldSeparator);
    if (at < 0) continue;
    out.add((hash: chunk.substring(0, at), body: chunk.substring(at + 1)));
  }
  return out;
}

String _record(String summary, List<String> bodies) =>
    <String>['$markerPrefix $summary', ...bodies].join('\n');

void main() {
  group('★★ 陽性対照 —— ★判定が働くこと（**D-10**）★★', () {
    test('★★ 揃っていれば★足りないものは無い ★★', () {
      final body = _record('★丸めていないことを値で見る 1 件', <String>[
        '${conditionPrefixes[0]} §63-7 の宣言の字面を見る走査',
        '${conditionPrefixes[1]} 仕込み (F) で 1 件落ちる',
        '${conditionPrefixes[2]} loveca-server 335 → 349（★足した 15 − 消した 1）',
      ]);

      expect(missingConditions(body), isEmpty);
    });

    test('★★ 見出しが 1 つも無ければ★記録ではない（★誤りではない）★★', () {
      expect(missingConditions('★ふつうのコミット本文'), isNull);
    });

    for (var i = 0; i < conditionPrefixes.length; i++) {
      test('★★ 条件 ${i + 1} が無ければ★足りないと返す ★★', () {
        final bodies = <String>[
          for (var j = 0; j < conditionPrefixes.length; j++)
            if (j != i) '${conditionPrefixes[j]} ★中身',
        ];

        expect(missingConditions(_record('★何か', bodies)),
            <String>[conditionPrefixes[i]]);
      });
    }

    test('★★ 見出しだけ書いて★中身が空なら★通らない ★★', () {
      final body = <String>[
        markerPrefix,
        '${conditionPrefixes[0]} ★中身',
        conditionPrefixes[1],
        '${conditionPrefixes[2]} ★中身',
      ].join('\n');

      expect(missingConditions(body),
          <String>[markerPrefix, conditionPrefixes[1]]);
    });

    test('★★ 対: ★行の途中に書いても★記録にならない（★行頭で見ている）★★', () {
      expect(missingConditions('★この回は $markerPrefix と書いただけである'), isNull);
    });
  });

  group('★★ 走査そのものの対（**D-27** の (乙) —— ★★今日★実物が 0 件である★★）★★', () {
    test('★★ 欠けたコミットを★拾う ★★', () {
      final got = invalidCommits(<Commit>[
        (hash: 'aaaa111', body: '★ふつうの本文'),
        (hash: 'bbbb222', body: _record('★何か', <String>[])),
      ]);

      expect(got.length, 1);
      expect(got.single, contains('bbbb222'));
    });

    test('★★ 対: ★揃っていれば★拾わない ★★', () {
      final body = _record('★何か', <String>[
        for (final prefix in conditionPrefixes) '$prefix ★中身',
      ]);

      expect(
          invalidCommits(<Commit>[(hash: 'cccc333', body: body)]), isEmpty);
    });
  });

  group('★★ 見出しの字面は★doc と 1 文字も違わない（**D-37 の裏**）★★', () {
    // ★★ 両側が★同じ定数を読むのではない ★★
    // ★**人は★doc を見て本文を書く。★★doc と試験が黙って割れると、★書いた記録が通らない★★。**
    // ★**先例は §72 の (D)(J) / §80-6 の (M)**（★どちらも★★引用符ごと在ることを見る★★）。
    test('★★ 4 つの見出しが★`ルール整合性チェック_v1.06.md` に★そのまま在る ★★', () {
      final doc = File(p.join(_repoRoot.path, 'ルール整合性チェック_v1.06.md'))
          .readAsStringSync();

      final prefixes = <String>[markerPrefix, ...conditionPrefixes];
      // ★★ 空の列なら★この群は何も見ていない（**D-10**）★★
      expect(prefixes.length, 1 + conditionPrefixes.length);

      for (final prefix in prefixes) {
        expect(doc.contains(prefix), isTrue,
            reason: '★★doc に無い見出しは★誰も書けない★★: $prefix');
      }
    });

    test('★★ 対: ★在りもしない見出しは★doc に無い（★陽性対照）★★', () {
      final doc = File(p.join(_repoRoot.path, 'ルール整合性チェック_v1.06.md'))
          .readAsStringSync();

      expect(doc.contains('条件 4（SPIKE）:'), isFalse);
    });
  });

  group('★★ 実物の履歴（★`git log`）★★', () {
    test('★★ 履歴が読める（★陽性対照 —— ★★0 件を「無い」と読ませない★★）★★', () {
      expect(_commitsFromGit(), isNotEmpty,
          reason: '★★`git log` が 0 件なら★この群は何も見ていない★★');
    });

    test('★★ 記録を持つコミットは★3 つの条件を 1 つ残らず持つ ★★', () {
      expect(invalidCommits(_commitsFromGit()), isEmpty,
          reason: '★★本文は後から直せない**（**D-36**）。'
              '★足りないぶんは `CLAUDE.md` §3 に理由つきで書くこと★★');
    });
  });
}
