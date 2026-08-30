/// ★★ コードが引く決定番号・所見番号が台帳に実在すること（未決 **U32** / 新所見 **D-29**）★★
///
/// **D-29** の機構 —— ★**参照の側だけを走査して 0 件を得て、採番の側を突き合わせずに
/// 「記録が無い」と結論した。**★ 同じ 0 件が「記録が失われた」と
/// 「参照が別の記法に置き換わった」の 2 つの意味を持っていた。
/// → ★**区別するには採番の側（番号空間）を見るしかない。**
///
/// ★★ この手が効くのは「台帳がリポジトリ内に在る番号体系」だけである ★★
/// 総合ルールの条番号には使えない —— `docs/LoveLiveTCG_cr_1.06_260428.pdf` は
/// **git 管理外**（`CLAUDE.md` §1）で、**突き合わせる相手がリポジトリに存在しない**（D-29）。
///
/// ★★ 見ない形を先に書く —— 素の `DNN` ★★
/// `決定 ` を伴わない素の `DNN` は**対象にしない。**
/// 実データのカード番号と字面が同じだからである（`loveca-core/test/refresh_test.dart` の
/// `'D0'` / `'D1'` / `'D2'`）。★**機械には分けられない**（旧・同期設計番号について
/// **D-5** が書いているのと同じ形）。→ ★**その字面が実在することを下で固定し、
/// 「見ていない」ことの理由を残す**（★理由の無い除外を作らない / **D-30**）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 決定番号の台帳。
final _decisions = File(p.join('..', 'docs', '決定事項一覧.md'));

/// 所見番号の台帳。
final _findings = File(p.join('..', 'ルール整合性チェック_v1.06.md'));

const _roots = <String>[
  'lib',
  'test',
  '../loveca-core/lib',
  '../loveca-core/test',
  '../loveca-db/lib',
  '../loveca-db/test',
];

/// ★コードが引く決定番号。**`決定 DNN` の形だけ**（上の library doc）。
final _decisionRef = RegExp(r'決定 (D\d+)');

/// ★コードが引く所見番号。`D-NN`。
final _findingRef = RegExp(r'(?<![A-Za-z0-9_])(D-\d+)(?![0-9])');

/// ★台帳 §1 の索引行。`| **D62** | …`
final _ledgerRow = RegExp(r'^\| \*\*(D\d+)\*\*', multiLine: true);

/// ★台帳の詳細見出し。`### ★ D90 の詳細（…）` / `### ★★ D100 / D101 / D102 の詳細…`
final _ledgerDetail = RegExp(r'^#+ .*の詳細.*$', multiLine: true);

/// ★所見の台帳の見出し。`### D-36. …`
final _findingHeading = RegExp(r'^### (D-\d+)\.', multiLine: true);

final _anyDecision = RegExp(r'D\d+');

/// 台帳 §1 の索引に在る番号。
Set<String> ledgerRows() => _ledgerRow
    .allMatches(_decisions.readAsStringSync())
    .map((m) => m.group(1)!)
    .toSet();

/// 詳細節が在る番号（★見出し行に現れるものをすべて採る。範囲表記も 1 行に載る）。
Set<String> ledgerDetails() => _ledgerDetail
    .allMatches(_decisions.readAsStringSync())
    .expand((m) => _anyDecision.allMatches(m.group(0)!).map((d) => d.group(0)!))
    .toSet();

/// ★台帳に実在する決定番号 ＝ 索引行 ∪ 詳細見出し。
Set<String> ledgerDecisions() => {...ledgerRows(), ...ledgerDetails()};

/// 台帳に実在する所見番号。
Set<String> ledgerFindings() => _findingHeading
    .allMatches(_findings.readAsStringSync())
    .map((m) => m.group(1)!)
    .toSet();

/// [source] が引く番号を取り出す。★分類器そのもの。陽性対照はここへ当てる。
Set<String> decisionRefsIn(String source) =>
    _decisionRef.allMatches(source).map((m) => m.group(1)!).toSet();

Set<String> findingRefsIn(String source) =>
    _findingRef.allMatches(source).map((m) => m.group(1)!).toSet();

/// 木をなめて、番号 → それを引いているファイル名 の対応を作る。
Map<String, Set<String>> _collect(Set<String> Function(String) extract) {
  final refs = <String, Set<String>>{};
  for (final root in _roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      for (final number in extract(entity.readAsStringSync())) {
        refs.putIfAbsent(number, () => <String>{}).add(p.basename(entity.path));
      }
    }
  }
  return refs;
}

