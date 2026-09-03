/// 起動ゲートの進行（`docs/UI設計メモ.md` §3-5(3)）.
///
/// ★★ 失敗を段つきで持ち帰る ★★
/// どの段で失敗したかが分からないと、「デッキが読めない」と「カードが古い」を
/// 利用者が区別できず、続行できる状態でも「壊れた」と誤解する。
library;

import 'package:flutter/foundation.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import '../data/clock.dart';
import '../data/master_catalog.dart';
import '../data/master_repository.dart';
import '../data/search_limit.dart';
import '../state/store.dart';
import '../data/card_detail.dart';
import 'boot_steps.dart';

sealed class BootState {
  const BootState();
}

final class BootRunning extends BootState {
  const BootRunning(this.stage);

  final BootStageId stage;
}

final class BootFailed extends BootState {
  const BootFailed({
    required this.stage,
    required this.error,
    required this.stackTrace,
    this.searchedPaths = const [],
  });

  /// ★どの段で失敗したか。表示の要。
  final BootStageId stage;

  final Object error;
  final StackTrace stackTrace;

  /// dist を探した場所（決定 D60）。★不在が原因のときに全部出す。
  final List<String> searchedPaths;
}

/// 取り込みをもう一度走らせた結果（`docs/Android UI 決定.md` §1-5）。
///
/// ★★ `BootState` に混ぜない ★★
/// ★**起動の状態と★再取り込みの結果は★★主語が違う★★** ——
/// 前者は「アプリが立ち上がったか」、後者は「押した操作が通ったか」。
/// ★混ぜると★★再取り込みに失敗しただけでアプリが失敗画面へ倒れる★★。
sealed class MasterReloadResult {
  const MasterReloadResult();
}

/// 差し替えた。
final class MasterReloadDone extends MasterReloadResult {
  const MasterReloadDone({required this.outcome, required this.notices});

  final MasterImportOutcome outcome;

  /// ★★ 起動と同じ規則で集めた（決定 D39 / D60: 黙って捨てない）★★
  final List<BootNotice> notices;
}

