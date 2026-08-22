/// デッキ構築ルールの検証.
///
/// 総合ルール 6.1 / 設計書 STEP 7 §7.4 に対応。
///
/// ★★ このクラスは PC・スマホ・サーバの 3 者で共有される唯一の実装でなければならない ★★
///
/// 決定 D28 (スマホと PC でデータを共有する) の前提条件がこれ。
/// 別実装にすると「スマホでは合法、PC では不正」という事故が起きる。
/// そのため loveca_core は Flutter に一切依存させない純粋 Dart パッケージとする。
///
/// 検証の非対称性:
///   保持は printingId 単位 (決定 D11)
///   検証は cardNumber 単位 (総合ルール 6.1.1.2)

library;

import '../entities/card.dart';
import '../entities/deck.dart';

enum DeckIssueCode {
  /// 総合ルール 6.1.1.2: 同一カードナンバーは 4 枚まで
  /// ★メインデッキのみ。エネルギーデッキには適用されない。
  tooManyCopies,

  /// 総合ルール 6.1.1.1: メンバー 48 枚ちょうど
  memberCountMismatch,

  /// 総合ルール 6.1.1.1: ライブ 12 枚ちょうど
  liveCountMismatch,

  /// 総合ルール 6.1.1.3: エネルギー 12 枚ちょうど
  energyCountMismatch,

  /// 参照先の printingId がカードマスタに存在しない (決定 D35)
  unknownPrinting,

  /// 枚数が 0 以下
  invalidCount,
}

class DeckIssue {
  const DeckIssue({
    required this.code,
    required this.message,
    this.cardNumber,
    this.printingId,
    this.actual,
    this.expected,
  });

  final DeckIssueCode code;
  final String message;
  final String? cardNumber;
  final String? printingId;
  final int? actual;
  final int? expected;

  @override
  String toString() => message;
}

class DeckValidationResult {
  const DeckValidationResult({
    required this.issues,
    required this.memberCount,
    required this.liveCount,
    required this.energyCount,
    required this.unknownPrintingIds,
  });

  final List<DeckIssue> issues;
  final int memberCount;
  final int liveCount;
  final int energyCount;

  /// カードマスタに存在しない printingId。
  /// ★決定 D35: これらを黙って削除してはいけない。デッキが静かに壊れる。
  final List<String> unknownPrintingIds;

  bool get isValid => issues.isEmpty;

  /// 未知カードを含む場合、編集は禁止し読み取り専用で表示する。
  bool get hasUnknownCards => unknownPrintingIds.isNotEmpty;
}

class DeckValidator {
  const DeckValidator({
    required this.cards,
    required this.printings,
    this.config = RuleConfig.standard,
  });

  /// cardNumber -> Card
  final Map<String, Card> cards;

  /// printingId -> Printing
  final Map<String, Printing> printings;

  final RuleConfig config;

