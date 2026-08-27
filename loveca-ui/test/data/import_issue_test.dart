/// ★★ M6 の本命テスト（1）— 取り込み失敗を「実際に起こして」固定する ★★
///
/// D-10 の教訓:
/// > 検知手段を書いたら必ず「見つかるはずのもの」を仕込んで動かす。
/// > 0 件は「無い」と「見えていない」の区別がつかない。
///
/// 決定 D39 は「商品ファイル単位で隔離し `import_issues` に記録する」と定めたが、
/// M5 まで**読み出す側が 1 つも無かった**。R6（M6）がその出口である。
/// フェイクに件数を返させても、それは**画面の検査であって出口の検査ではない。**
/// ここは実 DB に対して `MasterImporter` を本当に走らせる。
///
/// ★★ 「起きない入力で出ないこと」も対で固定する ★★
/// 出る側だけ見ると、**常に 1 件返す**実装でも通ってしまう。
///
/// ★役割を混ぜない。画面がこれをどう出すかは `test/ui/settings_page_test.dart`。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:loveca_ui/src/data/repository_exception.dart';
import 'package:path/path.dart' as p;

final _t0 = DateTime.utc(2026, 8, 24, 12);

/// 取り込める最小の商品ファイル。
String _cardsJson({String heartColor = 'BLUE'}) =>
    '{"expansion": "bp1", '
    '"cards": [{"cardNumber": "X-1", "name": "テストメンバー", '
    '"cardType": "メンバー", "hearts": {"$heartColor": 1}}], '
    '"printings": [{"printingId": "X-1-N", "cardNumber": "X-1", '
    '"expansion": "bp1", "rarity": "N", "isParallel": false}]}';