/// 走らせたが失敗した。★**古いカタログのまま動き続ける。**
final class MasterReloadFailed extends MasterReloadResult {
  const MasterReloadFailed({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;
}

/// 走らせなかった。
///
/// ★★ 失敗と分けている ★★
/// ★**「起動が終わっていない」「もう 1 本走っている」は★★取り込みの失敗ではない★★。**
/// ★畳むと「データが壊れている」と読める文面が出る。
final class MasterReloadRefused extends MasterReloadResult {
  const MasterReloadRefused();
}

final class BootReady extends BootState {
  const BootReady({
    required this.environment,
    required this.notices,
    required this.timings,
  });

  final AppEnvironment environment;

  /// ★エラーではないが伝えるべきこと（`docs/UI設計メモ.md` §3-4(3)）。
  final List<BootNotice> notices;

  final BootTimings timings;
}

class BootController extends Store<BootState> {
  BootController(this._steps, {this.clock = systemClockUtc})
      : super(const BootRunning(BootStageId.sqlite));

  final BootSteps _steps;

  /// ★UI 層で `DateTime.now()` を書くのは `systemClockUtc` の 1 行だけ
  /// （`docs/UI設計メモ.md` §9-1）。ここは受け取って配るだけ。
  final Clock clock;

  Future<void> run() async {
    final notices = <BootNotice>[];
    final sw = Stopwatch()..start();
    var mark = Duration.zero;

    Duration lap() {
      final now = sw.elapsed;
      final delta = now - mark;
      mark = now;
      return delta;
    }

    // ★段に依らない設定なので最初に見る（決定 D64）。
    //   上書きも不正値も**黙って通さない**。
    _collectSearchLimitNotices(_steps.searchLimit, notices);

    try {
      state = const BootRunning(BootStageId.sqlite);
      await _steps.checkSqlite();
      final sqliteTime = lap();

      state = const BootRunning(BootStageId.database);
      await _steps.openDatabase();
      final databaseTime = lap();

      state = const BootRunning(BootStageId.import);
      final outcome = await _steps.importMaster();
      _collectImportNotices(outcome, notices);
      final importTime = lap();

      state = const BootRunning(BootStageId.catalog);
      final catalog = await _steps.loadCatalog(outcome);
      final catalogTime = lap();

      final timings = BootTimings(
        sqlite: sqliteTime,
        database: databaseTime,
        import: importTime,
        catalog: catalogTime,
      );

      state = BootReady(
        environment: AppEnvironment(
          catalog: catalog,
          imageSource: _steps.imageSourceFor(outcome),
          decks: _steps.decksFor(catalog),
          cardCatalog: _steps.cardCatalogFor(),
          // ★カタログから組むだけ。段（BootSteps）を経由しないのは
          //   DB も dist も要らないため（決定 D55）。
          cardDetail: CardDetailView(catalog),
          searchLimit: _steps.searchLimit,
          clock: clock,
          // ★M6: R6（設定・診断）が読む材料。段の中で捨てない。
          master: _steps.masterFor(),
          settingsStore: _steps.settingsStoreFor(),
          importOutcome: outcome,
          appVersion: outcome.appVersion,
          paths: _steps.paths,
        ),
        notices: notices,
        timings: timings,
      );

      _printSummary(catalog, timings, notices, _steps.searchLimit);
    } on Object catch (error, stackTrace) {
      final current = value;
      final failed = BootFailed(
        stage: current is BootRunning ? current.stage : BootStageId.catalog,
        error: error,
        stackTrace: stackTrace,
        searchedPaths: switch (error) {
          EmptyCatalogException(:final searchedPaths) => searchedPaths,
          _ => const [],
        },
      );
      state = failed;
      // ★★ 失敗もログに出す ★★
      // 画面にしか出さないと、ログしか見られない状況（CI・遠隔・自動確認）で
      // 「起動しなかった」以上のことが分からない。成功時だけ出すのは片手落ち。
      _printFailure(failed);
    }
  }

  /// 取り込みをもう一度走らせ、カタログを差し替える（`docs/Android UI 決定.md` §1-5）。
  ///
  /// ★★ 決定 D56 を覆した部分と、★覆していない部分を分ける ★★
  ///
  /// | | |
  /// |---|---|
  /// | ★**覆した** | ★**取り込みが★★起動ゲート以外でも走る★★** |
  /// | ★★**覆していない**★★ | ★**D56 が挙げた害そのもの** —— ★★`MasterCatalog` と
  ///   `DeckValidator` が古くなることは★1 ミリも消えていない★★ |
  ///
  /// ★★ 受け入れた穴（★申し送り §2 の穴 2）★★
  /// ★**この口は★★`AppEnvironment` を丸ごと作り直して差し替える★★**ので、
  /// ★`AppScope` より下は新しいカタログを見る。
  /// ★★**ただし★既に開いている `DeckEditStore` は★古いリポジトリを掴んだままである**★★
  /// （★構築時に受け取っているため）。★★利用者が承知のうえで受け入れた★★。
  ///
  /// ★★ 進捗はここで出さない ★★
  /// ★**`BootRunning` へ落とさない** —— ★★落とすと画面の木ごと捨てられる★★
  /// （`BootGate` が読み込み画面へ切り替わる）。★進捗は**呼ぶ側**が出す。
  ///
  /// ★★ 失敗しても `BootFailed` にしない ★★
  /// ★**起動は既に成功している。**★★アプリ全体を失敗画面へ倒すのは過剰である★★。
  /// → ★**答えを返す。★呼ぶ側が見せる**（★§32-6 の 25 と同じ形）。
  ///
  /// ★★ `BootTimings` は差し替えない ★★
  /// ★あれは**起動の内訳**であり、★★再取り込みは起動ではない★★。
  Future<MasterReloadResult> reload() async {
    final current = value;
    if (current is! BootReady) {
      // ★★ 起動が終わる前に呼ばれた ★★
      //   ★DB も dist も揃っていない段が在りうるので、★★走らせない★★。
      return const MasterReloadRefused();
    }
    if (_reloading) {
      // ★★ 2 つ同時に走らせない ★★
      //   ★取り込みは DB を書く。★同じ DB へ 2 本走らせる理由が無い。
      return const MasterReloadRefused();
    }
    _reloading = true;
    try {
      final notices = <BootNotice>[];
      _collectSearchLimitNotices(_steps.searchLimit, notices);
      final outcome = await _steps.importMaster();
      _collectImportNotices(outcome, notices);
      final catalog = await _steps.loadCatalog(outcome);

      state = BootReady(
        environment: AppEnvironment(
          catalog: catalog,
          imageSource: _steps.imageSourceFor(outcome),
          decks: _steps.decksFor(catalog),
          cardCatalog: _steps.cardCatalogFor(),
          cardDetail: CardDetailView(catalog),
          searchLimit: _steps.searchLimit,
          clock: clock,
          master: _steps.masterFor(),
          settingsStore: _steps.settingsStoreFor(),
          importOutcome: outcome,
          appVersion: outcome.appVersion,
          paths: _steps.paths,
        ),
        notices: notices,
        // ★★ 起動の内訳はそのまま持ち越す（★上の doc）★★
        timings: current.timings,
      );
      return MasterReloadDone(outcome: outcome, notices: notices);
    } on Object catch (error, stackTrace) {
      // ★★ 直前の `BootReady` を 1 ビットも触らない ★★
      //   ★失敗しても**アプリは動き続ける**（★古いカタログのままである）。
      return MasterReloadFailed(error: error, stackTrace: stackTrace);
    } finally {
      _reloading = false;
    }
  }

  bool _reloading = false;

  /// 検索上限の上書き（決定 D64）。
  ///
  /// ★★ 上書きされていることを見える形にする ★★
  /// 気づかずに使い続けると「打ち切りが頻発するアプリ」だと誤認する。
  /// 出す先を Notice にしたのは、これが**セッション中ずっと続く状態**だから
  /// （`docs/UI設計メモ.md` §2-6: その瞬間の状態は検索画面、永続する状態は Notice）。
  /// ★打ち切りの文面にも実効上限を出す（誤認が起きるまさにその瞬間に出る）。
  ///
  /// ★★ 不正値を黙って既定に戻さない ★★
  /// 黙って戻すのは A-3 と同じ型で、「下げたはずなのに打ち切られない」が
  /// 原因不明のまま残る。**起動は止めない** ——
  /// 検証用の変数が本番起動を壊せる状態にしないため
  /// （設定ファイルが壊れていたときと同じ扱い / 設計メモ §4-6(5)）。
  static void _collectSearchLimitNotices(
    SearchLimitSetting setting,
    List<BootNotice> notices,
  ) {
    if (setting.rejectedValue case final bad?) {
      notices.add(BootNotice(
        '$searchLimitEnvironmentKey の値を解釈できないため既定に戻しました',
        // ★実値を出す。これが無いと利用者はどこを直せばよいか分からない。
        details: [
          '指定された値: $bad',
          '使う上限: ${setting.limit} 件（既定）',
          '1 以上の整数を指定してください。',
        ],
      ));
      return;
    }

    if (setting.overriddenValue case final value?) {
      notices.add(BootNotice(
        '検索結果の上限が ${setting.limit} 件に変更されています（検証用）',
        details: [
          '$searchLimitEnvironmentKey = $value',
          '既定は ${CardSearchDao.defaultLimit} 件（決定 D50）',
          'この状態では実データでも打ち切りが起こりえます。',
        ],
      ));
    }
  }

  /// ★決定 D39 / D60: 黙って捨てない。続行できる失敗も必ず出す。
  static void _collectImportNotices(
    MasterImportOutcome outcome,
    List<BootNotice> notices,
  ) {
    // ★設定ファイルの復旧は dist の有無と独立に起きる。先に出す（設計メモ §4-6(5)）。
    if (outcome.settingsRecoveredFrom case final reason?) {
      notices.add(BootNotice(
        '設定ファイルを読めなかったため既定に戻しました',
        details: ['$reason'],
      ));
    }

    if (outcome.distMissing) {
      // ★★ 内部語彙 `dist` を出さない。症状と、次にすべきことを書く（決定 D89）★★
      //   以前は「データを更新できませんでした」としか言わず、
      //   実際に起きること（**カード画像が 1 枚も出ない**）に触れていなかった。
      //   画像は dist からしか読まない（D43）ので、これは必ず起きる。
      notices.add(BootNotice(
        'カードデータの置き場所が見つかりません。カード画像は 1 枚も表示されません',
        details: [
          'カードの一覧とデッキは、前回取り込んだ内容で動いています。',
          '設定画面で「カードデータの場所」を指定してください。',
          // ★探した場所を省かない（決定 D60）。
          ...outcome.searchedPaths,
        ],
      ));
      return;
    }

    final result = outcome.result;
    if (result == null) return;

    // ★★ 取り込みが 1 件も行われなかった事実を黙って落とさない ★★
    // appTooOld / upToDate は例外を投げずに戻る。カタログが空でなければ
    // 起動は続くので、ここで出さないと「新しい商品が出ているのに増えない」が
    // 原因不明のまま残る（設計メモ §4-6(4)）。
    switch (result.decision) {
      case UpdateDecision.appTooOld:
        notices.add(BootNotice(
          'アプリが古いため配信データを取り込めませんでした',
          // ★実値を出す。これが無いとどちらを直せばよいか分からない。
          details: [
            'このアプリ: ${outcome.appVersion}',
            'データが要求する最小版: ${outcome.remoteMinAppVersion ?? '不明'}',
          ],
        ));
      case UpdateDecision.upToDate:
      case UpdateDecision.update:
        break;
    }

    if (result.failedPaths.isNotEmpty) {
      notices.add(BootNotice(
        '${result.failedPaths.length} 件の商品ファイルを取り込めませんでした',
        details: result.failedPaths,
      ));
    }
    if (result.unhandledPaths.isNotEmpty) {
      notices.add(BootNotice(
        '${result.unhandledPaths.length} 件の未対応ファイルがありました',
        details: result.unhandledPaths,
      ));
    }
    if (result.hasFailures && !result.dataVersionAdvanced) {
      notices.add(const BootNotice(
        'データ版は据え置きです（失敗したファイルは次回再取得されます）',
      ));
    }
  }

  static void _printFailure(BootFailed failed) {
    debugPrint('[boot] FAILED at ${failed.stage.label}: ${failed.error}');
    for (final path in failed.searchedPaths) {
      debugPrint('[boot]   探した場所: $path');
    }
  }

  /// 起動サマリ。★実測の読み取り口（決定 D55 の判断根拠の検算）。
  static void _printSummary(
    MasterCatalog catalog,
    BootTimings timings,
    List<BootNotice> notices,
    SearchLimitSetting searchLimit,
  ) {
    String ms(Duration d) => '${d.inMicroseconds / 1000}ms';
    debugPrint(
      '[boot] ok  total=${ms(timings.total)}  '
      'sqlite=${ms(timings.sqlite)} db=${ms(timings.database)} '
      'import=${ms(timings.import)} catalog=${ms(timings.catalog)}',
    );
    debugPrint(
      '[boot] catalog  rows=${catalog.rows.length} '
      'cards=${catalog.cardCount} printings=${catalog.printingCount} '
      'dataVersion=${catalog.dataVersion} '
      'imageHashが空の刷り=${catalog.rowsWithoutImage}',
    );
    // ★上書きされているかをログにも出す（決定 D64）。
    //   画面にしか出さないと、ログしか見られない状況で追えない。
    debugPrint(
      '[boot] searchLimit=${searchLimit.limit}'
      '${searchLimit.isOverridden ? ' (★$searchLimitEnvironmentKey で上書き)' : ''}',
    );
    for (final notice in notices) {
      debugPrint('[boot] notice: ${notice.message}');
    }
  }
}