  DeckValidationResult validate(Deck deck) {
    final issues = <DeckIssue>[];
    final unknown = <String>[];

    // cardNumber 単位に集約する。★ここが検証の単位 (総合ルール 6.1.1.2)
    final byCardNumber = <String, int>{};
    final countByType = <CardType, int>{
      CardType.member: 0,
      CardType.live: 0,
      CardType.energy: 0,
    };

    for (final entry in deck.entries) {
      if (entry.count <= 0) {
        issues.add(DeckIssue(
          code: DeckIssueCode.invalidCount,
          printingId: entry.printingId,
          actual: entry.count,
          message: '${entry.printingId}: 枚数が不正です (${entry.count})',
        ));
        continue;
      }

      final printing = printings[entry.printingId];
      if (printing == null) {
        unknown.add(entry.printingId);
        issues.add(DeckIssue(
          code: DeckIssueCode.unknownPrinting,
          printingId: entry.printingId,
          message: '${entry.printingId}: カードデータが未取得です',
        ));
        continue;
      }

      final card = cards[printing.cardNumber];
      if (card == null) {
        unknown.add(entry.printingId);
        issues.add(DeckIssue(
          code: DeckIssueCode.unknownPrinting,
          printingId: entry.printingId,
          cardNumber: printing.cardNumber,
          message: '${printing.cardNumber}: カードデータが未取得です',
        ));
        continue;
      }

      // ★4 枚制限はメインデッキのみ (総合ルール 6.1.1.2)★
      //   「メインデッキには、カードナンバーが同一であるカードをそれぞれ4枚まで」
      //   6.1.1.3 のエネルギーデッキには枚数制限の規定が無い。
      //   同じエネルギーカードを 12 枚入れることが認められている。
      if (card.cardType != CardType.energy) {
        byCardNumber[printing.cardNumber] =
            (byCardNumber[printing.cardNumber] ?? 0) + entry.count;
      }
      countByType[card.cardType] = countByType[card.cardType]! + entry.count;
    }

    // -- 総合ルール 6.1.1.2: 同一カードナンバー 4 枚まで --------------------
    // ★異なる printing (パラレル) でも cardNumber が同じなら合算される
    for (final entry in byCardNumber.entries) {
      if (entry.value > config.maxCopiesPerCardNumber) {
        issues.add(DeckIssue(
          code: DeckIssueCode.tooManyCopies,
          cardNumber: entry.key,
          actual: entry.value,
          expected: config.maxCopiesPerCardNumber,
          message: '${entry.key}: ${entry.value}枚 '
              '(メインデッキの上限${config.maxCopiesPerCardNumber}枚。'
              'パラレル違いも合算されます)',
        ));
      }
    }

    final members = countByType[CardType.member]!;
    final lives = countByType[CardType.live]!;
    final energies = countByType[CardType.energy]!;

    // -- 総合ルール 6.1.1: 「ちょうど」の枚数 -------------------------------
    if (members != config.memberCount) {
      issues.add(DeckIssue(
        code: DeckIssueCode.memberCountMismatch,
        actual: members,
        expected: config.memberCount,
        message: 'メンバーカード ${members}枚 (${config.memberCount}枚ちょうど必要)',
      ));
    }
    if (lives != config.liveCount) {
      issues.add(DeckIssue(
        code: DeckIssueCode.liveCountMismatch,
        actual: lives,
        expected: config.liveCount,
        message: 'ライブカード ${lives}枚 (${config.liveCount}枚ちょうど必要)',
      ));
    }
    if (energies != config.energyDeckSize) {
      issues.add(DeckIssue(
        code: DeckIssueCode.energyCountMismatch,
        actual: energies,
        expected: config.energyDeckSize,
        message: 'エネルギーカード ${energies}枚 (${config.energyDeckSize}枚ちょうど必要)',
      ));
    }

    return DeckValidationResult(
      issues: issues,
      memberCount: members,
      liveCount: lives,
      energyCount: energies,
      unknownPrintingIds: unknown,
    );
  }

  /// 追加可能かどうかを事前判定する (UI で「+」を無効化するため)。
  bool canAdd(Deck deck, String printingId) {
    final printing = printings[printingId];
    if (printing == null) return false;

    // エネルギーカードに 4 枚制限は無い (総合ルール 6.1.1.2 はメインデッキのみ)。
    // ただしエネルギーデッキ全体の 12 枚上限は超えられない。
    final card = cards[printing.cardNumber];
    if (card?.cardType == CardType.energy) {
      var energyTotal = 0;
      for (final entry in deck.entries) {
        final p = printings[entry.printingId];
        if (p == null) continue;
        if (cards[p.cardNumber]?.cardType == CardType.energy) {
          energyTotal += entry.count;
        }
      }
      return energyTotal < config.energyDeckSize;
    }

    var current = 0;
    for (final entry in deck.entries) {
      final p = printings[entry.printingId];
      if (p != null && p.cardNumber == printing.cardNumber) {
        current += entry.count;
      }
    }
    return current < config.maxCopiesPerCardNumber;
  }

  /// 同一 cardNumber の合計枚数 (絵柄内訳 UI で使う)。
  int countOf(Deck deck, String cardNumber) {
    var total = 0;
    for (final entry in deck.entries) {
      final p = printings[entry.printingId];
      if (p != null && p.cardNumber == cardNumber) total += entry.count;
    }
    return total;
  }
}
