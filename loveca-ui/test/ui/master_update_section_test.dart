/// ★★ カードデータの更新の節（`docs/Android UI 決定.md` §3-16 の 1 / §1-5 ＝ **W-82** の (e)）★★
///
/// ★★ 呼ぶ側が 1 つも無い（**D-20** を承知で置いた）★★
/// ★**§3-1 の下段タブ「その他」が★1 行も無い**（★走査した / 2026-09-03）。
/// ★★**いつ呼ばれる予定か**★★ —— ★**その「その他」タブが入ったとき**である（★§3-16 が★その中身の一覧である）。
///
/// ★★ 覆っていないもの ★★
/// ★**§2 の穴 2（★編集中のデッキが古いカタログを見続ける）は★★1 ミリも塞いでいない★★**
/// （★★塞いだと読ませないために★ここに書く★★）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/boot/boot_controller.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:loveca_ui/src/ui/settings/master_update_section.dart';

import '../support/strip_comments.dart';

MasterImportOutcome _outcome({
  bool distMissing = false,
  UpdateDecision decision = UpdateDecision.update,
  List<String> failedPaths = const [],
}) =>
    MasterImportOutcome(
      distMissing: distMissing,
      location: const DistLocation(directory: null, searched: []),
      appVersion: '1.0.0',
      settings: const AppSettings(),
      result: distMissing
          ? null
          : MasterImportResult(
              decision: decision,
              dataVersion: 2,
              dataVersionAdvanced: true,
              failedPaths: failedPaths,
            ),
    );

MasterReloadDone _done({
  UpdateDecision decision = UpdateDecision.update,
  List<String> failedPaths = const [],
}) =>
    MasterReloadDone(
      outcome: _outcome(decision: decision, failedPaths: failedPaths),
      notices: const [],
    );

Widget _section({
  MasterUpdateStatus status = MasterUpdateStatus.updateAvailable,
  required Future<MasterReloadResult> Function() onUpdate,
  void Function(List<BootNotice>)? onNotices,
}) =>
    MaterialApp(
      home: Scaffold(
        body: MasterUpdateSection(
          status: status,
          localDataVersion: 1,
          remoteDataVersion: 2,
          onUpdate: onUpdate,
          onNotices: onNotices,
        ),
      ),
    );

