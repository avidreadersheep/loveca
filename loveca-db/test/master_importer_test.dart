/// 差分取り込みと失敗の隔離の検証.
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

final _t0 = DateTime.utc(2026, 8, 23, 12);

/// ミニ配信物を土台に、任意のファイルだけ差し替えた配信物を組み立てる。
class _Dist {
  _Dist({int dataVersion = 2}) : _dataVersion = dataVersion {
    for (final f in fixtureManifest.files) {
      _files[f.path] = readFixture(f.path);
      _hashes[f.path] = f.hash;
    }
  }

  final int _dataVersion;
  final Map<String, String> _files = {};
  final Map<String, String> _hashes = {};

  /// ファイルの中身とハッシュを差し替える（配信側が更新した状況）。
  void replace(String path, String content, String hash) {
    _files[path] = content;
    _hashes[path] = hash;
  }

  void remove(String path) {
    _files.remove(path);
    _hashes.remove(path);
  }

  void add(String path, String content, String hash) =>
      replace(path, content, hash);

  _Dist bump(int dataVersion) {
    final next = _Dist(dataVersion: dataVersion);
    next._files
      ..clear()
      ..addAll(_files);
    next._hashes
      ..clear()
      ..addAll(_hashes);
    return next;
  }

  VersionInfo get version => VersionInfo(
        dataVersion: _dataVersion,
        minAppVersion: '1.0.0',
        manifestPath: '/data/manifest.json',
        manifestHash: 'sha256:manifest-$_dataVersion',
      );

  Manifest get manifest => Manifest(
        dataVersion: _dataVersion,
        files: [
          for (final path in _files.keys)
            ManifestFile(
              path: path,
              hash: _hashes[path]!,
              bytes: _files[path]!.length,
            ),
        ],
      );

  MapMasterFileSource get source => MapMasterFileSource(Map.of(_files));
}

/// 未知のハートの色を混ぜて `HeartColor.fromKey` を throw させる（D-1 の再現）。
String _withUnknownHeartColor(String cardsJson) =>
    cardsJson.replaceFirst('"BLUE"', '"CYAN"');

