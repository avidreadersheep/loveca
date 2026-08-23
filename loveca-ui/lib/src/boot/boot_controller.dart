/// 起動ゲートの進行（`docs/UI設計メモ.md` §3-5(3)）.
///
/// ★★ 失敗を段つきで持ち帰る ★★
/// どの段で失敗したかが分からないと、「デッキが読めない」と「カードが古い」を
/// 利用者が区別できず、続行できる状態でも「壊れた」と誤解する。
library;

import 'package:flutter/foundation.dart';

import '../data/clock.dart';
import '../data/master_catalog.dart';
import '../data/master_repository.dart';
import '../state/store.dart';
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
          clock: clock,
        ),
        notices: notices,
        timings: timings,
      );

      _printSummary(catalog, timings, notices);
    } on Object catch (error, stackTrace) {
      final current = value;
      state = BootFailed(
        stage: current is BootRunning ? current.stage : BootStageId.catalog,
        error: error,
        stackTrace: stackTrace,
        searchedPaths: switch (error) {
          DistMissingAndEmptyException(:final searchedPaths) => searchedPaths,
          _ => const [],
        },
      );
    }
  }

  /// ★決定 D39 / D60: 黙って捨てない。続行できる失敗も必ず出す。
  static void _collectImportNotices(
    MasterImportOutcome outcome,
    List<BootNotice> notices,
  ) {
    if (outcome.distMissing) {
      notices.add(BootNotice(
        'カードデータを更新できませんでした（前回取り込んだ内容で動いています）',
        details: outcome.searchedPaths,
      ));
      return;
    }

    final result = outcome.result;
    if (result == null) return;

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

  /// 起動サマリ。★実測の読み取り口（決定 D55 の判断根拠の検算）。
  static void _printSummary(
    MasterCatalog catalog,
    BootTimings timings,
    List<BootNotice> notices,
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
    for (final notice in notices) {
      debugPrint('[boot] notice: ${notice.message}');
    }
  }
}
