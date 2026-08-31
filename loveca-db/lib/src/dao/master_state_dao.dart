/// 取り込み状態の読み書き.
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../schema/database.dart';
import '../schema/enums.dart';
import '../schema/tables.dart';

class MasterStateDao {
  const MasterStateDao(this.db);

  final LovecaDatabase db;

  // -------------------------------------------------------------------------
  // 版
  // -------------------------------------------------------------------------

  Future<MasterStateRow?> current() =>
      (db.select(db.masterStates)..where((s) => s.id.equals(singletonRowId)))
          .getSingleOrNull();

  Future<int> localDataVersion() async => (await current())?.dataVersion ?? 0;

  /// ★全ファイルが成功したときにだけ呼ぶこと★
  /// `planUpdate` は `remoteVersion.dataVersion <= localDataVersion` で
  /// `upToDate` を返す（`loveca_core` の `planUpdate` の**版ゲート**。
  /// ★行番号で指さない —— 行を 1 つ足した瞬間に古くなる。★以前ここは
  /// 行番号で指しており、★その行は**アプリ版のゲート**（`isAppSupported`）
  /// であって版ゲートではなかった / 決定 **D118-15**）。1 ファイル失敗したのに
  /// ここを上げると、次回は `upToDate` になり**失敗したファイルが
  /// 二度と再取得されない。**
  Future<void> setVersion(VersionInfo version) async {
    await db.into(db.masterStates).insertOnConflictUpdate(
          MasterStatesCompanion.insert(
            // ★id を明示する★
            // INTEGER PRIMARY KEY は rowid の別名になるため、省略すると
            // 列の DEFAULT 0 ではなく自動採番 (1) が入り、単一行のはずが増える。
            id: const Value(singletonRowId),
            dataVersion: Value(version.dataVersion),
            minAppVersion: Value(version.minAppVersion),
            manifestHash: Value(version.manifestHash),
          ),
        );
  }

  // -------------------------------------------------------------------------
  // ファイルのハッシュ
  // -------------------------------------------------------------------------

  /// `planUpdate` に渡す path -> hash。
  Future<Map<String, String>> localFileHashes() async {
    final rows = await db.select(db.masterFiles).get();
    return {for (final r in rows) r.path: r.hash};
  }

  /// ★成功したファイルだけ記録する★
  /// 行が無ければ `planUpdate` から見て `localHash == null` になり、
  /// 次回の計画で再取得対象に残る。これが失敗の再試行を成立させている。
  ///
  /// ★★ 同じ path の過去の失敗を同じトランザクションで消す（D-13）★★
  /// 意味は「そのファイルが**いまの版で読めた**なら、そのファイルについての
  /// 過去の失敗は未解消ではない」。
  ///
  /// ★★ なぜ消す必要があるのか ★★
  /// 「未解消」の判定は `(path, hash)` の一致で行う（[_outstandingWhere]）。
  /// `master_files` は path ごとに**現在のハッシュ 1 件だけ**を持つので、
  /// **配信側がファイルを直すとハッシュが変わり、古い失敗の行と永久に照合できない。**
  /// 決定 D39 の「取り込みに成功した時点で自動的に未解消から外れる」は、
  /// **同じハッシュで再取得が成功する場合（一時的な読み取り失敗）にしか
  /// 当てはまっていなかった。**
  ///
  /// ★★ 失敗の記録を捨ててよい理由 ★★
  /// `import_issues` は「**いま何が読めないか**」を出すための表であって履歴ではない。
  /// 1 回ごとの失敗は起動 Notice が出しており、繰り返しは `occurrenceCount` が持っている。
  /// ★また壊れれば**新しい行が入る**（`firstSeenAt` も新しくなる）。
  /// これは正しい —— **別の版の別の失敗**である。
  ///
  /// ★★ 判定を `path` だけの `NOT EXISTS` にしなかった理由 ★★
  /// ★**逆方向に壊れる。** v1 で成功 → v2 で失敗、のときに「解消済み」に見え、
  /// **本物の失敗を隠す。**
  ///
  /// ★`schemaVersion` は上げない。列も索引も変えないので移行が要らない。
  Future<void> recordFile(ManifestFile file, DateTime importedAt) =>
      db.transaction(() async {
        await db.into(db.masterFiles).insertOnConflictUpdate(
              MasterFilesCompanion.insert(
                path: file.path,
                hash: file.hash,
                bytes: Value(file.bytes),
                cardCount: Value(file.cardCount),
                // ★DB 層は日時を UTC に正規化する（deck_dao.dart と同じ理由）。
                importedAt: importedAt.toUtc(),
              ),
            );
        await (db.delete(db.importIssues)
              ..where((i) => i.path.equals(file.path)))
            .go();
      });

  Future<void> forgetFile(String path) async {
    await (db.delete(db.masterFiles)..where((f) => f.path.equals(path))).go();
  }

  // -------------------------------------------------------------------------
  // 失敗の記録（決定 D39）
  // -------------------------------------------------------------------------

  /// 取り込み失敗を記録する。
  ///
  /// ★主キーが `(path, hash)` なので同じ失敗は 1 行に集約される★
  /// 配信側が壊れたまま直らないと毎回同じ失敗が起きる。
  /// 追記型にすると起動のたびに行が増える。
  Future<void> recordIssue({
    required String path,
    required String hash,
    required ImportIssueKind kind,
    required String message,
    required DateTime at,
  }) async {
    final now = at.toUtc();
    final existing = await (db.select(db.importIssues)
          ..where((i) => i.path.equals(path) & i.hash.equals(hash)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.importIssues).insert(
            ImportIssuesCompanion.insert(
              path: path,
              hash: hash,
              kind: kind,
              message: message,
              firstSeenAt: now,
              lastSeenAt: now,
            ),
          );
      return;
    }

    await (db.update(db.importIssues)
          ..where((i) => i.path.equals(path) & i.hash.equals(hash)))
        .write(
      ImportIssuesCompanion(
        kind: Value(kind),
        message: Value(message),
        occurrenceCount: Value(existing.occurrenceCount + 1),
        lastSeenAt: Value(now),
      ),
    );
  }

  /// 未解消の失敗。
  ///
  /// 「解消済み」= その `(path, hash)` が `master_files` に記録されている
  /// （＝あとで取り込みに成功した）。
  /// ★手で消す運用にしない★ 消し忘れで警告が残り続けるのを防ぐ。
  static const String _outstandingWhere = '''
NOT EXISTS (
  SELECT 1 FROM master_files f
  WHERE f.path = import_issues.path AND f.hash = import_issues.hash
)''';

  /// ★UI が警告を出せるようにするための件数★
  /// 記録するだけで誰も見ない状態にしない（決定 D39）。
  Future<int> outstandingImportIssueCount() async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM import_issues WHERE $_outstandingWhere',
          readsFrom: {db.importIssues, db.masterFiles},
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Phase 3b の警告バッジ用。取り込みの成否に追従して自動で消える。
  Stream<int> watchOutstandingImportIssueCount() => db
      .customSelect(
        'SELECT COUNT(*) AS c FROM import_issues WHERE $_outstandingWhere',
        readsFrom: {db.importIssues, db.masterFiles},
      )
      .watchSingle()
      .map((row) => row.read<int>('c'));

  /// 詳細ダイアログ用。
  Future<List<ImportIssueRow>> outstandingImportIssues() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM import_issues WHERE $_outstandingWhere '
          'ORDER BY path',
          readsFrom: {db.importIssues, db.masterFiles},
        )
        .get();
    return rows.map((row) => db.importIssues.map(row.data)).toList();
  }
}
