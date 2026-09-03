/// ★★ 「どのパッケージの試験を走らせる必要が在るか」の判定を★機械で固定する ★★
/// （`tool/affected_tests.dart` / ★運転指示【0】(1) / **D-15 (j)** / **D-2**）
///
/// ★★ なぜ置くか ★★
/// ★2026-09-03、★`loveca_core` の `DeckValidator.canAdd` の意味を変えた回に
/// ★★`loveca-db` を走らせないまま「280 のまま」と書いた★★（**D-15 (j)**）。
/// ★**作法を「5 パッケージ全部を走らせてから数える」にしたが、★★作法は忘れられる★★**（**D-2**）。
/// → ★**判定を道具にした。★★この試験はその道具を見張る★★。**
///
/// ★★ この試験が覆わないもの（★言い切る）★★
/// ★**1) 走らせたかどうか** —— ★★観測できない★★（★道具の doc と同じ）。
/// ★**2) 落ちる件数** —— ★★走らせないと分からない★★（**D-28**）。
/// ★**3) `pubspec.yaml` に現れない結びつき** —— ★**D126-3** の型（★HTTP 越しの鍵の字面）。
///   ★★**その受けは★走査テストの側に在る**★★（★`deck_sync_client_test.dart` など）。
///
/// ★★ 対は「本番の関数」を通す（**D-27** (甲)）★★
/// ★下の群は★★合成の入力を [affectedPackages] に流す★★。
/// ★**リポジトリを実際に見る群**（[discoverPackages] / [docWatcherDirs]）も別に置く ——
/// ★★**合成だけだと「本番の根が変わったこと」を 1 つも見ない**★★（**D-31** の受け）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/affected_tests.dart';

/// ★リポジトリのルート（★試験の作業ディレクトリは `loveca-ui`）。
const _repoRoot = '..';

/// ★合成のパッケージ。★推移を見るためだけに使う（★リポジトリを 1 バイトも読まない）。
List<PackageSpec> _synthetic() => [
      (dir: 'aa', name: 'aa', command: 'dart test', deps: <String>{'bb'}),
      (dir: 'bb', name: 'bb', command: 'dart test', deps: <String>{'cc'}),
      (dir: 'cc', name: 'cc', command: 'dart test', deps: <String>{}),
      (dir: 'zz', name: 'zz', command: 'dart test', deps: <String>{}),
    ];

Set<String> _affected(List<String> changed,
        {List<PackageSpec>? packages, Set<String>? watchers}) =>
    affectedPackages(
      packages: packages ?? discoverPackages(_repoRoot),
      docWatchers: watchers ?? docWatcherDirs(_repoRoot, discoverPackages(_repoRoot)),
      changedPaths: changed,
    );

