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
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:loveca_ui/src/data/search_limit.dart';

import 'fake_card_catalog_repository.dart';
import 'fake_deck_repository.dart';

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
    this.searchLimit = SearchLimitSetting.standard,
    FakeDeckRepository? decks,
    FakeCardCatalogRepository? cardCatalog,
  })  : decks = decks ?? FakeDeckRepository(),
        cardCatalog = cardCatalog ?? FakeCardCatalogRepository();

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

  /// M2。★drift ではなく組み立て済みのリポジトリを配る（決定 D55）。
  final FakeDeckRepository decks;

  /// M3。★同上。
  final FakeCardCatalogRepository cardCatalog;

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
      searchedPaths: searchedPaths,
      appVersion: '0.1.0',
      remoteMinAppVersion: minAppVersion,
      settingsRecoveredFrom: settingsRecoveredFrom,
      result: distMissing
          ? null
          : MasterImportResult(
              decision: decision,
              dataVersion: 2,
              dataVersionAdvanced: decision == UpdateDecision.update,
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
}

/// 起動が通る最小の構成（カードが 1 枚だけある）。
Map<String, Card> oneCard() => const {
      'X-1': Card(cardNumber: 'X-1', name: 'テスト', cardType: CardType.member),
    };
