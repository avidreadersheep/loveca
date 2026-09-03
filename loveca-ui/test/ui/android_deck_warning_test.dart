/// Android の警告の文言（`docs/Android UI 決定.md` §3-17）.
///
/// ★★ 何を固定するか ★★
/// ★**5 つの文言**（★1〜4 は命令形 / ★★5 は命令形にしない★★）／
/// ★**数は `RuleConfig` から来る**（★字面ではない）／
/// ★★**「同名カード」を 1 度も出さない**★★ / ★**内部語彙を 1 つも出さない** /
/// ★**1 件 = 1 行**（★改行を 1 つも含まない）。
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**どの issue を出すか**（★★`visibleDeckIssues` が決める★★ / §1-1）／
/// ★**呼ぶ側**（★★`lib` に 1 つも無い★★ / **D-20**）／
/// ★**Windows の文言**（★`DeckIssue.message` は★★1 文字も変えていない★★）／
/// ★**カード名の引き方**（★★呼び出し側から受け取る★★ / U21 の論点 1 に触らない）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/android_deck_warning.dart';
import 'package:loveca_ui/src/ui/deck/deck_validation_panel.dart';
import 'package:path/path.dart' as p;

import '../support/strip_comments.dart';

DeckIssue _issue(
  DeckIssueCode code, {
  String? cardNumber,
  String? printingId,
  int? actual,
  int? expected,
}) =>
    DeckIssue(
      code: code,
      message: 'windows の文言',
      cardNumber: cardNumber,
      printingId: printingId,
      actual: actual,
      expected: expected,
    );

