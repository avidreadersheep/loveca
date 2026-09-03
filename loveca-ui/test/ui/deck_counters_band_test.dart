/// 3 本のカウンタ（`docs/Android UI 決定.md` §3-4）.
///
/// ★★ §7 の測定 5（**W-79**）—— 411 論理px に 1 段で入るか ★★
/// ★§3-4 が「★★しきい値は実装時に実測して決める★★」と書いている。
/// ★**測定の作法**（**D-28**）: ★刻み幅・標本点・判定手段を併記する。
///
/// | 項目 | 中身 |
/// |---|---|
/// | ★**判定手段** | ★`fitsOneRow` の答え（★★純粋関数★★）と、★立てた widget の `ValueKey` の 2 つ |
/// | ★**刻み幅** | ★**1 論理px**（★★境目は 1px 刻みで詰めた★★） |
/// | ★**標本点** | ★下の `境目` の群が★実際に走らせている値である |
/// | ★**測った日** | ★**2026-09-03** |
/// | ★**測った機械** | ★★**ウィジェット試験の既定のフォント**★★（★実機のフォントではない / ★下） |
///
/// ★★ この測定が覆わないもの ★★
/// ★**実機のフォント** —— ★ウィジェット試験は `Ahem` 系の試験用フォントを使う。
/// ★★実機（Android の Roboto / Noto Sans CJK）では★字幅が違う★★。
/// → ★**「入る / 入らない」は★★この条件での値である★★**（★**W-26** の実機とは別の相手）。
/// ★**縦の高さ** —— ★3 段になったときの高さは測っていない。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/deck_counters_band.dart';

const _config = RuleConfig.standard;

DeckValidationResult _validation({
  int member = 12,
  int live = 3,
  int energy = 0,
}) =>
    DeckValidationResult(
      issues: const [],
      memberCount: member,
      liveCount: live,
      energyCount: energy,
      unknownPrintingIds: const [],
    );

