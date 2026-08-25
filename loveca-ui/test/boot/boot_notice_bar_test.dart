/// 起動時の警告の帯（M-B4 / 決定 D89 / `docs/UI設計メモ.md` §11-3 / §11-6）.
///
/// ★★ 症状の出る画面から原因に辿れること ★★
/// dist が解決できていないときの症状は「**カード画像が 1 枚も出ない**」で、
/// R3 / R4 / R7 で現れる。帯が R2 にしか無いと、そこから原因に辿れない。
/// ★M1 の `notice_bar.dart` の doc が書いた「R4 が暫定のホームだったので
/// 結果的に出ていただけ」と**同じ形の失敗**であり、置き場が 1 ルートに
/// 固定されている限り繰り返す。
///
/// ★★ 「R2 から消えた」と「全画面に出た」を取り違えない ★★
/// 一本化の対象は `BootNotice` を出す **7 経路**（`boot_controller.dart`）で、
/// **1 つも消えないこと**をここで固定する。
/// ★`DeckNotValid`（と、★2026-08-26 に廃止した `MulliganNotImplemented` / D93-4）は
/// `BoardNotice`（盤面の帯）であって
/// `BootNotice` ではなく、R2 の帯には元から出ていない。混ぜない。
///
/// ★★ 2 つの群は見ているものが違う ★★
///
/// | 群 | 何を見るか | 通す経路 |
/// |---|---|---|
/// | 経路 | ★**実物の `BootGate` が帯を置いていること** | `BootGate` + `FakeBootSteps` |
/// | ルート | 画面を移っても読めること | `pumpInAppScope`（本番と同じ `BootNoticeHost`） |
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' show UpdateDecision;
import 'package:loveca_ui/src/boot/boot_gate.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';
import 'package:loveca_ui/src/ui/settings/settings_page.dart';

import '../support/board_fixture.dart';
import '../support/fake_boot_steps.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

final _bar = find.byKey(const ValueKey('boot-notice-bar'));