void main() {
  late LovecaDatabase db;
  late MasterImporter importer;
  late MasterStateDao state;
  late CardDao cards;

  setUp(() {
    db = LovecaDatabase(openInMemoryExecutor());
    importer = MasterImporter(db);
    state = MasterStateDao(db);
    cards = CardDao(db);
  });
  tearDown(() => db.close());

  Future<MasterImportResult> run(_Dist dist, {MapMasterFileSource? source}) =>
      importer.import(
        remoteVersion: dist.version,
        remoteManifest: dist.manifest,
        source: source ?? dist.source,
        appVersion: '1.0.0',
        now: _t0,
      );

  group('初回取り込み', () {
    test('全ファイルが取り込まれ data_version が上がる', () async {
      final dist = _Dist();
      final source = dist.source;
      final result = await run(dist, source: source);

      expect(result.decision, UpdateDecision.update);
      expect(result.hasFailures, isFalse);
      expect(result.dataVersionAdvanced, isTrue);
      expect(result.dataVersion, 2);
      expect(await state.localDataVersion(), 2);
      expect(source.readPaths, hasLength(dist.manifest.files.length));

      expect(await cards.cardCount(), 25);
      expect((await cards.printingsById()).length, 50);
      expect(await CardSearchDao(db).indexedCount(), 25);
      expect((await DeckDao(db).ruleConfig()).memberCount, 48);
    });

    test('アプリが古すぎると何もしない', () async {
      final result = await importer.import(
        remoteVersion: const VersionInfo(
          dataVersion: 2,
          minAppVersion: '9.9.9',
          manifestPath: '/data/manifest.json',
          manifestHash: '',
        ),
        remoteManifest: _Dist().manifest,
        source: _Dist().source,
        appVersion: '1.0.0',
        now: _t0,
      );
      expect(result.decision, UpdateDecision.appTooOld);
      expect(await cards.cardCount(), 0);
    });
  });

  group('★差分更新', () {
    test('同じ dataVersion なら 1 件も読まない', () async {
      await run(_Dist());

      final again = _Dist();
      final source = again.source;
      final result = await run(again, source: source);

      expect(result.decision, UpdateDecision.upToDate);
      expect(source.readPaths, isEmpty);
    });

    test('ハッシュが一致するファイルは再投入されない', () async {
      await run(_Dist());

      // dataVersion を上げ、BP01 だけ中身とハッシュを変える。
      final next = _Dist().bump(3);
      next.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        'sha256:bp01-v2',
      );

      final source = next.source;
      final result = await run(next, source: source);

      // ★読まれたのは変えた 1 件だけ★
      expect(source.readPaths, ['cards/BP01.json']);
      expect(result.importedPaths, ['cards/BP01.json']);
      expect(result.skippedPaths, hasLength(next.manifest.files.length - 1));
      expect(result.dataVersionAdvanced, isTrue);
      expect(await state.localDataVersion(), 3);
    });

    test('配信側から消えた商品の刷りが取り除かれる', () async {
      await run(_Dist());
      expect(await cards.printingsOfCard(multiPrintingMember), hasLength(2));

      final next = _Dist().bump(3);
      next.remove('cards/PR.json');
      final result = await run(next);

      expect(result.deletedPaths, contains('cards/PR.json'));
      // PR の刷りだけ消え、BP01 の刷りとカード本体は残る。
      final printings = await cards.printingsOfCard(multiPrintingMember);
      expect(printings, hasLength(1));
      expect(printings.single.expansion, 'BP01');
    });

    test('知らない path はハッシュを記録しつつ結果に載せる', () async {
      final dist = _Dist();
      dist.add('meta/whatever.json', '{}', 'sha256:whatever');
      final result = await run(dist);

      expect(result.unhandledPaths, ['meta/whatever.json']);
      // ★毎回取りに行く状態にはしない（ハッシュは記録する）。
      expect(result.dataVersionAdvanced, isTrue);
    });
  });

  group('★取り込み失敗の隔離 (決定 D39 / D-1)', () {
    _Dist brokenDist({int dataVersion = 2}) {
      final dist = _Dist(dataVersion: dataVersion);
      dist.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-broken',
      );
      return dist;
    }

    test('壊れた商品ファイルがあっても他は取り込まれる', () async {
      final result = await run(brokenDist());

      expect(result.failedPaths, ['cards/BP01.json']);
      expect(result.importedPaths, isNot(contains('cards/BP01.json')));
      // ★アプリが起動不能にならない。他の商品は入っている。
      expect(await cards.cardCount(), greaterThan(0));
      expect(await cards.cardByNumber(multiPrintingMember), isNotNull);
    });

    test('未知キーは unknownKey として記録される', () async {
      await run(brokenDist());

      final issues = await state.outstandingImportIssues();
      expect(issues, hasLength(1));
      expect(issues.single.path, 'cards/BP01.json');
      expect(issues.single.kind, ImportIssueKind.unknownKey);
      expect(issues.single.message, contains('CYAN'));
    });

    test('読み込み失敗は readFailure として記録される', () async {
      final dist = _Dist();
      final source = MapMasterFileSource(<String, String>{});
      final result = await run(dist, source: source);

      expect(result.failedPaths, hasLength(dist.manifest.files.length));
      final issues = await state.outstandingImportIssues();
      expect(issues.map((i) => i.kind).toSet(), {ImportIssueKind.readFailure});
    });

    // ★1 件でも失敗が残っているうちは旧 data_version を保持する★
    test('失敗が残ると data_version が上がらない', () async {
      final result = await run(brokenDist());
      expect(result.dataVersionAdvanced, isFalse);
      expect(result.dataVersion, 0);
      expect(await state.localDataVersion(), 0);
    });

    // ★★ data_version 据え置きの副作用の検証 ★★
    // planUpdate は dataVersion を「入口の門番」にしか使っておらず、
    // filesToDownload はハッシュ差分だけで決まる（master_data.dart:243-248）。
    // したがって旧 data_version を据え置いても全ファイル再取得は起きない。
    test('据え置いても再取得されるのは失敗したファイルだけ', () async {
      await run(brokenDist());

      // 同じ配信物にもう一度当てる。dataVersion は据え置かれたままなので、
      // 0 < 2 で門は通り、ハッシュ差分だけが取得対象になる。
      final second = brokenDist();
      final source = second.source;
      final result = await run(second, source: source);

      expect(source.readPaths, ['cards/BP01.json']);
      expect(result.failedPaths, ['cards/BP01.json']);
      expect(result.skippedPaths,
          hasLength(second.manifest.files.length - 1));
      expect(await state.localDataVersion(), 0);
    });

    test('配信側が直したら成功して data_version が上がる', () async {
      await run(brokenDist());
      expect(await state.outstandingImportIssueCount(), 1);

      final fixed = _Dist();
      fixed.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        'sha256:bp01-fixed',
      );
      final source = fixed.source;
      final result = await run(fixed, source: source);

      expect(source.readPaths, ['cards/BP01.json']);
      expect(result.hasFailures, isFalse);
      expect(result.dataVersionAdvanced, isTrue);
      expect(await state.localDataVersion(), 2);
      expect(await cards.cardCount(), 25);
    });

    test('同じ失敗を繰り返しても行は増えず回数だけ増える', () async {
      await run(brokenDist());
      await run(brokenDist());
      await run(brokenDist());

      final issues = await state.outstandingImportIssues();
      expect(issues, hasLength(1));
      expect(issues.single.occurrenceCount, 3);
    });
  });

  group('★UI が失敗を検知できる (決定 D39)', () {
    test('件数が 0 → 1 → 0 と動く', () async {
      expect(await state.outstandingImportIssueCount(), 0);

      final broken = _Dist();
      broken.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-broken',
      );
      await run(broken);
      expect(await state.outstandingImportIssueCount(), 1);

      // ★取り込みに成功したら自動で未解消から外れる（手で消す運用にしない）。
      // ★★ ここは「同じハッシュ文字列で直した版」である（一時的な読み取り失敗の形）★★
      //   **内容を直せばハッシュも変わる**という実際の配信の形は、下の
      //   「別のハッシュで直しても 0 件に戻る」が見る（**D-13**）。
      final fixed = _Dist();
      fixed.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        'sha256:bp01-broken',
      );
      await run(fixed);
      expect(await state.outstandingImportIssueCount(), 0);
    });

    test('★★ 別のハッシュで直しても 0 件に戻る（D-13）★★', () async {
      // ★★ この穴が D-13 である ★★
      //   上のテストは**同じハッシュ文字列で直した版を publish している**ので、
      //   `(path, hash)` の照合が成立していた。
      //   実際の配信は**内容を直せばハッシュも変わる**ので、
      //   古い失敗の行と永久に照合できず「未解消」のまま残っていた。
      expect(await state.outstandingImportIssueCount(), 0);

      final broken = _Dist();
      broken.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-v1-broken',
      );
      await run(broken);
      expect(await state.outstandingImportIssueCount(), 1);

      final fixed = _Dist();
      fixed.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        // ★★ ここが違う。直した内容なのでハッシュも変わる ★★
        'sha256:bp01-v2-fixed',
      );
      await run(fixed);

      expect(await state.outstandingImportIssueCount(), 0);
      // ★行そのものが消えていること（「未解消でない」ではなく「無い」）。
      expect(await state.outstandingImportIssues(), isEmpty);
    });

    test('★対: 直っていなければ 0 件に戻らない（判定を path だけにすると壊れる）',
        () async {
      // ★★ 却下案 (c)「判定を path だけの NOT EXISTS にする」を排除する ★★
      //   それだと v1 で成功 → v2 で失敗 のときに「解消済み」に見え、
      //   **本物の失敗を隠す。**
      final ok = _Dist();
      ok.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        'sha256:bp01-v1-ok',
      );
      await run(ok);
      expect(await state.outstandingImportIssueCount(), 0);

      // ★★ dataVersion を上げること ★★
      //   1 回目が成功したので `data_version` が進んでいる（決定 D39）。
      //   据え置くと `upToDate` になり **1 件も読まれない**ので、
      //   「失敗しなかった」ではなく「試してすらいない」状態を測ることになる。
      final broken = _Dist().bump(3);
      broken.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-v2-broken',
      );
      await run(broken);

      expect(await state.outstandingImportIssueCount(), 1,
          reason: '★成功のあとに失敗したら、それは未解消の失敗である');
    });

    test('★ 別のファイルの失敗は巻き込まない（消すのは同じ path だけ）', () async {
      final broken = _Dist();
      broken.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-broken-x',
      );
      // ★★ BP03 ではなく BP05 を使う ★★
      //   `_withUnknownHeartColor` は `"BLUE"` を置き換える。
      //   **BP03 の fixture に `"BLUE"` は 1 つも無い**ので空振りし、
      //   「壊したつもりで壊れていない」状態になる（実際に一度そうなった）。
      broken.replace(
        'cards/BP05.json',
        _withUnknownHeartColor(readFixture('cards/BP05.json')),
        'sha256:bp05-broken-x',
      );
      await run(broken);
      expect(await state.outstandingImportIssueCount(), 2,
          reason: '★2 ファイルとも本当に壊れていること');

      // ★BP01 だけを直す。
      final half = _Dist();
      half.replace(
        'cards/BP01.json',
        readFixture('cards/BP01.json'),
        'sha256:bp01-fixed-x',
      );
      half.replace(
        'cards/BP05.json',
        _withUnknownHeartColor(readFixture('cards/BP05.json')),
        'sha256:bp05-broken-x',
      );
      await run(half);

      final issues = await state.outstandingImportIssues();
      expect(issues, hasLength(1));
      expect(issues.single.path, 'cards/BP05.json');
    });

    test('watch が件数の変化を流す', () async {
      final seen = <int>[];
      final sub = state.watchOutstandingImportIssueCount().listen(seen.add);
      await pumpEventQueue();

      final broken = _Dist();
      broken.replace(
        'cards/BP01.json',
        _withUnknownHeartColor(readFixture('cards/BP01.json')),
        'sha256:bp01-broken',
      );
      await run(broken);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });
}
