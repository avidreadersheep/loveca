/// R6 設定・診断（`docs/UI設計メモ.md` §2-2 / 決定 D39 / D60 / D64 / D56）.
///
/// ★★ 出る側と出ない側を対で固定する ★★
/// 「取り込み失敗が出る」だけを見ると、**常に出す実装**でも通ってしまう。
/// 「上限の上書きが出る」だけを見ると、**常設している実装**でも通ってしまう。
///
/// ★役割を混ぜない。取り込み失敗が**実際に起きる**ことは
/// `test/data/import_issue_test.dart` が実 DB で固定している。
/// ここで見るのは**画面がそれをどう出すか**だけである。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:loveca_ui/src/data/import_issue.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';
import 'package:loveca_ui/src/ui/settings/settings_page.dart';

import '../support/fake_app_settings_store.dart';
import '../support/fake_deck_repository.dart';
import '../support/fake_master_repository.dart';
import '../support/pump_app.dart';

final _t0 = DateTime.utc(2026, 8, 24, 12);

ImportIssue _issue({
  String path = 'cards/BP01.json',
  String hash = 'sha256:broken',
  String? currentHash,
  ImportIssueKind kind = ImportIssueKind.unknownKey,
  int occurrenceCount = 1,
}) =>
    ImportIssue(
      path: path,
      hash: hash,
      kind: kind,
      message: 'Invalid argument(s): unknown heart color: CYAN',
      occurrenceCount: occurrenceCount,
      firstSeenAt: _t0,
      lastSeenAt: _t0,
      currentHash: currentHash,
    );

/// ★★ R6 は `ListView` なので下のほうは「まだ作られていない」★★
/// `find` に出ないのは「無い」のではなく「まだ作っていない」。
/// 混同すると「出ないこと」のテストが**常に通る**（D-10 と同じ形 / M5 §9-9）。
/// 押す前に**送ってから**でないと叩けない。
/// ★`ensureVisible` では足りない。あれは「作られてはいるが見えていない」用で、
/// まだ作られていない要素には `No element` で落ちる。
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: _scrollable());
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// ★`.first` を付ける。`SelectableText`（`EditableText`）も `Scrollable` を持つので、
/// 絞らないと 'Too many elements' になる。外側の `ListView` が先に見つかる。
Finder _scrollable() => find
    .descendant(
      of: find.byType(SettingsPage),
      matching: find.byType(Scrollable),
    )
    .first;

/// 「出ない側」を見るときに使う。
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = _scrollable();
  await tester.drag(scrollable, const Offset(0, -4000));
  await tester.pumpAndSettle();
  await tester.drag(scrollable, const Offset(0, -4000));
  await tester.pumpAndSettle();
}

Future<FakeMasterRepository> _open(
  WidgetTester tester, {
  FakeMasterRepository? master,
  FakeAppSettingsStore? settingsStore,
  AppSettings settings = AppSettings.defaults,
  SearchLimitSetting searchLimit = SearchLimitSetting.standard,
  DistSource distSource = DistSource.environment,
  List<String> searchedPaths = const [r'C:\dist'],
}) async {
  final resolved = master ?? FakeMasterRepository();
  await pumpInAppScope(
    tester,
    const SettingsPage(),
    decks: FakeDeckRepository(),
    master: resolved,
    settingsStore: settingsStore,
    settings: settings,
    searchLimit: searchLimit,
    distSource: distSource,
    searchedPaths: searchedPaths,
  );
  return resolved;
}

