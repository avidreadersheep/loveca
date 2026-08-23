/// 起動ゲートの 4 段（`docs/UI設計メモ.md` §3-5(3)）.
///
/// ★★ 段を分ける理由は「どの段で失敗したか」を言えるようにするため ★★
/// 段 2（DB を開く + 移行）と段 3（取り込み）を混ぜると
/// 「デッキが読めない」と「カードが古い」が区別できない。
/// 前者は続行不能、後者は続行可能。混ぜると利用者が「壊れた」と誤解する。
///
/// ★段は差し替えられる形にしてある。テストが実 DB を要求しないため。
library;

import 'dart:io';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';

import '../data/app_database.dart';
import '../data/app_paths.dart';
import '../data/app_settings.dart';
import '../data/card_catalog_repository.dart';
import '../data/card_image_source.dart';
import '../data/card_list_row.dart';
import '../data/clock.dart';
import '../data/dist_locator.dart';
import '../data/master_catalog.dart';
import '../data/master_repository.dart';

enum BootStageId {
  /// 1: ネイティブ sqlite3 の確認。
  sqlite,

  /// 2: DB を開く + 移行。
  database,

  /// 3: マスタ取り込み。
  import,

  /// 4: カタログ読み込み。
  catalog;

  String get label => switch (this) {
        BootStageId.sqlite => '段1: ネイティブ sqlite3 の確認',
        BootStageId.database => '段2: データベースを開く / 移行',
        BootStageId.import => '段3: カードデータの取り込み',
        BootStageId.catalog => '段4: カタログの読み込み',
      };
}

/// 起動時に出す「エラーではないが伝えるべきこと」（`docs/UI設計メモ.md` §3-4(3)）。
///
/// ★`Loadable` の `Failed` では表せない。**成功したが不完全**を成功と混ぜない。
class BootNotice {
  const BootNotice(this.message, {this.details = const []});

  final String message;
  final List<String> details;
}

/// 段 2 で開いた DB。★段の内側に閉じてある。
///
/// これを [BootSteps] の引数や戻り値に出すと、
/// **テストが実 DB を用意しないと段 3 以降を試せなくなる。**
/// 段どうしの受け渡しは実装（[RealBootSteps]）の内部で行う。
class _DatabaseHandle {
  const _DatabaseHandle(this.db, this.paths);

  final LovecaDatabase db;
  final AppPaths paths;
}

/// 段ごとの所要時間。★決定 D55 の判断根拠を実測で裏づけるために測る。
class BootTimings {
  const BootTimings({
    required this.sqlite,
    required this.database,
    required this.import,
    required this.catalog,
  });

  final Duration sqlite;
  final Duration database;
  final Duration import;

  /// ★`MasterCatalog` の構築時間。設計メモの見積りは 40〜60ms だが、
  /// それは `DeckDao.validate` 経由の推定であって起動時の一括構築の実測ではない。
  final Duration catalog;

  Duration get total => sqlite + database + import + catalog;
}

/// 4 段の中身。★テストはこれを差し替える。
///
/// ★★ 段どうしの受け渡しを引数に出さない ★★
/// DB ハンドルを引数にすると、**テストが実 DB を用意しないと
/// 段 3 以降を試せなくなる**。「どの段で失敗したか」を固定したいだけなのに
/// ネイティブ sqlite3 とファイル I/O が要る、という本末転倒になる。
abstract class BootSteps {
  /// 段 1。要求を満たさなければ投げる。
  Future<void> checkSqlite();

  /// 段 2。開いた DB は実装の内部に保つ。
  Future<void> openDatabase();

  /// 段 3。★dist が無ければ `MasterImporter` を呼ばずに戻る（決定 D60）。
  Future<MasterImportOutcome> importMaster();

  /// 段 4。★`distMissing` かつ `cards` が 0 件なら投げる（決定 D60）。
  Future<MasterCatalog> loadCatalog(MasterImportOutcome importOutcome);