void main() {
  late Directory tmp;
  late Directory dist;
  late LovecaDatabase db;
  late MasterRepository master;

  /// dist を組み立てる。
  ///
  /// ★[hash] は差分計画の鍵であって内容の検算には使われない
  /// （`master_importer.dart` は content を読むだけでハッシュを検算しない）ので、
  /// 「別の版になった」ことを表すために自由に変えてよい。
  void writeDist({
    required String cards,
    required String hash,
    required int dataVersion,
  }) {
    File(p.join(dist.path, 'version.json')).writeAsStringSync(
      '{"dataVersion": $dataVersion, "minAppVersion": "1.0.0"}',
    );
    File(p.join(dist.path, 'manifest.json')).writeAsStringSync(
      '{"dataVersion": $dataVersion, "files": '
      '[{"path": "cards/BP01.json", "hash": "$hash"}]}',
    );
    File(p.join(dist.path, 'cards', 'BP01.json')).writeAsStringSync(cards);
  }

  Future<MasterImportResult> runImport() async {
    final version = VersionInfo.parse(
      File(p.join(dist.path, 'version.json')).readAsStringSync(),
    );
    final manifest = Manifest.parse(
      File(p.join(dist.path, 'manifest.json')).readAsStringSync(),
    );
    return MasterImporter(db).import(
      remoteVersion: version,
      remoteManifest: manifest,
      source: LocalDirectoryMasterFileSource(dist),
      appVersion: '1.0.0',
      now: _t0,
    );
  }

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_import_issue_test');
    dist = Directory(p.join(tmp.path, 'dist'));
    Directory(p.join(dist.path, 'cards')).createSync(recursive: true);
    // ★本番と同じ経路で開く。テストだけ別経路にすると、
    //   決定 D45 が本経路で成立することがテストからは検証されない状態になる。
    db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
    master = MasterRepository(db);
  });

  tearDown(() async {
    try {
      await db.close();
    } on Object catch (_) {
      // 後始末であって検査ではない。
    }
    // ★Windows は開いたままだと消せない。
    tmp.deleteSync(recursive: true);
  });

  group('前提（仕込みが効いていること）', () {
    test('壊れていない dist なら取り込みは成功する', () async {
      writeDist(cards: _cardsJson(), hash: 'sha256:v1', dataVersion: 1);

      final result = await runImport();

      expect(result.decision, UpdateDecision.update);
      expect(result.failedPaths, isEmpty, reason: '仕込みの土台が壊れていないこと');
      expect(result.importedPaths, ['cards/BP01.json']);
    });
  });

  group('★ 取り込み失敗が実際に記録される（決定 D39）', () {
    test('★未知のハートの色で本当に失敗し、未解消として出る', () async {
      // ★★ 実際に壊す ★★
      //   HeartColor.fromKey が未知のキーで ArgumentError を投げる（D-1）。
      //   配信側が新しい色を足した状況そのもの。
      writeDist(
        cards: _cardsJson(heartColor: 'CYAN'),
        hash: 'sha256:broken',
        dataVersion: 1,
      );

      final result = await runImport();
      expect(result.failedPaths, ['cards/BP01.json'],
          reason: '仕込みが効いていること自体をまず確かめる');

      expect(await master.outstandingImportIssueCount(), 1);

      final issues = await master.outstandingImportIssues();
      expect(issues, hasLength(1));
      expect(issues.single.path, 'cards/BP01.json');
      expect(issues.single.kind, ImportIssueKind.unknownKey);
      expect(issues.single.message, contains('CYAN'),
          reason: '★実際の値を出さないと利用者は何が起きたか分からない');
      expect(issues.single.occurrenceCount, 1);
      // ★drift の DateTime 列は UTC で書いて**ローカルで読み戻る**
      //   （`master_state_dao.dart:91` が `at.toUtc()` で書いている）。
      //   ここを素の等値で比べると、タイムゾーンが UTC の環境でだけ通る。
      expect(issues.single.lastSeenAt.toUtc(), _t0);
      expect(issues.single.firstSeenAt.toUtc(), _t0);
      // ★一度も取り込めていないので現在ハッシュは無い。
      expect(issues.single.currentHash, isNull);
    });

    test('★壊れていなければ 1 件も出ない（出ない側）', () async {
      writeDist(cards: _cardsJson(), hash: 'sha256:v1', dataVersion: 1);
      await runImport();

      expect(await master.outstandingImportIssueCount(), 0,
          reason: '出る側だけ見ると「常に 1 件返す」実装でも通ってしまう');
      expect(await master.outstandingImportIssues(), isEmpty);
    });

    test('★同じ壊れ方を繰り返すと回数が増える（行は増えない）', () async {
      writeDist(
        cards: _cardsJson(heartColor: 'CYAN'),
        hash: 'sha256:broken',
        dataVersion: 1,
      );
      await runImport();
      await runImport();
      await runImport();

      final issues = await master.outstandingImportIssues();
      expect(issues, hasLength(1), reason: '主キーが {path, hash} なので 1 行のまま');
      expect(issues.single.occurrenceCount, 3);
    });

    test('★読めないファイルは readFailure になる', () async {
      writeDist(cards: _cardsJson(), hash: 'sha256:v1', dataVersion: 1);
      File(p.join(dist.path, 'cards', 'BP01.json')).deleteSync();

      await runImport();

      final issues = await master.outstandingImportIssues();
      expect(issues.single.kind, ImportIssueKind.readFailure);
    });

    test('★解釈できないファイルは parseFailure になる', () async {
      writeDist(cards: '{ こわれた', hash: 'sha256:v1', dataVersion: 1);

      await runImport();

      final issues = await master.outstandingImportIssues();
      expect(issues.single.kind, ImportIssueKind.parseFailure);
    });
  });

  group('★ 未解消から外れる条件（決定 D39 / ★所見 D-13）', () {
    test('同じハッシュのまま取り込めるようになれば消える（一時的な読み取り失敗）',
        () async {
      // ★readFailure は中身が変わらなくても直りうる唯一の経路。
      writeDist(cards: _cardsJson(), hash: 'sha256:v1', dataVersion: 1);
      File(p.join(dist.path, 'cards', 'BP01.json')).deleteSync();
      await runImport();
      expect(await master.outstandingImportIssueCount(), 1);

      // 同じハッシュのまま読めるようになる。
      File(p.join(dist.path, 'cards', 'BP01.json'))
          .writeAsStringSync(_cardsJson());
      await runImport();

      expect(await master.outstandingImportIssueCount(), 0,
          reason: 'D39 が「取り込み成功で自動的に未解消から外れる」と書いた経路');
    });

    test('★★ 配信側が直してハッシュが変わっても 0 件に戻る（D-13 の根治）★★',
        () async {
      // ★★ 2026-08-27: 向きが逆になった ★★
      //   ここは「取り込めても未解消のまま残る」ことを固定していた。
      //   それが **D-13 そのもの**であり、UI 側で
      //   `supersededByNewerFile` を立てて言い添えるのが当座の手当てだった。
      //   `MasterStateDao.recordFile` が同じ path の過去の失敗を消すようになり、
      //   **記録そのものが残らなくなった。**
      writeDist(
        cards: _cardsJson(heartColor: 'CYAN'),
        hash: 'sha256:broken',
        dataVersion: 1,
      );
      await runImport();
      expect(await master.outstandingImportIssueCount(), 1);

      // ★★ 配信側が直す = 内容が変わる = ハッシュも変わる ★★
      //   これが現実の直り方であって、上のテストの「同じハッシュ」ではない。
      writeDist(cards: _cardsJson(), hash: 'sha256:fixed', dataVersion: 2);
      final result = await runImport();
      expect(result.failedPaths, isEmpty, reason: '今度は取り込めている');

      expect(await master.outstandingImportIssueCount(), 0);
      expect(await master.outstandingImportIssues(), isEmpty,
          reason: '★「未解消でない」ではなく「行が無い」');
    });

    test('★対: 成功のあとに別の版で失敗したら、それは未解消である', () async {
      // ★★ 却下案「判定を path だけの NOT EXISTS にする」を排除する ★★
      //   それだと**本物の失敗を隠す。**
      writeDist(cards: _cardsJson(), hash: 'sha256:v1-ok', dataVersion: 1);
      await runImport();
      expect(await master.outstandingImportIssueCount(), 0);

      writeDist(
        cards: _cardsJson(heartColor: 'CYAN'),
        hash: 'sha256:v2-broken',
        dataVersion: 2,
      );
      await runImport();

      expect(await master.outstandingImportIssueCount(), 1);
      final issues = await master.outstandingImportIssues();
      expect(issues.single.hash, 'sha256:v2-broken');
      // ★現在ハッシュは「いま取り込まれている版」= 古い版のほう。
      //   ★これが `supersededByNewerFile` を撤去した理由でもある ——
      //     残しておくと**この状態で「新しい版で取り込めています」と嘘をつく。**
      expect(issues.single.currentHash, 'sha256:v1-ok');
    });
  });

  group('失敗は 0 件にすり替えない（決定 D53）', () {
    test('DB が閉じていれば RepositoryException が飛ぶ', () async {
      await db.close();

      await expectLater(
        master.outstandingImportIssues(),
        throwsA(isA<RepositoryException>()
            .having((e) => e.op, 'op', 'master.outstandingImportIssues')),
      );
    });
  });
}