void main() {
  group('★ dist をどの段で解決したか（決定 D60）', () {
    test('段の名前は 3 つとも別（前提）', () {
      final labels = {for (final s in DistSource.values) s.label};
      expect(labels, hasLength(3), reason: '同じ文言だと画面で区別できない');
    });

    testWidgets('段1（環境変数）で解決したと読める', (tester) async {
      await _open(tester, distSource: DistSource.environment);
      expect(find.text('環境変数 LOVECA_DIST_DIR'), findsWidgets);
    });

    testWidgets('段2（設定）で解決したと読める', (tester) async {
      await _open(tester, distSource: DistSource.settings);
      expect(find.text('設定（settings.json の distDir）'), findsWidgets);
    });

    testWidgets('段3（実行ファイルの隣）で解決したと読める', (tester) async {
      await _open(tester, distSource: DistSource.bundled);
      expect(find.text('実行ファイルの隣の data/dist'), findsWidgets);
    });

    testWidgets('★探した場所を全部出す', (tester) async {
      await _open(tester, searchedPaths: [r'C:\one', r'C:\two']);
      expect(find.text(r'C:\one'), findsOneWidget);
      expect(find.text(r'C:\two'), findsOneWidget);
    });
  });

  group('★★ 取り込み失敗の出口（決定 D39）★★', () {
    testWidgets('★1 件あれば path と回数が読める', (tester) async {
      await _open(
        tester,
        master: FakeMasterRepository(
          issues: [_issue(occurrenceCount: 3)],
        ),
      );
      await _scrollToEnd(tester);

      expect(find.textContaining('1 件のファイルを取り込めませんでした'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('importIssue:cards/BP01.json')),
          findsOneWidget);
      expect(find.textContaining('3 回'), findsOneWidget);
      // ★内部語彙を出さない。対処が分かる言葉にする。
      expect(find.text('このアプリが知らない値が入っていました'), findsOneWidget);
    });

    testWidgets('★★ 0 件なら一覧を出さず「ありません」と言う（出ない側）★★',
        (tester) async {
      await _open(tester, master: FakeMasterRepository());
      await _scrollToEnd(tester);

      expect(find.text('取り込めなかったファイルはありません'), findsOneWidget);
      expect(find.textContaining('件のファイルを取り込めませんでした'), findsNothing,
          reason: '出る側だけ見ると、常に出す実装でも通ってしまう');
      expect(find.byKey(const ValueKey('importIssue:cards/BP01.json')),
          findsNothing);
    });

    testWidgets('★★ 「そのあと取り込めています」はもう出ない（D-13 の根治）★★',
        (tester) async {
      // ★★ 2026-08-27: 当座の手当てを撤去した ★★
      //   `MasterStateDao.recordFile` が同じ path の過去の失敗を消すので、
      //   **ここに並ぶのは「いま読めていないファイル」だけ**になった。
      //   ★残しておくと逆に嘘をつく —— `currentHash != hash` になるのは
      //     「**古い**版が取り込まれていて**新しい**版で失敗した」ときで、
      //     「新しい版で取り込めています」は向きが逆である。
      await _open(
        tester,
        master: FakeMasterRepository(
          issues: [_issue(currentHash: 'sha256:other')],
        ),
      );
      await _scrollToEnd(tester);

      expect(find.textContaining('そのあと別の版で取り込めています'), findsNothing);
      // ★対: 記録そのものは出ている（節ごと壊していないこと）。
      expect(find.byKey(const ValueKey('importIssue:cards/BP01.json')),
          findsOneWidget);
      // ★現在ハッシュは手がかりとして残す。
      //   ★「詳しい内容」は畳んである（内部語彙を最初から見せない）ので、
      //     **開かないと出ない**。開かずに見ると常に通る検査になる。
      await tester.tap(find.text('詳しい内容'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sha256:other'), findsOneWidget);
    });

    testWidgets('★読めなければエラーを出す。0 件にすり替えない（決定 D53）',
        (tester) async {
      await _open(
        tester,
        master: FakeMasterRepository(failIssues: StateError('DB が閉じている')),
      );
      await _scrollToEnd(tester);

      expect(find.text('取り込めなかったファイルはありません'), findsNothing,
          reason: '「読めなかった」を「無い」と同じ見た目にしない');
      expect(find.textContaining('DB が閉じている'), findsOneWidget);
    });
  });

  group('★★ 検索上限の上書き（決定 D64）★★', () {
    testWidgets('★上書きされていれば実値つきで出る', (tester) async {
      await _open(tester, searchLimit: resolveSearchLimit('50'));
      await _scrollToEnd(tester);

      expect(find.text('検索結果の上限（検証用）'), findsOneWidget);
      expect(find.text('50 件'), findsOneWidget);
      expect(find.textContaining('本番の設定経路ではありません'), findsOneWidget);
    });

    testWidgets('★★ 上書きが無ければ節ごと出さない（出ない側）★★', (tester) async {
      await _open(tester);
      await _scrollToEnd(tester);

      expect(find.text('検索結果の上限（検証用）'), findsNothing,
          reason: '常設すると、検証用の口が本番の設定に見える');
    });
  });

  group('★ 設定の書き込み（M6 が AppSettingsStore.save の最初の呼び出し元）', () {
    testWidgets('パラレル表示の既定を切り替えると保存される', (tester) async {
      final store = FakeAppSettingsStore(const AppSettings());
      await _open(tester, settingsStore: store);

      await _tap(tester, find.byKey(const Key('showParallelSwitch')));

      expect(store.saved, hasLength(1));
      expect(store.saved.single.showParallel, isFalse);
    });

    testWidgets('★保存しても「いま効いた」とは言わない（決定 D56）', (tester) async {
      await _open(tester, settingsStore: FakeAppSettingsStore());

      await _tap(tester, find.byKey(const Key('showParallelSwitch')));

      expect(find.textContaining('反映されるのは次の起動から'), findsOneWidget,
          reason: '取り込みも dist の解決も起動ゲートでしか走らない');
    });

    testWidgets('★保存していなければ再起動の案内は出ない（上の対）', (tester) async {
      await _open(tester);
      expect(find.textContaining('反映されるのは次の起動から'), findsNothing);
    });

    /// ★★ 再起動が要るかは項目ごとに違う（`ルール整合性チェック_v1.06.md` D-23）★★
    ///
    /// かつては**どの項目でも**無条件に「次の起動から」と言っていた。
    /// 既存 2 項目がどちらも再起動を要したので**偶然に正しかった**だけで、
    /// 即時に効く項目を足した瞬間に嘘になる。
    group('★★ 補完に使うエネルギーカード（決定 D97 / D-23）★★', () {
      testWidgets('★★ 選び直しても「次の起動から」と言わない ★★', (tester) async {
        final store = FakeAppSettingsStore(const AppSettings());
        await _open(tester, settingsStore: store);

        await _tap(tester, find.byKey(const Key('energyFillPickSetting')));
        // ★ピッカから 1 枚選ぶ（fixture のエネルギーは 1 種）。
        await _tap(tester, find.byKey(const ValueKey('energyFill:E-1-N')));

        expect(store.saved, hasLength(1));
        expect(store.saved.single.energyFillPrintingId, 'E-1-N');
        // ★★ ここが D-23 の要点 ★★
        expect(find.textContaining('反映されるのは次の起動から'), findsNothing,
            reason: '★補完の 1 回にしか効かないので、再起動は要らない');
        expect(find.textContaining('次に盤面を始めるときから効きます'), findsOneWidget);
      });

      testWidgets('★★ 対: dist を保存したときは「次の起動から」と言う ★★',
          (tester) async {
        // ★片方だけ見ると、常に「要らない」と言う実装でも通ってしまう。
        await _open(tester, settingsStore: FakeAppSettingsStore());

        await tester.enterText(
            find.byKey(const Key('distDirField')), r'C:\dist');
        await _tap(tester, find.text('この場所を保存する'));

        expect(find.textContaining('反映されるのは次の起動から'), findsOneWidget);
      });

      testWidgets('★「補完しない」を選べる（片道にしない）', (tester) async {
        final store = FakeAppSettingsStore(
          const AppSettings(energyFillPrintingId: 'E-1-N'),
        );
        await _open(
          tester,
          settingsStore: store,
          settings: const AppSettings(energyFillPrintingId: 'E-1-N'),
        );

        await _tap(tester, find.byKey(const Key('energyFillPickSetting')));
        await _tap(tester, find.byKey(const ValueKey('energyFillNone')));

        expect(store.saved.single.energyFillPrintingId, isNull);
      });

      testWidgets('★やめたら何も保存しない（null と「補完しない」は別物）',
          (tester) async {
        final store = FakeAppSettingsStore(const AppSettings());
        await _open(tester, settingsStore: store);

        await _tap(tester, find.byKey(const Key('energyFillPickSetting')));
        await _tap(tester, find.widgetWithText(TextButton, 'やめる'));

        expect(store.saved, isEmpty);
      });

      testWidgets('★★ 開いた時点の値を読み直す（起動時のスナップショットを出さない）★★',
          (tester) async {
        // ★★ 実機で見つけた（2026-08-26）★★
        //   補完のカードは盤面の開始ダイアログでも変えられるので、
        //   `env.settings` のまま出すと**前の刷りが「いま補うカード」として出る。**
        //   ★`settings`（起動時）と `settingsStore`（いま）を**わざと食い違わせる。**
        await _open(
          tester,
          settings: const AppSettings(energyFillPrintingId: 'E-1-N'),
          settingsStore: FakeAppSettingsStore(
            const AppSettings(energyFillPrintingId: 'E-1-ZZZ'),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('energyFillPickSetting')),
          120,
          scrollable: _scrollable(),
        );
        await tester.pumpAndSettle();

        // ★store の値（いま）が出ること。★env.settings（起動時）ではない。
        expect(find.textContaining('選ばれている刷りがありません'), findsOneWidget,
            reason: '★起動時のスナップショットを出していると、これは出ない');
      });

      testWidgets('★★ 引けない刷りは理由を撃ち分けて出す（決定 D97-5）★★',
          (tester) async {
        // ★cardNumber ごと無い側。
        await _open(
          tester,
          settings: const AppSettings(energyFillPrintingId: 'GHOST-9-9-X'),
        );

        // ★★ ListView は画面外を作らない ★★
        //   スクロールせずに見ると、出ていても findsNothing になる（M5 の教訓）。
        await tester.scrollUntilVisible(
          find.byKey(const Key('energyFillPickSetting')),
          120,
          scrollable: _scrollable(),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('がカードデータにありません'), findsOneWidget);
      });

      testWidgets('★対: cardNumber は在るが刷りだけ無い側は文面が違う', (tester) async {
        await _open(
          tester,
          settings: const AppSettings(energyFillPrintingId: 'E-1-ZZZ'),
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('energyFillPickSetting')),
          120,
          scrollable: _scrollable(),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('選ばれている刷りがありません'), findsOneWidget);
        expect(find.textContaining('がカードデータにありません'), findsNothing);
      });
    });

    testWidgets('★dist のパスを空にすると設定から消える（片道にしない）',
        (tester) async {
      final store = FakeAppSettingsStore(const AppSettings(distDir: r'C:\old'));
      await _open(
        tester,
        settingsStore: store,
        settings: const AppSettings(distDir: r'C:\old'),
      );

      await tester.scrollUntilVisible(
          find.byKey(const Key('distDirField')), 120,
          scrollable: _scrollable());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('distDirField')), '   ');
      await _tap(tester, find.text('この場所を保存する'));

      expect(store.saved.single.distDir, isNull);
    });

    testWidgets('★パスを入れると設定に入る（上の対）', (tester) async {
      final store = FakeAppSettingsStore();
      await _open(tester, settingsStore: store);

      await tester.scrollUntilVisible(
          find.byKey(const Key('distDirField')), 120,
          scrollable: _scrollable());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('distDirField')), r'C:\new');
      await _tap(tester, find.text('この場所を保存する'));

      expect(store.saved.single.distDir, r'C:\new');
    });
  });

  group('★ 「データを更新」は再起動を伴う操作（決定 D56）', () {
    testWidgets('★「いま取り込む」ボタンを置かない', (tester) async {
      await _open(tester);
      expect(find.textContaining('いま取り込む'), findsNothing);
      expect(find.text('アプリを終了する'), findsOneWidget);
    });

    testWidgets('終了は確認を 1 枚挟む', (tester) async {
      await _open(tester);

      await _tap(tester, find.text('アプリを終了する'));

      expect(find.text('アプリを終了しますか'), findsOneWidget);
      expect(find.textContaining('取り込みは起動のときだけ'), findsWidgets);

      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();
      expect(find.text('アプリを終了しますか'), findsNothing);
    });
  });

  group('★ R2 のバッジ（§2-3 の P2）', () {
    testWidgets('★件数が 0 ならバッジを出さない（出ない側）', (tester) async {
      final master = FakeMasterRepository();
      await pumpInAppScope(
        tester,
        const DeckListPage(),
        decks: FakeDeckRepository(),
        master: master,
      );
      master.issueCount.add(0);
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing,
          reason: '常に丸が付いていると、何も言っていないのと同じになる');
      expect(find.byTooltip('設定・診断'), findsOneWidget);
    });

    testWidgets('★件数が 1 以上ならバッジが出る', (tester) async {
      final master = FakeMasterRepository();
      await pumpInAppScope(
        tester,
        const DeckListPage(),
        decks: FakeDeckRepository(),
        master: master,
      );
      master.issueCount.add(2);
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('設定アイコンから R6 へ行ける', (tester) async {
      await pumpInAppScope(
        tester,
        const DeckListPage(),
        decks: FakeDeckRepository(),
      );

      await tester.tap(find.byTooltip('設定・診断'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('設定・診断'), findsWidgets);
    });
  });
}
