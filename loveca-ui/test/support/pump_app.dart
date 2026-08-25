/// 画面を `AppScope` の下で立てる（テスト用）.
///
/// ★★ 起動ゲートを通さずに画面だけ試す ★★
/// 起動の 4 段は `boot/boot_gate_test.dart` が固定している。画面のテストで
/// そこを通すと、落ちたときにどちらの問題か切り分けられない（M1 と M2 を
/// 分けた理由と同じ / 設計メモ §2-4）。
///
/// ★★ `AppScope` は Navigator より上に置く（本番の `app.dart` と同じ）★★
/// `MaterialApp(home: AppScope(...))` にすると `push` した画面から
/// `AppScope.of` が届かず、**テストだけ通って実機で落ちる**（逆もある）。
/// 器の組み方を本番と揃えておかないと、遷移の不具合をテストが捕まえられない。
///
/// ★★ 起動時の警告の帯も本番と同じ部品を通す（決定 D89）★★
/// `BootGate` は 4 段を走らせるのでここでは通せないが、**帯の組み立ては
/// [BootNoticeHost] 1 か所**なので、そこだけを本番と同じ形で置く。
/// ★ハーネスだけが帯を出す形にしない —— それだと「全ルートで読める」が
/// テストの中だけの性質になる。`BootGate` が実際に置いていることは
/// `test/boot/boot_notice_bar_test.dart` が実物で確かめている。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/card_catalog_repository.dart';
import 'package:loveca_ui/src/data/card_detail.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/app_scope.dart';
import 'package:loveca_ui/src/ui/common/boot_notice_host.dart';

import 'fake_app_settings_store.dart';
import 'fake_card_catalog_repository.dart';
import 'fake_deck_repository.dart';
import 'fake_master_repository.dart';

Future<void> pumpInAppScope(
  WidgetTester tester,
  Widget child, {
  required FakeDeckRepository decks,
  List<BootNotice> notices = const [],
  /// ★画像の経路を確かめたいときだけ差し替える（M5）。既定は dist 不在。
  CardImageSource? imageSource,
  CardCatalogRepository? cardCatalog,
  MasterCatalog? catalog,
  SearchLimitSetting searchLimit = SearchLimitSetting.standard,
  /// ★M6: R6（設定・診断）とバッジが読む材料。
  FakeMasterRepository? master,
  FakeAppSettingsStore? settingsStore,
  AppSettings settings = AppSettings.defaults,
  DistSource distSource = DistSource.environment,
  List<String> searchedPaths = const [r'C:\dist'],
}) async {
  // ★本番と同じく、カタログから 1 回だけ組んで配る（決定 D55 / M5）。
  final resolved = catalog ?? fakeCatalog();
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, navigator) => AppScope(
        environment: AppEnvironment(
          catalog: resolved,
          imageSource: imageSource ?? const LocalDirectoryCardImageSource(null),
          decks: decks,
          cardCatalog: cardCatalog ?? FakeCardCatalogRepository(),
          cardDetail: CardDetailView(resolved),
          searchLimit: searchLimit,
          clock: fakeNow,
          master: master ?? FakeMasterRepository(),
          settingsStore: settingsStore ?? FakeAppSettingsStore(settings),
          appVersion: '1.0.0',
          importOutcome: MasterImportOutcome(
            distMissing: false,
            location: DistLocation(
              directory: null,
              searched: [
                for (final path in searchedPaths)
                  DistCandidate(source: distSource, path: path),
              ],
              source: distSource,
            ),
            appVersion: '1.0.0',
            settings: settings,
            remoteMinAppVersion: '1.0.0',
            remoteDataVersion: 2,
            result: const MasterImportResult(
              decision: UpdateDecision.upToDate,
              dataVersion: 2,
              dataVersionAdvanced: false,
            ),
          ),
        ),
        notices: notices,
        timings: const BootTimings(
          sqlite: Duration.zero,
          database: Duration.zero,
          import: Duration.zero,
          catalog: Duration.zero,
        ),
        child: BootNoticeHost(
          notices: notices,
          navigator: navigatorKey,
          child: navigator ?? const SizedBox.shrink(),
        ),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
