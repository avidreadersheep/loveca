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
import '../data/card_detail.dart';
import '../data/card_image_source.dart';
import '../data/card_list_row.dart';
import '../data/clock.dart';
import '../data/deck_repository.dart';
import '../data/dist_locator.dart';
import '../data/master_catalog.dart';
import '../data/master_repository.dart';
import '../data/search_limit.dart';

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

  /// デッキの読み書き（M2）。
  ///
  /// ★★ `LovecaDatabase` を返さない ★★
  /// drift の型が `AppEnvironment` に載ると UI へ漏れ、Phase 5 の Web / WASM 経路で
  /// UI ごと巻き込む（決定 D55）。DB ハンドルは段の内側に閉じたまま、
  /// **組み立て済みのリポジトリだけ**を画面へ出す。
  ///
  /// [catalog] は段 4 の結果。`DeckValidator` の材料になる（決定 D55）。
  DeckRepository decksFor(MasterCatalog catalog);

  /// カードの読み出し（M3 の検索が使う）。
  ///
  /// ★[decksFor] と同じく**組み立て済みのリポジトリだけ**を出す。
  /// `LovecaDatabase` を返さない理由も同じ（決定 D55）。
  CardCatalogRepository cardCatalogFor();

  /// 検索結果の上限と、その出所（決定 D50 / D64）。
  ///
  /// ★段に依らないので getter にしてある。段 1 の前でも決まる。
  SearchLimitSetting get searchLimit;

  /// マスタの状態を読む口（M6 / R6）。
  ///
  /// ★★ ここでも `LovecaDatabase` を返さない（決定 D55）★★
  /// R6 が要るのは `import_issues` の件数と一覧だけで、DB ハンドルではない。
  MasterRepository masterFor();

  /// 設定の書き込み口（M6 / R6）。★`AppSettingsStore.save` の最初の呼び出し元。
  AppSettingsStore settingsStoreFor();

  /// アプリのファイル置き場（R6 の診断表示）。★テストでは null。
  AppPaths? get paths;
}

/// カタログが空のまま起動しようとしたときの失敗（決定 D60 / 設計メモ §4-6(4)）。
///
/// ★★ 無言で空のカタログを返さない ★★
/// 空の一覧を出すと「カードが 1 枚も無いデータ」と区別がつかない。
///
/// ★★ 2026-08-24 訂正 ★★
/// 当初は「dist 不在 かつ 0 件」だけを止めていたが、それは**特殊形**だった。
/// 実機で `dist はある が appTooOld で 1 件も取り込まれず 0 件` に落ち、
/// **成功として通ってしまった。** 見るべきは入口（dist の有無）ではなく
/// **出口（カタログが空か）**である。
class EmptyCatalogException implements Exception {
  const EmptyCatalogException({
    required this.reason,
    this.searchedPaths = const [],
    this.hint,
  });

  /// なぜ空なのか。★段 3 の結末から決まる。
  final String reason;

  /// dist を探した場所（決定 D60）。★不在が原因のとき全部持つ。
  final List<String> searchedPaths;

  /// ★実際の値（アプリ版と要求される最小版など）。
  /// 「アプリが古い」だけでは利用者は直せない。
  final String? hint;

  @override
  String toString() =>
      hint == null ? reason : [reason, hint].join(' / ');
}

/// 本番の 4 段。
class RealBootSteps implements BootSteps {
  RealBootSteps({
    required this.appVersion,
    this.clock = systemClockUtc,
    Map<String, String>? environment,
  }) : searchLimit = resolveSearchLimit(
          (environment ?? Platform.environment)[searchLimitEnvironmentKey],
        );

  final String appVersion;
  final Clock clock;

  /// ★★ `LOVECA_SEARCH_LIMIT` を読むのはここ 1 箇所だけ（決定 D64）★★
  /// 検証用の口であって本番の設定経路ではない（本番の設定経路は D60 の dist 解決だけ）。
  @override
  final SearchLimitSetting searchLimit;

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