void main() {
  group('§3-17 の 5 つの文言', () {
    test('1 —— メンバー（★命令形）', () {
      expect(
        androidDeckWarningOf(
          _issue(DeckIssueCode.memberCountMismatch, actual: 45, expected: 48),
        ),
        'メンバーカードは 48 枚にしてください。',
      );
    });

    test('2 —— ライブ（★命令形）', () {
      expect(
        androidDeckWarningOf(
          _issue(DeckIssueCode.liveCountMismatch, actual: 3, expected: 12),
        ),
        'ライブカードは 12 枚にしてください。',
      );
    });

    test('3 —— エネルギー（★命令形）', () {
      expect(
        androidDeckWarningOf(
          _issue(DeckIssueCode.energyCountMismatch, actual: 5, expected: 12),
        ),
        'エネルギーカードは 12 枚にしてください。',
      );
    });

    test('4 —— カードナンバー ＋（カード名）', () {
      expect(
        androidDeckWarningOf(
          _issue(
            DeckIssueCode.tooManyCopies,
            cardNumber: 'LL-bp1-001',
            actual: 5,
            expected: 4,
          ),
          nameOf: (n) => n == 'LL-bp1-001' ? '日野下花帆' : null,
        ),
        'LL-bp1-001「日野下花帆」は 4 枚までです。',
      );
    });

    test('5 —— 見つからない刷り（★★命令形にしない★★）', () {
      final text = androidDeckWarningOf(
        _issue(DeckIssueCode.unknownPrinting, printingId: 'LL-bp1-001-P'),
      );
      expect(text, 'LL-bp1-001-P のカードが見つかりません。');
      // ★★ 対 —— ★命令形の語を 1 つも含まない ★★
      expect(text.contains('してください'), isFalse);
      expect(text.contains('までです'), isFalse);
    });
  });

  group('数は `RuleConfig` から来る（★字面ではない）', () {
    test('48 / 12 / 12 / 4 は `expected` から出る', () {
      expect(
        androidDeckWarningOf(
          _issue(DeckIssueCode.memberCountMismatch, expected: 40),
        ),
        'メンバーカードは 40 枚にしてください。',
      );
      expect(
        androidDeckWarningOf(
          _issue(DeckIssueCode.tooManyCopies, cardNumber: 'X', expected: 2),
        ),
        'X は 2 枚までです。',
      );
    });

    test('★対: 実物の `DeckValidator` が `expected` を詰めている', () {
      final result = DeckValidator(
        cards: const {},
        printings: const {},
        config: const RuleConfig(memberCount: 48, liveCount: 12),
      ).validate(
        Deck(
          deckId: 'd',
          name: 'n',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final member = result.issues
          .firstWhere((i) => i.code == DeckIssueCode.memberCountMismatch);
      expect(
        androidDeckWarningOf(member),
        'メンバーカードは 48 枚にしてください。',
      );
    });
  });

  group('作法（★実装メモ §9-5 / M3）', () {
    List<String> allTexts() => androidDeckWarnings([
          _issue(DeckIssueCode.memberCountMismatch, expected: 48),
          _issue(DeckIssueCode.liveCountMismatch, expected: 12),
          _issue(DeckIssueCode.energyCountMismatch, expected: 12),
          _issue(
            DeckIssueCode.tooManyCopies,
            cardNumber: 'LL-bp1-001',
            expected: 4,
          ),
          _issue(DeckIssueCode.unknownPrinting, printingId: 'LL-bp1-001-P'),
          _issue(DeckIssueCode.invalidCount, printingId: 'LL-bp1-002-P'),
        ], nameOf: (_) => '日野下花帆');

    test('★★「同名カード」を 1 度も出さない★★', () {
      for (final t in allTexts()) {
        expect(t.contains('同名'), isFalse, reason: t);
      }
    });

    test('内部語彙を 1 つも出さない', () {
      for (final t in allTexts()) {
        for (final code in DeckIssueCode.values) {
          expect(t.contains(code.name), isFalse, reason: '$t / ${code.name}');
        }
      }
      // ★★ 対 —— ★`DeckIssue.message`（★Windows の文言）は★1 度も出ない ★★
      for (final t in allTexts()) {
        expect(t.contains('windows の文言'), isFalse);
      }
    });

    test('1 件 = 1 行（★改行を 1 つも含まない）', () {
      for (final t in allTexts()) {
        expect(t.contains(String.fromCharCode(10)), isFalse, reason: t);
      }
    });

    test('★6 つの code に 1 つずつ文言が在る（★★空にならない★★）', () {
      expect(allTexts(), hasLength(DeckIssueCode.values.length));
      for (final t in allTexts()) {
        expect(t.trim(), isNotEmpty);
      }
    });
  });

  group('カード名が引けないとき（★既定値）', () {
    test('番号だけを出す（★★空の括弧を作らない★★）', () {
      expect(
        androidDeckWarningOf(
          _issue(
            DeckIssueCode.tooManyCopies,
            cardNumber: 'LL-bp1-001',
            expected: 4,
          ),
        ),
        'LL-bp1-001 は 4 枚までです。',
      );
      // ★★ 対 —— ★引ける場合は括弧が出る（★「常に番号だけ」と区別できる形）★★
      expect(
        androidDeckWarningOf(
          _issue(
            DeckIssueCode.tooManyCopies,
            cardNumber: 'LL-bp1-001',
            expected: 4,
          ),
          nameOf: (_) => '花帆',
        ),
        'LL-bp1-001「花帆」は 4 枚までです。',
      );
    });
  });

  group('出し分けを 2 か所に置かない（**D-15** の規約 3）', () {
    test('★この層は★1 件も落とさない', () {
      // ★★ エネルギー 0 枚の規則は `visibleDeckIssues` が持つ（§1-1）★★
      final issues = [
        _issue(DeckIssueCode.energyCountMismatch, actual: 0, expected: 12),
      ];
      expect(androidDeckWarnings(issues), hasLength(1));
      // ★★ 対 —— ★落とすのは `visibleDeckIssues` の側である ★★
      final shown = visibleDeckIssues(
        DeckValidationResult(
          issues: issues,
          memberCount: 48,
          liveCount: 12,
          energyCount: 0,
          unknownPrintingIds: const [],
        ),
      );
      expect(androidDeckWarnings(shown), isEmpty);
    });
  });

  group('走査 —— `DeckIssue.message` を使っていない', () {
    test('★この層のソースに `.message` が 1 つも無い', () {
      final src = stripComments(
        File(p.join('lib', 'src', 'ui', 'deck', 'android_deck_warning.dart'))
            .readAsStringSync(),
      );
      expect(src.contains('.message'), isFalse);
      // ★★ 陽性対照（**D-10**）—— ★コメントを外す処理が働いていること ★★
      //   ★**doc には Windows の文言の写しが在る**（★上の doc）。
      //   ★★**外したあとの本文には 1 つも無い**★★。
      expect(src.contains('ちょうど必要'), isFalse);
    });
  });
}