  /// 段 4 まで通ったあとに作る、画面が使う道具一式。
  CardImageSource imageSourceFor(MasterImportOutcome importOutcome);
}

/// dist が無く、DB にもカードが無いときの失敗（決定 D60）。
///
/// ★★ 無言で空のカタログを返さない ★★
/// 空の一覧を出すと「カードが 1 枚も無いデータ」と区別がつかない。
class DistMissingAndEmptyException implements Exception {
  const DistMissingAndEmptyException(this.searchedPaths);

  /// ★どこを見て無かったのかを全部持つ。出さないと利用者は直せない。
  final List<String> searchedPaths;

  @override
  String toString() => 'カードデータが見つかりません';
}

/// 本番の 4 段。
class RealBootSteps implements BootSteps {
  RealBootSteps({required this.appVersion, this.clock = systemClockUtc});

  final String appVersion;
  final Clock clock;

  Directory? _distDir;
  _DatabaseHandle? _handle;

  _DatabaseHandle get _db {
    final handle = _handle;
    if (handle == null) {
      throw StateError('段2 を通っていない');
    }
    return handle;
  }

  @override
  Future<void> checkSqlite() async {
    // ★loveca_db の既存 API。FTS5 が無いビルドを掴んでいると
    //   card_search の作成時まで気づけない（`open_sqlite.dart` の doc）。
    assertSqliteCapabilities();
  }

  @override
  Future<void> openDatabase() async {
    final paths = await AppPaths.resolve();
    // ★ここで SELECT 1 を打って onCreate / onUpgrade / beforeOpen を走らせきる。
    final db = await openAppDatabase(paths.databaseFile);
    _handle = _DatabaseHandle(db, paths);
  }

  @override
  Future<MasterImportOutcome> importMaster() async {
    final handle = _db;
    final settings = await AppSettingsStore(handle.paths.settingsFile).load();
    final located = await DesktopDistLocator(
      settingsDistDir: settings.settings.distDir,
    ).locate();

    if (!located.found) {
      // ★★ MasterImporter を呼ばない（決定 D60）★★
      // 呼ぶと読み取り例外になり、原因が「dist が無い」から「読めない」に化ける。
      return MasterImportOutcome(
        distMissing: true,
        searchedPaths: located.searched,
      );
    }

    _distDir = located.directory;
    return MasterRepository(handle.db).import(
      distDir: located.directory!,
      searchedPaths: located.searched,
      appVersion: appVersion,
      now: clock(),
    );
  }

  @override
  Future<MasterCatalog> loadCatalog(MasterImportOutcome importOutcome) async {
    final handle = _db;
    final catalog = CardCatalogRepository(handle.db);
    final master = MasterRepository(handle.db);

    final rows = await catalog.loadListRows();
    final cards = await catalog.cardsByNumber();

    // ★dist が無く、DB にもカードが無いなら停止する（決定 D60）。
    if (importOutcome.distMissing && cards.isEmpty) {
      throw DistMissingAndEmptyException(importOutcome.searchedPaths);
    }

    return MasterCatalog(
      cards: cards,
      printings: await catalog.printingsById(),
      config: await master.ruleConfig(),
      rows: rows,
      dataVersion: await master.localDataVersion(),
    );
  }

  @override
  CardImageSource imageSourceFor(MasterImportOutcome importOutcome) =>
      LocalDirectoryCardImageSource(
        _distDir == null ? null : Directory('${_distDir!.path}/images'),
      );
}

/// 画面が使う道具一式。★`AppScope` が配る。
class AppEnvironment {
  const AppEnvironment({
    required this.catalog,
    required this.imageSource,
    required this.clock,
  });

  final MasterCatalog catalog;
  final CardImageSource imageSource;
  final Clock clock;

  List<CardListRow> get rows => catalog.rows;

  /// M2 以降が `DeckValidator` を組むための材料（決定 D55）。
  Map<String, Card> get cards => catalog.cards;
  Map<String, Printing> get printings => catalog.printings;
  RuleConfig get ruleConfig => catalog.config;
}