void main() {
  group('★★ 状態の判定は 1 か所（**D-15** の規約 3）★★', () {
    test('★ dist が無ければ★★どの版でも★見つからない★★', () {
      expect(
        masterUpdateStatusOf(local: 1, remote: 9, distMissing: true),
        MasterUpdateStatus.distMissing,
      );
    });

    test('★ 配信物のほうが新しければ★更新できる', () {
      expect(
        masterUpdateStatusOf(local: 1, remote: 2, distMissing: false),
        MasterUpdateStatus.updateAvailable,
      );
    });

    test('★★ 対: ★同値でも★古くても★取り込み済みである ★★', () {
      expect(
        masterUpdateStatusOf(local: 2, remote: 2, distMissing: false),
        MasterUpdateStatus.upToDate,
      );
      expect(
        masterUpdateStatusOf(local: 3, remote: 2, distMissing: false),
        MasterUpdateStatus.upToDate,
      );
      // ★配信物の版が読めないときも「取り込み済み」側（★★更新できるとは言わない★★）。
      expect(
        masterUpdateStatusOf(local: 1, remote: null, distMissing: false),
        MasterUpdateStatus.upToDate,
      );
    });
  });

  group('★★ Windows の R6 も★同じ判定を読む（**D-15** の規約 3 の受け）★★', () {
    // ★★ ここが (K) の受けである（**D-27** の (乙)）★★
    //   ★**共有しただけでは★戻されたことに 1 つも気づけない** ——
    //   ★★あちらの字面は **D56** のままなので、★値では区別しようがない★★。
    //   → ★**ソースに★呼び出しが在ることを見る**（★先例は **D-37 の裏** の走査）。
    test('★★ `settings_page.dart` が `masterUpdateStatusOf` を引いている ★★', () {
      final source = stripComments(
        File('lib/src/ui/settings/settings_page.dart').readAsStringSync(),
      );
      expect(source, contains('masterUpdateStatusOf('));
      // ★★ 陽性対照: ★同じ走査が★在らない字面では当たらない ★★
      expect(source, isNot(contains('masterUpdateStatusOfNothing(')));
    });

    test('★★ あちらの字面は **D56** のままである（★共有したのは条件だけ）★★', () {
      final source =
          File('lib/src/ui/settings/settings_page.dart').readAsStringSync();
      expect(source, contains('アプリを起動し直すと取り込みます'));
      // ★★ Windows に更新ボタンを足していない ★★
      expect(source, isNot(contains('カードデータを更新する')));
    });
  });

  group('★★ 完了ダイアログの 1 行（★§2 の穴 3）★★', () {
    test('★ 取り込んだ ＋ 失敗 0 件', () {
      expect(masterUpdateDoneMessage(_done()), '更新しました。');
    });

    test('★★ 取り込んだ ＋ 失敗 1 件 —— ★★件数を出す★★ ★★', () {
      expect(
        masterUpdateDoneMessage(_done(failedPaths: ['cards/BP01.json'])),
        '更新しました。（1 件を取り込めませんでした）',
      );
    });

    test('★★ 1 件も走らなかったときに「更新しました」と言わない ★★', () {
      expect(
        masterUpdateDoneMessage(_done(decision: UpdateDecision.upToDate)),
        '新しいカードデータはありませんでした。',
      );
    });
  });

  group('★★ 画面（★§3-16 の 4 つ）★★', () {
    testWidgets('★ 1. 状態を出す', (tester) async {
      await tester.pumpWidget(_section(onUpdate: () async => _done()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('masterUpdate:status')), findsOneWidget);
      expect(find.textContaining('新しいカードデータがあります'), findsOneWidget);
    });

    testWidgets('★★ 状態は渡された値で変わる（★★常に同じ字面ではない★★）★★', (tester) async {
      await tester.pumpWidget(_section(
        status: MasterUpdateStatus.upToDate,
        onUpdate: () async => _done(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('取り込み済みです。'), findsOneWidget);
    });

    testWidgets('★ 2. 押すと★取り込みを走らせる', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_section(onUpdate: () async {
        calls++;
        return _done();
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });

    testWidgets('★★ 3. 走っているあいだは★進捗が出て★押せない ★★', (tester) async {
      final gate = Completer<MasterReloadResult>();
      await tester.pumpWidget(_section(onUpdate: () => gate.future));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('masterUpdate:progress')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pump();

      expect(find.byKey(const ValueKey('masterUpdate:progress')), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('masterUpdate:button')),
      );
      expect(button.onPressed, isNull);

      gate.complete(_done());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('masterUpdate:progress')), findsNothing);
    });

    testWidgets('★★ 走っているあいだに 2 度目を押しても 1 回しか走らない ★★',
        (tester) async {
      var calls = 0;
      final gate = Completer<MasterReloadResult>();
      await tester.pumpWidget(_section(onUpdate: () {
        calls++;
        return gate.future;
      }));
      await tester.pumpAndSettle();

      // ★★ フレームを挟まずに 2 度叩く ★★
      //   ★**あいだに `pump` を入れると★ボタンが無効になり、★2 度目が★★届かない★★** ——
      //   ★★それでは `_running` の門に 1 度も当たらない★★（★実測 0 件 / 2026-09-03 / **D-27** の (a)）。
      //   ★**実機でも★同じフレームのうちに 2 度届きうる**（★再構築は次のフレームである）。
      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pump();

      expect(calls, 1);
      gate.complete(_done());
      await tester.pumpAndSettle();
    });

    testWidgets('★ 4. 終わると★完了ダイアログが出る', (tester) async {
      await tester.pumpWidget(_section(onUpdate: () async => _done()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('masterUpdate:dialog')), findsOneWidget);
      expect(find.text('更新しました。'), findsOneWidget);
    });

    testWidgets('★★ 失敗と「走らせなかった」を畳まない ★★', (tester) async {
      await tester.pumpWidget(_section(
        onUpdate: () async =>
            MasterReloadFailed(error: 'x', stackTrace: StackTrace.empty),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();
      final failed = tester
          .widget<Text>(find.byKey(const ValueKey('masterUpdate:dialogText')))
          .data;

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
          _section(onUpdate: () async => const MasterReloadRefused()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();
      final refused = tester
          .widget<Text>(find.byKey(const ValueKey('masterUpdate:dialogText')))
          .data;

      // ★★ 別の字面である —— ★畳むと「データが壊れている」と読める ★★
      expect(refused, isNot(failed));
      expect(failed, contains('前回取り込んだ内容で動いています'));
    });

    testWidgets('★★ Notice は呼ぶ側へ回す（★★このなかにバーを持たない★★ / §2 の穴 3）★★',
        (tester) async {
      List<BootNotice>? got;
      await tester.pumpWidget(_section(
        onUpdate: () async => MasterReloadDone(
          outcome: _outcome(),
          notices: const [
            BootNotice('取り込めなかったファイルがあります'),
          ],
        ),
        onNotices: (notices) => got = notices,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();

      expect(got, isNotNull);
      expect(got!.length, 1);
      // ★★ バーそのものは 1 つも出さない ★★
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('★★ 失敗しても Notice を回さない（★★答えが違う★★）★★', (tester) async {
      var called = false;
      await tester.pumpWidget(_section(
        onUpdate: () async =>
            MasterReloadFailed(error: 'x', stackTrace: StackTrace.empty),
        onNotices: (_) => called = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('masterUpdate:button')));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });
  });
}