    // ★設定が壊れていて既定に戻したなら、その事実を運ぶ（設計メモ §4-6(5)）。
    //   捨てると「設定したのに効かない」が原因不明のまま残る。
    final settingsRecoveredFrom = settings.recoveredFrom;

    if (!located.found) {
      // ★★ MasterImporter を呼ばない（決定 D60）★★
      // 呼ぶと読み取り例外になり、原因が「dist が無い」から「読めない」に化ける。
      return MasterImportOutcome(
        distMissing: true,
        location: located,
        appVersion: appVersion,
        settings: settings.settings,
        settingsRecoveredFrom: settingsRecoveredFrom,
      );
    }

    _distDir = located.directory;
    return MasterRepository(handle.db).import(
      location: located,
      appVersion: appVersion,
      settings: settings.settings,
      now: clock(),
      settingsRecoveredFrom: settingsRecoveredFrom,
      // ★★ 画像を★端末へ写さない（★決定 **D149-3**）★★
      //   ★**ここはローカルの dist から取り込む経路である** ——
      //     ★★画像は既に読み先（段 1）に在る★★ので、★写すと 571 MB を二重に持つ。
      //   ★**渡す相手は★HTTP から取り込む経路**（★§32-6 の 8 の 5 / ★未着手）。
      imageSink: null,
    );
  }

  @override
  Future<MasterCatalog> loadCatalog(MasterImportOutcome importOutcome) async {
    final handle = _db;
    final catalog = CardCatalogRepository(handle.db);
    final master = MasterRepository(handle.db);

    final rows = await catalog.loadListRows();
    final cards = await catalog.cardsByNumber();

    // ★★ 出口で見る。カタログが空なら理由を添えて止める（設計メモ §4-6(4)）★★
    if (cards.isEmpty) throw emptyCatalogFailure(importOutcome);

    return MasterCatalog(
      cards: cards,
      printings: await catalog.printingsById(),
      config: await master.ruleConfig(),
      rows: rows,
      dataVersion: await master.localDataVersion(),
    );
  }

  /// ★★ 読み先は★段で決まる（★決定 **D137-1** ＝ 画経-4 / **D149-2**）★★
  ///
  /// ★**段 1 ＝ `dist/images`（★今日までの唯一の形）／ ★★段 2 ＝ 端末の領域★★。**
  /// ★★**読み先は★常に 1 つである**★★（**D137-4** の柵 1 —— ★2 つ読むと **D43** の害が戻る）。
  /// ★**判定は★★純粋関数に切り出してある★★**（`resolveCardImagesRoot`）—— ★対を置くため。
  @override
  CardImageSource imageSourceFor(MasterImportOutcome importOutcome) =>
      LocalDirectoryCardImageSource(
        resolveCardImagesRoot(
          distDir: _distDir,
          deviceImagesDir: _handle?.paths.cardImagesDir,
        ).root,
      );

  @override
  DeckRepository decksFor(MasterCatalog catalog) =>
      // ★時刻は Clock から供給する（設計メモ §9-1）。層の内側で DateTime.now() を呼ばない。
      DeckRepository(_db.db, catalog: catalog, clock: clock);

  @override
  CardCatalogRepository cardCatalogFor() => CardCatalogRepository(_db.db);

  @override
  MasterRepository masterFor() => MasterRepository(_db.db);

  @override
  AppSettingsStore settingsStoreFor() =>
      AppSettingsStore(_db.paths.settingsFile);

  @override
  AppPaths? get paths => _handle?.paths;
}

