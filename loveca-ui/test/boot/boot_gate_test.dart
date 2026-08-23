/// 起動ゲートの 4 段（`docs/UI設計メモ.md` §3-5(3) / 決定 D60）.
///
/// ★★ 失敗が「どの段で起きたか」区別して表示されることを固定する ★★
/// 段 2（DB を開く + 移行）と段 3（取り込み）を混ぜると
/// 「デッキが読めない」と「カードが古い」が区別できず、
/// 続行できる状態でも利用者が「壊れた」と誤解する。
///
/// ★実 DB を使わない。`BootSteps` を差し替えて段だけを試す。
library;

// ★`Card` は loveca_core（ルール上のカード）と Material（ウィジェット）で衝突する。
//   ここで要るのは前者なので、Material 側を隠す。
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/boot/boot_gate.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/master_repository.dart';

/// 指定した段で投げる差し替え可能な段。
class _FakeSteps implements BootSteps {
  _FakeSteps({
    this.failAt,
    this.error,
    this.distMissing = false,
    this.searchedPaths = const [],
    this.cards = const {},
    this.decision = UpdateDecision.update,
    this.minAppVersion = '1.0.0',
  });

  final BootStageId? failAt;
  final Object? error;
  final bool distMissing;
  final List<String> searchedPaths;
  final Map<String, Card> cards;

  /// ★dist はあるが取り込まれない経路（`appTooOld` / `upToDate`）を試すため。
  final UpdateDecision decision;
  final String minAppVersion;

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
}

Future<void> _pump(WidgetTester tester, BootSteps steps) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BootGate(
        steps: steps,
        builder: (_) => const Scaffold(body: Text('READY')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('★段ごとの失敗が区別して表示される', () {
    testWidgets('段1 sqlite', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          failAt: BootStageId.sqlite,
          error: StateError('FTS5 がありません'),
        ),
      );

      expect(find.textContaining(BootStageId.sqlite.label), findsOneWidget);
      expect(find.textContaining('FTS5 がありません'), findsOneWidget);
      // ★ほかの段の名前が出ていないこと。段が混ざると切り分けにならない。
      expect(find.textContaining(BootStageId.database.label), findsNothing);
      expect(find.textContaining(BootStageId.import.label), findsNothing);
      expect(find.textContaining(BootStageId.catalog.label), findsNothing);
      expect(find.text('READY'), findsNothing);
    });

    testWidgets('段2 database', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          failAt: BootStageId.database,
          error: StateError('移行に失敗しました'),
        ),
      );

      expect(find.textContaining(BootStageId.database.label), findsOneWidget);
      expect(find.textContaining('移行に失敗しました'), findsOneWidget);
      expect(find.textContaining(BootStageId.sqlite.label), findsNothing);
      expect(find.textContaining(BootStageId.import.label), findsNothing);
    });

    testWidgets('段3 import', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          failAt: BootStageId.import,
          error: StateError('取り込みに失敗しました'),
        ),
      );

      expect(find.textContaining(BootStageId.import.label), findsOneWidget);
      expect(find.textContaining('取り込みに失敗しました'), findsOneWidget);
      expect(find.textContaining(BootStageId.database.label), findsNothing);
      expect(find.textContaining(BootStageId.catalog.label), findsNothing);
    });

    testWidgets('段4 catalog', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          failAt: BootStageId.catalog,
          error: StateError('カタログを組めませんでした'),
        ),
      );

      expect(find.textContaining(BootStageId.catalog.label), findsOneWidget);
      expect(find.textContaining('カタログを組めませんでした'), findsOneWidget);
      expect(find.textContaining(BootStageId.import.label), findsNothing);
    });
  });

  group('★dist 不在（決定 D60）', () {
    testWidgets('dist 不在 かつ cards が 0 件 なら停止し、探した場所を全部出す',
        (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          distMissing: true,
          searchedPaths: const [
            r'C:\env\dist',
            r'C:\settings\dist',
            r'C:\app\data\dist',
          ],
        ),
      );

      // ★段 4 の失敗として出る。
      expect(find.textContaining(BootStageId.catalog.label), findsOneWidget);
      expect(
        find.textContaining('カードデータ（dist）が見つかりません'),
        findsOneWidget,
      );

      // ★★ どこを見て無かったのかが 3 件とも出ること ★★
      expect(find.text('探した場所'), findsOneWidget);
      expect(find.textContaining(r'C:\env\dist'), findsOneWidget);
      expect(find.textContaining(r'C:\settings\dist'), findsOneWidget);
      expect(find.textContaining(r'C:\app\data\dist'), findsOneWidget);
      expect(find.textContaining('LOVECA_DIST_DIR'), findsOneWidget);

      expect(find.text('READY'), findsNothing);
    });

    testWidgets('dist 不在 でも cards があれば続行する', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          distMissing: true,
          searchedPaths: const [r'C:\app\data\dist'],
          cards: {
            'X-1': const Card(
              cardNumber: 'X-1',
              name: 'テスト',
              cardType: CardType.member,
            ),
          },
        ),
      );

      // ★止めない。前回取り込んだ内容で動く（決定 D39 と同じ考え方）。
      expect(find.text('READY'), findsOneWidget);
      expect(find.textContaining('起動できませんでした'), findsNothing);
    });
  });

  group('★★ カタログが空なら止める（2026-08-24 に一般化）★★', () {
    // ★当初は「dist 不在 かつ 0 件」しか止めていなかった。
    //   実機で dist はあるのに appTooOld で 0 件になり、成功として通った。
    testWidgets('dist はあるが appTooOld で 0 件 → 停止し、実値を出す',
        (tester) async {
      await _pump(
        tester,
        _FakeSteps(decision: UpdateDecision.appTooOld, minAppVersion: '1.0.0'),
      );

      expect(find.textContaining(BootStageId.catalog.label), findsOneWidget);
      expect(
        find.textContaining('アプリが古いため配信データを取り込めませんでした'),
        findsOneWidget,
      );
      // ★★ 実値が出ること。これが無いとどちらを直せばよいか分からない ★★
      expect(find.textContaining('0.1.0'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsOneWidget);
      expect(find.text('READY'), findsNothing);
    });

    testWidgets('dist はあるが upToDate で 0 件 → 停止する', (tester) async {
      await _pump(tester, _FakeSteps(decision: UpdateDecision.upToDate));

      expect(
        find.textContaining('取り込み済みのはずですがカードがありません'),
        findsOneWidget,
      );
      expect(find.text('READY'), findsNothing);
    });

    testWidgets('★appTooOld でも cards があれば続行し、警告を出す', (tester) async {
      await _pump(
        tester,
        _FakeSteps(
          decision: UpdateDecision.appTooOld,
          cards: {
            'X-1': const Card(
              cardNumber: 'X-1',
              name: 'テスト',
              cardType: CardType.member,
            ),
          },
        ),
      );

      // ★止めない。ただし取り込まれなかった事実は必ず出す。
      expect(find.text('READY'), findsOneWidget);
    });
  });

  testWidgets('4 段すべて通れば画面が出る', (tester) async {
    await _pump(
      tester,
      _FakeSteps(
        cards: {
          'X-1': const Card(
            cardNumber: 'X-1',
            name: 'テスト',
            cardType: CardType.member,
          ),
        },
      ),
    );

    expect(find.text('READY'), findsOneWidget);
  });
}
