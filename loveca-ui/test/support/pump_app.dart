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
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/card_catalog_repository.dart';
import 'package:loveca_ui/src/data/card_detail.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/app_scope.dart';

import 'fake_card_catalog_repository.dart';
import 'fake_deck_repository.dart';

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
}) async {
  // ★本番と同じく、カタログから 1 回だけ組んで配る（決定 D55 / M5）。
  final resolved = catalog ?? fakeCatalog();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, navigator) => AppScope(
        environment: AppEnvironment(
          catalog: resolved,
          imageSource: imageSource ?? const LocalDirectoryCardImageSource(null),
          decks: decks,
          cardCatalog: cardCatalog ?? FakeCardCatalogRepository(),
          cardDetail: CardDetailView(resolved),
          searchLimit: searchLimit,
          clock: fakeNow,
        ),
        notices: notices,
        timings: const BootTimings(
          sqlite: Duration.zero,
          database: Duration.zero,
          import: Duration.zero,
          catalog: Duration.zero,
        ),
        child: navigator ?? const SizedBox.shrink(),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