/// カタログが空だった理由を段 3 の結末から決める（設計メモ §4-6(4)）。
///
/// ★★ 理由には必ず「実際の値」を入れる ★★
/// 「アプリが古い」だけでは利用者は直せない。
EmptyCatalogException emptyCatalogFailure(MasterImportOutcome outcome) {
  if (outcome.distMissing) {
    return EmptyCatalogException(
      reason: 'カードデータ（dist）が見つかりません',
      searchedPaths: outcome.searchedPaths,
      hint: '環境変数 LOVECA_DIST_DIR で場所を指定できます。',
    );
  }

  final result = outcome.result;
  switch (result?.decision) {
    case UpdateDecision.appTooOld:
      return EmptyCatalogException(
        reason: 'アプリが古いため配信データを取り込めませんでした',
        // ★実値を出す。これが無いと利用者はどちらを直せばよいか分からない。
        hint: 'このアプリ: ${outcome.appVersion} / '
            'データが要求する最小版: ${outcome.remoteMinAppVersion ?? '不明'}',
      );
    case UpdateDecision.upToDate:
      return const EmptyCatalogException(
        reason: '取り込み済みのはずですがカードがありません',
        hint: 'master_state の版と実データが食い違っています。'
            'データベースを削除して作り直してください。',
      );
    case UpdateDecision.update:
      if (result!.hasFailures) {
        return EmptyCatalogException(
          reason: '${result.failedPaths.length} 件の商品ファイルを取り込めませんでした',
          searchedPaths: result.failedPaths,
        );
      }
      return const EmptyCatalogException(
        reason: '取り込みは成功しましたがカードが 1 件もありません',
      );
    case null:
      return const EmptyCatalogException(reason: 'カードがありません');
  }
}

/// 画面が使う道具一式。★`AppScope` が配る。
class AppEnvironment {
  const AppEnvironment({
    required this.catalog,
    required this.imageSource,
    required this.decks,
    required this.cardCatalog,
    required this.cardDetail,
    required this.searchLimit,
    required this.clock,
    required this.master,
    required this.settingsStore,
    required this.importOutcome,
    required this.appVersion,
    this.paths,
  });

  final MasterCatalog catalog;
  final CardImageSource imageSource;

  /// デッキの読み書き（M2）。★UI はこれより下（DAO / drift）を直接呼ばない（決定 D55）。
  final DeckRepository decks;

  /// カードの読み出しと検索（M3）。★同上。
  final CardCatalogRepository cardCatalog;

  /// カード詳細の材料（M5 / R5）。
  ///
  /// ★★ カタログから起動時に 1 回だけ組む（決定 D55 / D56）★★
  /// 取り込みは起動ゲートでしか走らないのでセッション中ずっと不変であり、
  /// **無効化処理そのものが要らない。** DB へも行かない。
  final CardDetailView cardDetail;

  /// 検索結果の上限と、その出所（決定 D50 / D64）。
  final SearchLimitSetting searchLimit;

  final Clock clock;

  /// マスタの状態（R6 / M6）。★`import_issues` の出口（決定 D39）。
  final MasterRepository master;

  /// 設定の書き込み（R6 / M6）。
  final AppSettingsStore settingsStore;

  /// 段 3 の結末そのもの（R6 の診断表示）。
  ///
  /// ★★ M5 までは `BootController` の中で捨てていた ★★
  /// 「どこの dist を どの段で 掴んで 何が起きたか」は**セッション中ずっと不変**で、
  /// R6 が出す唯一の材料である。
  final MasterImportOutcome importOutcome;

  /// このアプリの版（`AppInfo.version`）。★`minAppVersion` と並べて出す。
  final String appVersion;

  /// DB と設定ファイルの置き場（R6 の診断表示）。★テストでは null。
  final AppPaths? paths;

  /// このセッションで効いている設定（R6 の初期値）。
  AppSettings get settings => importOutcome.settings;

  List<CardListRow> get rows => catalog.rows;

  /// M2 以降が `DeckValidator` を組むための材料（決定 D55）。
  Map<String, Card> get cards => catalog.cards;
  Map<String, Printing> get printings => catalog.printings;
  RuleConfig get ruleConfig => catalog.config;
}