void main() {
  group('★★ 陽性対照 —— 取り出しと突き合わせが働くこと ★★', () {
    // ★★ 合成の番号も字面で書かない ★★
    //   書くと**この走査自身が拾い**、下の「1 つ残らず台帳に在る」が自分のせいで落ちる
    //   （**D-30** —— 禁止対象を説明する文は禁止対象と同じ字面を必ず含む）。
    //   → 連結で組む。`D` の次が数字にならないので走査に当たらない。
    const absent = '9999';

    test('★ 実在しない番号は「台帳に無い」と判定される', () {
      expect(decisionRefsIn('/// 決定 D$absent に従う'), {'D$absent'});
      expect(ledgerDecisions().contains('D$absent'), isFalse);

      expect(findingRefsIn('/// 新所見 D-$absent を見よ'), {'D-$absent'});
      expect(ledgerFindings().contains('D-$absent'), isFalse);
    });

    test('★★ 対: 実在する番号は「台帳に在る」と判定される ★★', () {
      expect(decisionRefsIn('/// 決定 D110 で決めた'), {'D110'});
      expect(ledgerDecisions().contains('D110'), isTrue);

      expect(findingRefsIn('/// 新所見 D-36 を見よ'), {'D-36'});
      expect(ledgerFindings().contains('D-36'), isTrue);
    });

    test('★ 台帳の抽出が空でない（★空なら下の「全部在る」は何も証明しない / **D-10**）', () {
      expect(ledgerRows(), isNotEmpty);
      expect(ledgerDetails(), isNotEmpty);
      expect(ledgerFindings(), isNotEmpty);
    });

    test('★ 参照の抽出が空でない（★同上。★走査の根を間違えていたら 0 件になる）', () {
      expect(_collect(decisionRefsIn), isNotEmpty);
      expect(_collect(findingRefsIn), isNotEmpty);
    });

    test('★★ 素の `DNN` を見ないことの理由が実在する ★★', () {
      // ★★ 除外の仮定を 1 行で書く（`CLAUDE.md` §3 の作法）★★
      //   「素の DNN はカード番号と区別できない」——その字面が実在すること自体を固定する。
      //   実在しなくなったら、除外の理由が消えたということである。
      final fixture =
          File(p.join('..', 'loveca-core', 'test', 'refresh_test.dart'));
      expect(fixture.existsSync(), isTrue);
      expect(fixture.readAsStringSync(), contains("'D0', 'D1', 'D2'"));
      // ★決定番号としては取り出されない（`決定 ` が前に無い）。
      expect(decisionRefsIn("expect(x, ['D0', 'D1', 'D2']);"), isEmpty);
    });
  });

  test('★★ コードが引く決定番号は 1 つ残らず台帳に在る（**U32**）★★', () {
    final ledger = ledgerDecisions();
    final missing = <String, Set<String>>{};
    _collect(decisionRefsIn).forEach((number, files) {
      if (!ledger.contains(number)) missing[number] = files;
    });
    // ★落ちたら: その番号が (1) 未採番なのか (2) 別の番号へ置き換わったのかを人が分ける。
    //   ★**0 件は 2 つの意味を持つ**（**D-29**）。台帳の側を見ずに結論しないこと。
    expect(missing, isEmpty);
  });

  test('★★ コードが引く所見番号は 1 つ残らず台帳に在る（**U32**）★★', () {
    final ledger = ledgerFindings();
    final missing = <String, Set<String>>{};
    _collect(findingRefsIn).forEach((number, files) {
      if (!ledger.contains(number)) missing[number] = files;
    });
    expect(missing, isEmpty);
  });

  test('★ 台帳 §1 の索引に行が無く、詳細だけで在る番号（★事実の固定）', () {
    // ★★ このテストは索引の欠落を「許して」いる ★★
    //   上の 2 つは 台帳 = 索引行 ∪ 詳細見出し で判定する。
    //   ★**どちらで在るかを潰すと、索引の欠落が見えなくなる。**
    //   → 差を**実測して固定**する。埋めたらここが落ちるので、そのとき消すこと。
    expect(ledgerDetails().difference(ledgerRows()), {'D90', 'D93', 'D94'});
  });
}
