/// アプリの器（`docs/UI設計メモ.md` §2-2）.
///
/// ★★ ホームはデッキ一覧（R2）である ★★
/// アプリの目的がデッキ構築だから（§2-2「カード一覧をホームにしない」）。
/// M1 では R2 がまだ無かったので R4 を暫定のホームにしていた。
/// M2 で戻したが、**戻し忘れても `flutter analyze` もほかのテストも通る**ので
/// ここで固定する。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/app.dart';

import 'support/fake_boot_steps.dart';

void main() {
  testWidgets('★起動ゲートを抜けた先がデッキ一覧（R2）である', (tester) async {
    await tester.pumpWidget(LovecaApp(steps: FakeBootSteps(cards: oneCard())));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'デッキ'), findsOneWidget);
    expect(find.text('新規デッキ'), findsOneWidget);

    // ★カード一覧をホームにしない。
    expect(find.widgetWithText(AppBar, 'カード'), findsNothing);
  });

  testWidgets('★R4（カード閲覧）へは R2 から入れる', (tester) async {
    await tester.pumpWidget(LovecaApp(steps: FakeBootSteps(cards: oneCard())));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('カードを見る'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'カード'), findsOneWidget);
  });

  testWidgets('★起動が失敗したらホームを出さない', (tester) async {
    // カタログが空なら段 4 で止まる（決定 D60 / 設計メモ §4-6(4)）。
    await tester.pumpWidget(LovecaApp(steps: FakeBootSteps()));
    await tester.pumpAndSettle();

    expect(find.textContaining('起動できませんでした'), findsOneWidget);
    expect(find.text('新規デッキ'), findsNothing);
  });
}
