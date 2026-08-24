/// dist の 3 段解決と不在の検出（決定 D60 / `docs/UI設計メモ.md` §4-6(3)(4)）.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:path/path.dart' as p;

/// `version.json` と `manifest.json` を持つ「使える dist」を作る。
Directory _makeDist(Directory root, String name) {
  final dir = Directory(p.join(root.path, name))..createSync(recursive: true);
  File(p.join(dir.path, 'version.json')).writeAsStringSync('{}');
  File(p.join(dir.path, 'manifest.json')).writeAsStringSync('{}');
  return dir;
}

void main() {
  late Directory tmp;
  late String fakeExecutable;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_dist_test');
    // 実行ファイルの隣 = <tmp>/app/loveca_ui.exe → 既定は <tmp>/app/data/dist
    Directory(p.join(tmp.path, 'app')).createSync(recursive: true);
    fakeExecutable = p.join(tmp.path, 'app', 'loveca_ui.exe');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  DesktopDistLocator locator({String? env, String? settings}) =>
      DesktopDistLocator(
        settingsDistDir: settings,
        environment: env == null
            ? const {}
            : {DesktopDistLocator.environmentKey: env},
        executablePath: fakeExecutable,
      );

  group('解決順', () {
    test('段1: 環境変数が最優先', () async {
      final fromEnv = _makeDist(tmp, 'from_env');
      final fromSettings = _makeDist(tmp, 'from_settings');

      final result = await locator(
        env: fromEnv.path,
        settings: fromSettings.path,
      ).locate();

      expect(result.found, isTrue);
      expect(result.directory!.path, fromEnv.path);
    });

    test('段2: 環境変数が無ければ settings.json', () async {
      final fromSettings = _makeDist(tmp, 'from_settings');

      final result = await locator(settings: fromSettings.path).locate();

      expect(result.directory!.path, fromSettings.path);
    });

    test('段3: どちらも無ければ実行ファイルの隣の data/dist', () async {
      final beside = _makeDist(Directory(p.join(tmp.path, 'app')), 'data/dist');

      final result = await locator().locate();

      expect(result.found, isTrue);
      expect(
        p.canonicalize(result.directory!.path),
        p.canonicalize(beside.path),
      );
    });

    test('★上位の段が「使えない」なら次の段へ落ちる', () async {
      // 環境変数は指しているがディレクトリが無い。
      final fromSettings = _makeDist(tmp, 'from_settings');

      final result = await locator(
        env: p.join(tmp.path, 'does_not_exist'),
        settings: fromSettings.path,
      ).locate();

      expect(result.directory!.path, fromSettings.path);
      // ★見た場所は全部残る。
      expect(result.searched, hasLength(2));
      expect(result.searchedPaths.first, contains('does_not_exist'));
      // ★どの段で解決したか（M6 / R6 が出す）。
      expect(result.source, DistSource.settings);
    });
  });

  group('★不在の検出（決定 D60）', () {
    test('どこにも無ければ found が false', () async {
      final result = await locator().locate();

      expect(result.found, isFalse);
      expect(result.directory, isNull);
    });

    test('★見た場所を全部返す。3 段すべてが searched に載る', () async {
      final result = await locator(
        env: p.join(tmp.path, 'no_env'),
        settings: p.join(tmp.path, 'no_settings'),
      ).locate();

      expect(result.found, isFalse);
      expect(result.searched, hasLength(3));
      expect(result.searchedPaths[0], contains('no_env'));
      expect(result.searchedPaths[1], contains('no_settings'));
      expect(result.searchedPaths[2], contains('data'));
      // ★段の名前も順番どおり残る。件数からは復元できない（空指定は積まれない）。
      expect(
        [for (final c in result.searched) c.source],
        [DistSource.environment, DistSource.settings, DistSource.bundled],
      );
      expect(result.source, isNull, reason: '見つからなければ段も決まらない');
    });

    test('★ディレクトリがあっても version.json / manifest.json が無ければ使わない',
        () async {
      // 空のディレクトリ。これを「見つかった」と扱うと
      // MasterImporter を呼んでしまい、原因が「読めない」に化ける。
      final empty = Directory(p.join(tmp.path, 'empty'))
        ..createSync(recursive: true);

      final result = await locator(env: empty.path).locate();

      expect(result.found, isFalse);
      expect(result.searchedPaths.first, empty.path);
    });

    test('★manifest.json だけあっても使わない', () async {
      final partial = Directory(p.join(tmp.path, 'partial'))
        ..createSync(recursive: true);
      File(p.join(partial.path, 'manifest.json')).writeAsStringSync('{}');

      final result = await locator(env: partial.path).locate();

      expect(result.found, isFalse);
    });
  });

  test('空文字や空白だけの指定は段として数えない', () async {
    final beside = _makeDist(Directory(p.join(tmp.path, 'app')), 'data/dist');

    final result = await locator(env: '   ', settings: '').locate();

    expect(
      p.canonicalize(result.directory!.path),
      p.canonicalize(beside.path),
    );
    // 空指定は候補に入らないので、見たのは既定の 1 箇所だけ。
    expect(result.searched, hasLength(1));
    // ★★ 件数から段は復元できない ★★
    // 1 件しか見ていないが、それは段 1 ではなく段 3 である。
    // R6 が「どの段が効いているか」を出すには、出所そのものが要る（M6）。
    expect(result.source, DistSource.bundled);
  });

  group('★どの段で解決したか（M6 / R6）', () {
    test('段1 なら environment', () async {
      final fromEnv = _makeDist(tmp, 'from_env');
      final result = await locator(env: fromEnv.path).locate();
      expect(result.source, DistSource.environment);
      expect(result.source!.label, contains('LOVECA_DIST_DIR'));
    });

    test('段2 なら settings', () async {
      final fromSettings = _makeDist(tmp, 'from_settings');
      final result = await locator(settings: fromSettings.path).locate();
      expect(result.source, DistSource.settings);
      expect(result.source!.label, contains('settings.json'));
    });

    test('段3 なら bundled', () async {
      _makeDist(Directory(p.join(tmp.path, 'app')), 'data/dist');
      final result = await locator().locate();
      expect(result.source, DistSource.bundled);
      expect(result.source!.label, contains('実行ファイル'));
    });
  });
}
