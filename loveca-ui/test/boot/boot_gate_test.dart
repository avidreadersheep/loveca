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
import 'package:loveca_ui/src/boot/boot_gate.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/state/app_scope.dart';

// ★段の差し替えは test/support/ に出してある（app_home_test.dart と共有する）。
import '../support/fake_boot_steps.dart';

/// ★起動後の画面は `AppScope` の Notice を描く。
///
/// ★★ 「Notice が作られたこと」ではなく「画面まで届くこと」を見る ★★
/// 作られただけで誰も読まない状態を通してしまうのは、
/// このタスクで潰している D-6 とまったく同じ型の穴である。
Future<void> _pump(WidgetTester tester, BootSteps steps) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BootGate(
        steps: steps,
        // ★AppScope は BootGate が内側に置く。Builder で読み直す。
        child: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('READY'),
                for (final notice in AppScope.of(context).notices)
                  Text(notice.message),
              ],
            ),
          ),
        ),
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
        FakeBootSteps(
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
        FakeBootSteps(
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
        FakeBootSteps(
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
        FakeBootSteps(
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
        FakeBootSteps(
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
        FakeBootSteps(
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
      // ★更新できなかった事実は画面に出す。
      expect(
        find.text('カードデータを更新できませんでした（前回取り込んだ内容で動いています）'),
        findsOneWidget,
      );
    });
  });

  group('★★ カタログが空なら止める（2026-08-24 に一般化）★★', () {
    // ★当初は「dist 不在 かつ 0 件」しか止めていなかった。
    //   実機で dist はあるのに appTooOld で 0 件になり、成功として通った。
    testWidgets('dist はあるが appTooOld で 0 件 → 停止し、実値を出す',
        (tester) async {
      await _pump(
        tester,
        FakeBootSteps(decision: UpdateDecision.appTooOld, minAppVersion: '1.0.0'),
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
      await _pump(tester, FakeBootSteps(decision: UpdateDecision.upToDate));

      expect(
        find.textContaining('取り込み済みのはずですがカードがありません'),
        findsOneWidget,
      );
      expect(find.text('READY'), findsNothing);
    });

    testWidgets('★appTooOld でも cards があれば続行し、警告を出す', (tester) async {
      await _pump(
        tester,
        FakeBootSteps(
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
      expect(
        find.text('アプリが古いため配信データを取り込めませんでした'),
        findsOneWidget,
      );
    });
  });

  testWidgets('★設定ファイルが壊れていたら警告が出る（設計メモ §4-6(5)）',
      (tester) async {
    // ★黙って既定に戻すと「設定したのに効かない」が原因不明のまま残る。
    //   M1 では recoveredFrom を作っただけで誰も読んでいなかった。
    await _pump(
      tester,
      FakeBootSteps(
        settingsRecoveredFrom: const FormatException('壊れた JSON'),
        cards: {
          'X-1': const Card(
            cardNumber: 'X-1',
            name: 'テスト',
            cardType: CardType.member,
          ),
        },
      ),
    );

    // 起動は続く（設定は既定に戻せば動く）。
    expect(find.text('READY'), findsOneWidget);
    // ★★ 警告が画面まで届くこと ★★
    expect(
      find.text('設定ファイルを読めなかったため既定に戻しました'),
      findsOneWidget,
    );
  });

  testWidgets('4 段すべて通れば画面が出る', (tester) async {
    await _pump(
      tester,
      FakeBootSteps(
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