void main() {
  group('★★ 分類器が当たること（★これが無いと下の答えは何も証明しない / D-10）★★', () {
    test('★ pubspec の name を読む', () {
      expect(pubspecName('name: loveca_core\nversion: 1.0.0\n'), 'loveca_core');
      expect(pubspecName('description: x\n'), isNull);
    });

    test('★★ flutter の判定は `sdk: flutter` の行だけを見る（D-37 の裏）★★', () {
      // ★アセットの節の `flutter:` は★依存ではない。★拾ってはならない。
      expect(usesFlutter('flutter:\n  assets:\n    - a/\n'), isFalse);
      expect(usesFlutter('dependencies:\n  flutter:\n    sdk: flutter\n'), isTrue);
    });

    test('★ path 依存はディレクトリ名で返る（★パッケージ名とは字面が違う）', () {
      const yaml = 'dependencies:\n'
          '  loveca_core:\n'
          '    path: ../loveca-core\n'
          '  loveca_db:\n'
          '    path: ../loveca-db\n';
      expect(pathDependencyDirs(yaml), {'loveca-core', 'loveca-db'});
      expect(pathDependencyDirs('dependencies:\n  path: ^1.9.0\n'), isEmpty);
    });

    test('★★ 持ち主は先頭一致で決める（★名前一致では見ない）★★', () {
      const dirs = {'loveca-core', 'loveca-ui'};
      expect(ownerOf('loveca-core/lib/x.dart', dirs), 'loveca-core');
      expect(ownerOf('loveca-core', dirs), 'loveca-core');
      // ★★ 名前を含むだけのパスは★持ち主ではない ★★
      expect(ownerOf('docs/loveca-core の話.md', dirs), isNull);
      expect(ownerOf('loveca-core-old/lib/x.dart', dirs), isNull);
    });
  });

  group('★★ D-15 (j) の 1 件 —— ★実際に落とした入力を固定する ★★', () {
    test('★★ loveca_core の rules を触ったら loveca-db も走らせる（★要石）★★', () {
      final got = _affected(['loveca-core/lib/src/rules/deck_validator.dart']);
      // ★★ この 1 行が、★2026-09-03 に書き落とされたものである ★★
      expect(got, contains('loveca-db'));
      expect(got, contains('loveca-ui'));
      expect(got, contains('loveca-core'));
    });

    test('★ loveca-db を触ったら loveca-ui も走らせる（★1 段の依存）', () {
      final got = _affected(['loveca-db/lib/src/dao/deck_dao.dart']);
      expect(got, containsAll(<String>['loveca-db', 'loveca-ui']));
      expect(got, isNot(contains('loveca-core')));
    });

    test('★★ 対: ★依存していないものは巻き込まない ★★', () {
      // ★線 α は空である（**D115-6** / **D126-3**）—— ★サーバーは core を引かない。
      expect(_affected(['loveca-server/lib/src/auth.dart']), {'loveca-server'});
      expect(_affected(['loveca-data/loveca_data/normalize.py']), {'loveca-data'});
      expect(_affected(['loveca-ui/lib/src/app.dart']), {'loveca-ui'});
    });

    test('★★ 推移は 1 段で止まらない（★合成の入力）★★', () {
      final pkgs = _synthetic();
      expect(
        _affected(['cc/lib/x.dart'], packages: pkgs, watchers: <String>{}),
        {'cc', 'bb', 'aa'},
      );
      expect(
        _affected(['zz/lib/x.dart'], packages: pkgs, watchers: <String>{}),
        {'zz'},
      );
    });
  });

  group('★★ どのパッケージにも属さないファイル（★規則 3）★★', () {
    test('★ docs / リポジトリ直下の文書は★doc を読む試験へ回す', () {
      final watchers = docWatcherDirs(_repoRoot, discoverPackages(_repoRoot));
      expect(_affected(['docs/同期設計メモ.md']), watchers);
      expect(_affected(['CLAUDE.md']), watchers);
    });

    test('★★ 宛先はリポジトリから導く。★決め打ちしない（D-31 の受け）★★', () {
      final packages = discoverPackages(_repoRoot);
      // ★**独立に数える** —— ★`test/docs/` を持つディレクトリを★試験の側でも走査する。
      final derived = <String>{
        for (final entity in Directory(_repoRoot).listSync())
          if (entity is Directory &&
              Directory('${entity.path}/test/docs').existsSync())
            entity.path.split(Platform.pathSeparator).last,
      };
      expect(docWatcherDirs(_repoRoot, packages), derived);
      // ★★ 陽性対照: ★空ではない（★空なら上の一致は何も言っていない / D-10）★★
      expect(derived, isNotEmpty);
    });
  });

  group('★★ 根はリポジトリである。★一覧を決め打ちしない（D-31）★★', () {
    test('★ pubspec.yaml か tests/run_all.py を持つ段を★1 つ残らず見つける', () {
      final found = {for (final p in discoverPackages(_repoRoot)) p.dir};
      // ★**独立に数える**（★道具の走査を 1 行も呼ばない）。
      final derived = <String>{
        for (final entity in Directory(_repoRoot).listSync())
          if (entity is Directory &&
              !entity.path.split(Platform.pathSeparator).last.startsWith('.') &&
              (File('${entity.path}/pubspec.yaml').existsSync() ||
                  File('${entity.path}/tests/run_all.py').existsSync()))
            entity.path.split(Platform.pathSeparator).last,
      };
      expect(found, derived);
      // ★★ 陽性対照: ★このリポジトリには★★Dart も Python も在る★★ ★★
      expect(found.length, greaterThanOrEqualTo(2));
    });

    test('★★ 走らせ方も pubspec から導く（★字面を書き写さない）★★', () {
      final byDir = {for (final p in discoverPackages(_repoRoot)) p.dir: p};
      expect(byDir['loveca-ui']?.command, 'flutter test');
      expect(byDir['loveca-core']?.command, 'dart test');
      expect(byDir['loveca-data']?.command, 'python tests/run_all.py');
    });

    test('★★ 依存の向きも pubspec から読む（★書き写さない）★★', () {
      final dependents = dependentsOf(discoverPackages(_repoRoot));
      expect(dependents['loveca-core'], {'loveca-db', 'loveca-ui'});
      expect(dependents['loveca-server'], isEmpty);
    });
  });

  group('★★ 文書を読む試験を★リポジトリから導く（★2026-09-04 / ★規則 3 の理由）★★', () {
    test('★★ 分類器が当たること（★これが無いと下の答えは何も証明しない / D-10）★★', () {
      // ★**(甲) ＋ (乙) の積である。★片方だけでは足りない。**
      expect(
        readsRepositoryDocs("final f = File(p.join('..', 'docs', 'a.md'));"),
        isTrue,
      );
      // ★**(甲) だけ** —— ★自分のパッケージの中の fixture（★`tls_fixture_test.dart` が実在する）。
      expect(
        readsRepositoryDocs("final f = File('test/fixtures/README.md');"),
        isFalse,
      );
      // ★**(乙) だけ** —— ★隣のパッケージのソースを走査するだけ。
      expect(
        readsRepositoryDocs("final d = Directory('../loveca-core/lib');"),
        isFalse,
      );
    });

    test('★★ コメントの中の字面は数えない（D-30）★★', () {
      // ★★**説明した doc は★説明対象と同じ字面を必ず含む**★★。
      // ★★逆斜線を字面で書かない★★（**D-38** —— ★この回で 5 度目を踏んだ）。
      final onlyComment = <String>[
        "/// ★`docs/決定事項一覧.md` を読む試験の話。",
        "// final f = File(p.join('..', 'docs', 'x.md'));",
        "void main() {}",
      ].join(String.fromCharCode(10));
      expect(readsRepositoryDocs(onlyComment), isFalse);
      // ★★ 陽性対照: ★コメントを外さなければ当たる（★上の 0 件が「見えていない」でないこと）★★
      expect(
        RegExp("[.]md[']").hasMatch(onlyComment),
        isTrue,
      );
    });

    test('★ ブロックコメントも外れる。★文字列は残る', () {
      expect(stripDartComments('a /* x.md */ b'), 'a  b');
      expect(stripDartComments("var a = 'x // y'; // z"), "var a = 'x // y'; ");
    });

    test('★★ 導いた一覧は空ではない（D-10）★★', () {
      final readers = docReadingTests(_repoRoot, discoverPackages(_repoRoot));
      expect(readers, isNotEmpty);
      // ★**実物が 1 件在ることを名指しで固定する**（★これが無いと「空でない」だけになる）。
      expect(readers, contains('loveca-ui/test/docs/measurement_date_test.dart'));
    });

    test('★★ `test/docs/` に閉じていない（★2026-09-04 の測定そのもの）★★', () {
      final readers = docReadingTests(_repoRoot, discoverPackages(_repoRoot));
      final outside =
          readers.where((r) => !r.contains('/test/docs/')).toList();
      // ★★**これが 0 件になったら「`flutter test test/docs` だけでよい」が真になる。**★★
      // ★**今日は偽である** —— ★`test/board/abolished_term_test.dart` が
      // ★`docs/決定事項一覧.md` を読む（★D88-1 の語を取り出す）。
      expect(outside, isNotEmpty,
          reason: '★狭めてよくなったら★この試験を消すのではなく★道具の命令を狭めること');
    });

    test('★★ 出す行に対を置く（★D-27 の (乙) の受け）★★', () {
      // ★★**出力だけを消しても★対が 1 件も落ちなかった**★★（2026-09-04 実測 / ★仕込み (G)）。
      // → ★**画面へ書く所と★何を書くかを分けた。★ここは後者を見る。**
      final lines = ruleThreeLines(
        ownerlessCount: 2,
        readers: <String>['a/test/x_test.dart', 'a/test/docs/y_test.dart'],
      );
      // ★**読む試験の名前が★1 つ残らず出ること**（★これが出ないと理由にならない）。
      expect(lines, contains('    a/test/x_test.dart'));
      expect(lines, contains('    a/test/docs/y_test.dart'));
      // ★**件数も出ること**（★名前だけだと「何件在るか」が読めない）。
      expect(lines.any((l) => l.contains('2 件在る')), isTrue);
      expect(lines.any((l) => l.contains('2 件:')), isTrue);
      // ★★**狭めてはならないことも★字面で出す**★★（★これが消えると★次の人が狭める）。
      // ★★**`any` で見ない**★★ —— ★一覧の側にも `test/docs/` を含む行が在るので、
      // ★★`any` だと★注意書きを消しても★一覧の行が当たってしまう★★（2026-09-04 実測 / ★仕込み (J) が 0 件）。
      expect(lines.last, contains('test/docs/'));
      expect(lines.last, contains('足りない'));
    });

    test('★ 一覧が空でも★行そのものは出る（★対）', () {
      final lines = ruleThreeLines(ownerlessCount: 1, readers: const <String>[]);
      expect(lines.any((l) => l.contains('0 件:')), isTrue);
    });

    test('★★ 規則 3 の答えは★読む試験を 1 つ残らず覆う★★', () {
      final packages = discoverPackages(_repoRoot);
      final readers = docReadingTests(_repoRoot, packages);
      final owners = {
        for (final r in readers) r.split('/').first,
      };
      // ★**doc だけの変更に対する答えが、★読む試験の持ち主を★全部含むこと。**
      expect(_affected(['docs/同期設計メモ.md']).containsAll(owners), isTrue);
      expect(owners, isNotEmpty);
    });
  });
}
