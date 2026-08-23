/// 試作用の DB 起動.
///
/// ★`loveca_db` は一切変更しない★
/// `LovecaDatabase(QueryExecutor)` という既存の口だけを使う。
/// 別 isolate 版の executor（`NativeDatabase.createInBackground`）は
/// 「呼び出し側が QueryExecutor を用意する」という loveca_db の設計どおり、
/// こちら側で組み立てる。
///
/// 初回だけ実 dist をファイル DB へ取り込み、2 回目以降は開くだけにする。
/// 毎回インメモリへ取り込むと「初回表示までの時間」の測定が取り込み時間に埋もれる。
library;


import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';

import 'paths.dart';

/// `--dart-define=LOVECA_DB_BACKGROUND=false` で UI isolate 実行に切り替える。
/// ★これ自体が測定項目（D45 の候補）。
const bool useBackgroundIsolate =
    bool.fromEnvironment('LOVECA_DB_BACKGROUND', defaultValue: true);

/// `--dart-define=LOVECA_DB_FRESH=true` でキャッシュ DB を捨てて取り込み直す。
const bool forceFreshImport = bool.fromEnvironment('LOVECA_DB_FRESH');

class SpikeDbOpenResult {
  SpikeDbOpenResult({
    required this.db,
    required this.paths,
    required this.capabilities,
    required this.usedBackgroundIsolate,
    required this.didImport,
    required this.openMillis,
    required this.importMillis,
    this.importResult,
    this.importError,
  });

  final LovecaDatabase db;
  final SpikePaths paths;
  final SqliteCapabilities capabilities;
  final bool usedBackgroundIsolate;

  /// この起動で取り込みを走らせたか（＝コールドスタート）。
  final bool didImport;
  final int openMillis;
  final int importMillis;
  final MasterImportResult? importResult;
  final Object? importError;
}

/// 試作用の DB を開く。無ければ実 dist から作る。
Future<SpikeDbOpenResult> openSpikeDatabase({bool? background}) async {
  final useBackground = background ?? useBackgroundIsolate;
  final paths = SpikePaths.resolve();
  final sw = Stopwatch()..start();

  // ★ネイティブ sqlite3 が要求を満たすか、最初に確かめる（既存 API）。
  //   FTS5 が無いビルドを掴んでいると card_search の作成時まで気づけない。
  final caps = probeSqliteCapabilities();

  paths.cacheDir.createSync(recursive: true);
  if (forceFreshImport && paths.dbFile.existsSync()) {
    paths.dbFile.deleteSync();
  }
  final needsImport = !paths.dbFile.existsSync();

  final QueryExecutor executor = useBackground
      ? NativeDatabase.createInBackground(paths.dbFile)
      : openFileExecutor(paths.dbFile.path);
  final db = LovecaDatabase(executor);

  // スキーマ作成（onCreate）をここで確実に走らせる。
  await db.customSelect('SELECT 1').get();
  final openMillis = sw.elapsedMilliseconds;

  if (!needsImport) {
    return SpikeDbOpenResult(
      db: db,
      paths: paths,
      capabilities: caps,
      usedBackgroundIsolate: useBackground,
      didImport: false,
      openMillis: openMillis,
      importMillis: 0,
    );
  }

  if (!paths.distExists) {
    return SpikeDbOpenResult(
      db: db,
      paths: paths,
      capabilities: caps,
      usedBackgroundIsolate: useBackground,
      didImport: false,
      openMillis: openMillis,
      importMillis: 0,
      importError: StateError(
        '★実データ未配置★ ${paths.distDir.path} がありません。'
        'loveca-data/data/ は git 管理外です。'
        '--dart-define=LOVECA_DIST_DIR=... で場所を指定できます。',
      ),
    );
  }

  final importSw = Stopwatch()..start();
  MasterImportResult? result;
  Object? error;
  try {
    result = await MasterImporter(db).import(
      remoteVersion: VersionInfo.parse(paths.versionJson.readAsStringSync()),
      remoteManifest: Manifest.parse(paths.manifestJson.readAsStringSync()),
      source: LocalDirectoryMasterFileSource(paths.distDir),
      appVersion: '1.0.0',
      // ★試作は loveca_core の外なので DateTime.now() を使って良い。
      //   層の内側（core / db）へは呼び出し側から渡す形が保たれている。
      now: DateTime.now().toUtc(),
    );
  } catch (e) {
    error = e;
  }
  importSw.stop();

  return SpikeDbOpenResult(
    db: db,
    paths: paths,
    capabilities: caps,
    usedBackgroundIsolate: useBackground,
    didImport: true,
    openMillis: openMillis,
    importMillis: importSw.elapsedMilliseconds,
    importResult: result,
    importError: error,
  );
}