Future<void> _pumpAt(WidgetTester tester, double logicalWidth,
    {DeckValidationResult? validation}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(logicalWidth, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeckCountersBand(
          validation: validation ?? _validation(),
          config: _config,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _oneRow = find.byKey(const ValueKey('deckCounters:oneRow'));
final _threeRows = find.byKey(const ValueKey('deckCounters:threeRows'));

void main() {
  group('★★ 中身の正は `deckCountersOf` である ★★', () {
    test('3 本。★並びは メンバー → ライブ → エネルギー', () {
      final counters = deckCountersOf(_validation(), _config);

      expect(counters.map((c) => c.label), ['メンバー', 'ライブ', 'エネルギー']);
      expect(counters.map((c) => c.expected), [48, 12, 12]);
    });

    test('★数え直していない（`DeckValidationResult` をそのまま出す / 決定 D28）', () {
      final counters =
          deckCountersOf(_validation(member: 7, live: 5, energy: 11), _config);

      expect(counters.map((c) => c.actual), [7, 5, 11]);
    });

    test('★期待値は `RuleConfig` から来る（★字面を埋めていない）', () {
      const small = RuleConfig(memberCount: 4, liveCount: 4);
      final counters = deckCountersOf(_validation(), small);

      expect(counters.map((c) => c.expected),
          [small.memberCount, small.liveCount, small.energyDeckSize]);
    });
  });

  group('★★ 段は 1 か 3 である。★2 段は作らない（§3-4）★★', () {
    test('★`fitsOneRow` —— ★ちょうど収まるときは入る', () {
      expect(fitsOneRow(const [10, 10, 10], 5, 40), isTrue);
    });

    test('★`fitsOneRow` —— ★1 だけ足りなければ入らない', () {
      expect(fitsOneRow(const [10, 10, 10], 5, 39), isFalse);
    });

    test('★`fitsOneRow` —— ★間隔も数える（★★本の幅だけを見ていない★★）', () {
      // ★合計 30 は入るが、★間隔 5 × 2 を足した 40 は入らない。
      expect(fitsOneRow(const [10, 10, 10], 0, 30), isTrue);
      expect(fitsOneRow(const [10, 10, 10], 5, 30), isFalse);
    });

    testWidgets('★広ければ 1 段', (tester) async {
      await _pumpAt(tester, 1000);

      expect(_oneRow, findsOneWidget);
      expect(_threeRows, findsNothing);
    });

    testWidgets('★★対: 狭ければ 3 段（★2 段にはならない）★★', (tester) async {
      await _pumpAt(tester, 120);

      expect(_threeRows, findsOneWidget);
      expect(_oneRow, findsNothing);
      // ★★3 本とも在る（★★畳んで捨てていない★★）★★
      for (final label in ['メンバー', 'ライブ', 'エネルギー']) {
        expect(find.byKey(ValueKey('deckCounter:$label')), findsOneWidget);
      }
    });

    testWidgets('★ラベルを縮めていない（§3-4）', (tester) async {
      await _pumpAt(tester, 120);

      expect(find.textContaining('メンバー'), findsOneWidget);
      expect(find.textContaining('エネルギー'), findsOneWidget);
    });
  });

  group('★★ W-79 —— ★411 論理px（§3-1 の電話の幅）で測った ★★', () {
    // ★★答え: ★★411 では 1 段に入らない。★3 段になる★★（2026-09-03 実測）★★
    //   ★§3-4 は「1 段に入れば横 1 段。★入らなければ 3 段」と定めている。
    //   → ★**電話では★★3 段が既定の見え方である★★。**
    testWidgets('★★411 論理px では★1 段に入らない（★3 段になる）★★', (tester) async {
      await _pumpAt(tester, 411);

      expect(_threeRows, findsOneWidget);
      expect(_oneRow, findsNothing);
    });

    testWidgets('★★境目は 517 論理px —— ★1 論理px 刻みで詰めた（2026-09-03 実測）★★',
        (tester) async {
      // ★★「〜付近」と書かない（**D-28**）★★ —— ★境目そのものを両側から当てる。
      //   ★**刻み幅 1 論理px** ／ ★**判定手段は `ValueKey`** ／
      //   ★**入力は メンバー 12 / 48・ライブ 3 / 12・エネルギー 0 / 12**（★§3-3 の図と同じ値）。
      await _pumpAt(tester, 517);
      expect(_oneRow, findsOneWidget, reason: '517 では入る');

      await _pumpAt(tester, 516);
      expect(_threeRows, findsOneWidget, reason: '516 では入らない');
    });

    testWidgets('★★対: 枚数が 3 桁になると境目が動く —— ★588（★中身に依る）★★',
        (tester) async {
      // ★★しきい値は定数ではない★★ —— ★数字が長くなれば必要幅が増える。
      //   ★**だから `LayoutBuilder` が実際の幅を見る**（★定数を書かない）。
      final wide = _validation(member: 100, live: 100, energy: 100);

      await _pumpAt(tester, 588, validation: wide);
      expect(_oneRow, findsOneWidget, reason: '588 では入る');

      await _pumpAt(tester, 587, validation: wide);
      expect(_threeRows, findsOneWidget, reason: '587 では入らない');
    });
  });

  group('★★ 超過は数字を赤にする（§3-4）★★', () {
    TextStyle? styleOf(WidgetTester tester, String label) =>
        tester.widget<Text>(find.byKey(ValueKey('deckCounter:$label'))).style;

    // ★★色は★他の 2 本と比べる（★`null` と比べない）★★
    //   ★`copyWith(color: null)` は★★元の色を落とさない★★ので、
    //   ★`style.color` は theme の既定色になる（★2026-09-03 に測って分かった）。
    //   → ★**「赤か」ではなく「★★他の本と違うか★★」を見る。**

    testWidgets('★超過は赤（★他の本と違う）', (tester) async {
      await _pumpAt(tester, 1000, validation: _validation(energy: 13));

      final theme = ThemeData();
      expect(styleOf(tester, 'エネルギー')?.color, theme.colorScheme.error);
      expect(styleOf(tester, 'エネルギー')?.color,
          isNot(styleOf(tester, 'メンバー')?.color));
      expect(styleOf(tester, 'エネルギー')?.fontWeight, FontWeight.w600);
    });

    testWidgets('★★対: 不足は赤にしない（★組んでいる途中は必ず不足している）★★',
        (tester) async {
      await _pumpAt(tester, 1000, validation: _validation(energy: 0));

      expect(styleOf(tester, 'エネルギー')?.color,
          styleOf(tester, 'メンバー')?.color);
      expect(styleOf(tester, 'エネルギー')?.fontWeight, isNot(FontWeight.w600));
    });

    testWidgets('★対: ちょうどでも赤にしない', (tester) async {
      await _pumpAt(tester, 1000, validation: _validation(energy: 12));

      expect(styleOf(tester, 'エネルギー')?.color,
          styleOf(tester, 'メンバー')?.color);
    });
  });
}
