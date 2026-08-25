/// 起動ゲートの 4 段の差し替え（テスト用）.
///
/// ★実 DB を使わない。「どの段で失敗したか」を固定したいだけなのに
/// ネイティブ sqlite3 とファイル I/O が要る、という本末転倒を避けるため
/// （`boot_steps.dart` の `BootSteps` の doc）。
///
/// ★M2 で `boot/boot_gate_test.dart` から出した。R2 をホームにしたので
/// `app_home_test.dart` からも同じものが要る。2 つに写すと片方だけ腐る。
library;

// ★`Card` は loveca_core（ルール上のカード）と Material（ウィジェット）で衝突する。
//   ここで要るのは前者。
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/card_catalog_repository.dart';
import 'package:loveca_ui/src/data/app_paths.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:loveca_ui/src/data/search_limit.dart';

import 'fake_app_settings_store.dart';
import 'fake_card_catalog_repository.dart';
import 'fake_deck_repository.dart';
import 'fake_master_repository.dart';

/// 指定した段で投げる差し替え可能な段。
class FakeBootSteps implements BootSteps {
  FakeBootSteps({
    this.failAt,
    this.error,
    this.distMissing = false,
    this.searchedPaths = const [],
    this.cards = const {},
    this.decision = UpdateDecision.update,
    this.minAppVersion = '1.0.0',
    this.settingsRecoveredFrom,
    this.failedPaths = const [],
    this.unhandledPaths = const [],
    this.dataVersionAdvanced,
    this.searchLimit = SearchLimitSetting.standard,
    this.distSource = DistSource.environment,
    this.settings = AppSettings.defaults,
    FakeDeckRepository? decks,
    FakeCardCatalogRepository? cardCatalog,
    FakeMasterRepository? master,
    FakeAppSettingsStore? settingsStore,
  })  : decks = decks ?? FakeDeckRepository(),
        cardCatalog = cardCatalog ?? FakeCardCatalogRepository(),
        master = master ?? FakeMasterRepository(),
        settingsStore = settingsStore ?? FakeAppSettingsStore(settings);

  final BootStageId? failAt;
  final Object? error;
  final bool distMissing;
  final List<String> searchedPaths;
  final Map<String, Card> cards;

  /// ★dist はあるが取り込まれない経路（`appTooOld` / `upToDate`）を試すため。
  final UpdateDecision decision;
  final String minAppVersion;

  /// ★設定ファイルが壊れて既定に戻った経路（設計メモ §4-6(5)）。
  final Object? settingsRecoveredFrom;

  /// ★取り込めなかった商品ファイル（決定 D39）。
  final List<String> failedPaths;

  /// ★未対応のファイル（同上）。
  final List<String> unhandledPaths;

  /// ★データ版が進んだか。null なら decision から導く。
  ///   **失敗があって進まなかった**経路（据え置きの警告）を作るために要る。
  final bool? dataVersionAdvanced;

  /// M2。★drift ではなく組み立て済みのリポジトリを配る（決定 D55）。
  final FakeDeckRepository decks;

  /// M3。★同上。
  final FakeCardCatalogRepository cardCatalog;

  /// M6。★`import_issues` の出口（決定 D39）。
  final FakeMasterRepository master;

  /// M6。★R6 が設定を書く先。
  final FakeAppSettingsStore settingsStore;

  /// M6。★dist をどの段で掴んだか（決定 D60）。
  final DistSource distSource;

  /// M6。★このセッションで効いている設定。
  final AppSettings settings;

  /// 検索結果の上限（決定 D50 / D64）。★上書き・不正値の経路を試すため。
  @override
  final SearchLimitSetting searchLimit;

  void _maybeFail(BootStageId stage) {
    if (failAt == stage) throw error ?? StateError('${stage.name} で失敗');
  }

  @override
  Future<void> checkSqlite() async => _maybeFail(BootStageId.sqlite);

  @override
  Future<void> openDatabase() async => _maybeFail(BootStageId.database);

  @override
  Future<MasterImportOutcome> importMaster() async {
    _maybeFail(BootStageId.import);
    return MasterImportOutcome(
      distMissing: distMissing,
      location: DistLocation(
        directory: null,
        searched: [
          for (final path in searchedPaths)
            DistCandidate(source: distSource, path: path),
        ],
        source: distMissing ? null : distSource,
      ),
      appVersion: '0.1.0',
      settings: settings,
      remoteMinAppVersion: minAppVersion,
      remoteDataVersion: 2,
      settingsRecoveredFrom: settingsRecoveredFrom,
      result: distMissing
          ? null
          : MasterImportResult(
              decision: decision,
              dataVersion: 2,
              dataVersionAdvanced:
                  dataVersionAdvanced ?? decision == UpdateDecision.update,
              failedPaths: failedPaths,
              unhandledPaths: unhandledPaths,
            ),
    );
  }

  @override
  Future<MasterCatalog> loadCatalog(MasterImportOutcome importOutcome) async {
    _maybeFail(BootStageId.catalog);
    // ★本番と同じ判断: カタログが空なら理由を添えて止める（設計メモ §4-6(4)）。
    if (cards.isEmpty) throw emptyCatalogFailure(importOutcome);
    return MasterCatalog(
      cards: cards,
      printings: const {},
      config: RuleConfig.standard,
      rows: const [],
      dataVersion: 1,
    );
  }

  @override
  CardImageSource imageSourceFor(MasterImportOutcome importOutcome) =>
      const LocalDirectoryCardImageSource(null);

  @override
  DeckRepository decksFor(MasterCatalog catalog) => decks;

  @override
  CardCatalogRepository cardCatalogFor() => cardCatalog;

  @override
  MasterRepository masterFor() => master;

  @override
  AppSettingsStore settingsStoreFor() => settingsStore;

  @override
  AppPaths? get paths => null;
}

/// 起動が通る最小の構成（カードが 1 枚だけある）。
Map<String, Card> oneCard() => const {
      'X-1': Card(cardNumber: 'X-1', name: 'テスト', cardType: CardType.member),
    };