/// 実物の `BootGate` を通す。★帯を置いているのが本番のコードであることを見る。
Future<void> pumpBootGate(WidgetTester tester, BootSteps steps) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // ★★★ 毎回ツリーを捨ててから組み直す ★★★
  //   同じ型の `MaterialApp` を `pumpWidget` し直すと **要素が使い回され**、
  //   `BootGate` の `initState`（= `BootController.run()`）が**再実行されない。**
  //   → 2 回目以降は 1 回目の notices を見続け、**どの経路も同じ結果になる。**
  //   ★これは D83 の「溢れが RenderObject ごとに 1 回しか報告されない」と同じ型の罠で、
  //   実際にこの検査を書いたその場で踏んだ（決定 D-10）。
  await tester.pumpWidget(const SizedBox.shrink());

  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => BootGate(
        steps: steps,
        navigator: navigator,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('READY')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('★★ 実物の BootGate が帯を置く（決定 D89）★★', () {
    testWidgets('dist 不在で帯が出て、症状と次の一手が読める', (tester) async {
      await pumpBootGate(
        tester,
        FakeBootSteps(
          distMissing: true,
          searchedPaths: const [r'C:\app\data\dist'],
          cards: oneCard(),
        ),
      );

      expect(_bar, findsOneWidget);
      // ★内部語彙 `dist` を出さない。
      expect(find.textContaining('カードデータの置き場所が見つかりません'),
          findsOneWidget);
      // ★★ 症状に触れる（これが無いと「絵が出ない」と結びつかない）★★
      expect(find.textContaining('カード画像は 1 枚も表示されません'), findsOneWidget);
    });

    testWidgets('★対: 警告が無ければ帯が出ない（常に出す実装を潰す）', (tester) async {
      await pumpBootGate(tester, FakeBootSteps(cards: oneCard()));

      expect(_bar, findsNothing);
      expect(find.text('READY'), findsOneWidget, reason: '★前提: 起動は通っている');
    });

    testWidgets('★★ BootNotice の 7 経路が 1 つも消えていない ★★', (tester) async {
      // ★★ 一本化は「R2 から消す」ではない ★★
      //   `boot_controller.dart` が出す 7 経路を 1 つずつ通す。
      final cases = <String, (FakeBootSteps, String)>{
        '検索上限の不正値': (
          FakeBootSteps(
            cards: oneCard(),
            searchLimit: resolveSearchLimit('0'),
          ),
          '解釈できないため既定に戻しました',
        ),
        '検索上限の上書き': (
          FakeBootSteps(
            cards: oneCard(),
            searchLimit: resolveSearchLimit('50'),
          ),
          '検索結果の上限が 50 件に変更されています',
        ),
        '設定ファイルの復旧': (
          FakeBootSteps(
            cards: oneCard(),
            settingsRecoveredFrom: 'JSON が壊れています',
          ),
          '設定ファイルを読めなかったため既定に戻しました',
        ),
        'dist 不在': (
          FakeBootSteps(cards: oneCard(), distMissing: true),
          'カードデータの置き場所が見つかりません',
        ),
        'アプリが古い': (
          FakeBootSteps(
            cards: oneCard(),
            decision: UpdateDecision.appTooOld,
          ),
          'アプリが古いため配信データを取り込めませんでした',
        ),
        '取り込めなかったファイル': (
          FakeBootSteps(
            cards: oneCard(),
            failedPaths: const ['cards/bp1.json'],
            unhandledPaths: const ['cards/unknown.json'],
          ),
          '件の商品ファイルを取り込めませんでした',
        ),
        'データ版据え置き': (
          FakeBootSteps(
            cards: oneCard(),
            failedPaths: const ['cards/bp1.json'],
            dataVersionAdvanced: false,
          ),
          'データ版は据え置きです',
        ),
      };

      for (final entry in cases.entries) {
        final (steps, expected) = entry.value;
        await pumpBootGate(tester, steps);

        expect(_bar, findsOneWidget, reason: '★${entry.key}');
        expect(find.textContaining(expected), findsOneWidget,
            reason: '★${entry.key} の経路が消えている（決定 D89）');
      }

      // ★★ 前提: 未対応ファイルの経路も別に出る（1 経路にまとめられていない）★★
      await pumpBootGate(
        tester,
        FakeBootSteps(
          cards: oneCard(),
          unhandledPaths: const ['cards/unknown.json'],
        ),
      );
      expect(find.textContaining('件の未対応ファイルがありました'), findsOneWidget);
    });

    testWidgets('★★ 「詳細」から R6（設定・診断）へ飛べる ★★', (tester) async {
      // ★帯は Navigator の**上**にあるので、鍵で辿れていないとここで落ちる。
      await pumpBootGate(
        tester,
        FakeBootSteps(
          distMissing: true,
          searchedPaths: const [r'C:\app\data\dist'],
          cards: oneCard(),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('boot-notice-details')));
      await tester.pumpAndSettle();

      // ★探した場所を省かない（決定 D60）。
      expect(find.textContaining(r'C:\app\data\dist'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('open-settings-from-notice')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      // ★帯は R6 の上にも出たままである。
      expect(_bar, findsOneWidget);
    });
  });

  group('★★ どのルートからでも読める（R2 / R3 / R4 / R7）★★', () {
    const notices = [
      BootNotice('カードデータの置き場所が見つかりません。カード画像は 1 枚も表示されません'),
    ];

    Future<void> openHome(WidgetTester tester,
        {List<BootNotice> given = notices}) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        const DeckListPage(),
        decks: FakeDeckRepository(
          catalog: realShapedCatalog(),
          decks: [boardFixtureDeck()],
        ),
        catalog: realShapedCatalog(),
        notices: given,
      );
    }

    testWidgets('R2（ホーム）', (tester) async {
      await openHome(tester);
      expect(_bar, findsOneWidget);
    });

    testWidgets('R4（カード閲覧）', (tester) async {
      await openHome(tester);
      await tester.tap(find.byTooltip('カードを見る'));
      await tester.pumpAndSettle();

      expect(_bar, findsOneWidget,
          reason: '★M1 の「R4 だったから結果的に出ていた」の逆を確かめている');
    });

    testWidgets('R3（デッキ編集）', (tester) async {
      await openHome(tester);
      await tester.tap(find.text('盤面テスト'));
      await tester.pumpAndSettle();

      expect(_bar, findsOneWidget);
    });

    testWidgets('R7（盤面）', (tester) async {
      await openHome(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ソロ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();
      // ★6.2.1.6（決定 D93）。ソロは 1 段。★0 枚で通す。
      await tester.tap(find.byKey(const ValueKey('mulligan-done')));
      await tester.pumpAndSettle();

      expect(_bar, findsOneWidget,
          reason: '★症状（絵が出ない）が最も目立つ画面である');
    });

    testWidgets('★対: 警告が無ければどのルートでも出ない', (tester) async {
      // ★これが無いと「常に出す実装」でも上の 4 件は通る。
      await openHome(tester, given: const []);
      expect(_bar, findsNothing);

      await tester.tap(find.byTooltip('カードを見る'));
      await tester.pumpAndSettle();
      expect(_bar, findsNothing);
    });

    testWidgets('★★ R2 に二重に出ていない（一本化の確認）★★', (tester) async {
      // ★★ 「R2 だけに出ていたものを全画面に出す」であって、足したのではない ★★
      await openHome(tester);
      expect(_bar, findsOneWidget);
    });
  });
}
