/// ★★ M6 の本命テスト（2）— 共有形式（決定 D67 / D68 / D69 / D35）★★
///
/// ★★ 実データの形で見る（M4 / M5 の教訓）★★
/// M4 の誤検知（区分をまたぐと縮退が出る）は**テストデータが単純すぎて
/// 通った**例だった。ここは `real_shaped_catalog.dart` を使い、
/// **非パラレル刷りが 2 つある実在の cardNumber**（`PL!N-sd1-001`。
/// 実データで 19 種しかない）で既定の刷りの選び方を見る。
///
/// ★★ 「起きない入力で出ないこと」も対で固定する ★★
/// 未知が出る側だけ見ると、**常に未知を返す**実装でも通ってしまう。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_detail.dart';
import 'package:loveca_ui/src/data/deck_share.dart';

import '../support/real_shaped_catalog.dart';

final _t0 = DateTime.utc(2026, 8, 24, 12);

final _catalog = realShapedCatalog();
final _view = CardDetailView(_catalog);

Deck _deck(List<DeckEntry> entries, {String name = 'テストデッキ'}) => Deck(
      deckId: 'deck-1',
      name: name,
      entries: entries,
      createdAt: _t0,
      updatedAt: _t0,
    );

DeckShareImportResult _resolve(String text, {int maxCopies = 4}) =>
    resolveDeckShare(parseDeckShare(text), _view, maxCopies: maxCopies);

void main() {
  group('前提（fixture が狙った形をしていること）', () {
    test('★非パラレル刷りが 2 つある cardNumber が入っている', () {
      final printings = _view.printingsOf(multiNormalCardNumber);
      expect(printings, hasLength(3));
      expect(
        printings.where((p) => !p.isParallel).map((p) => p.printingId),
        [multiNormalFirst, multiNormalSecond],
        reason: '★これが無いと「既定を選ぶしかない」経路を通らない（実データで 19 種）',
      );
    });

    test('刷りが 1 つだけの cardNumber も入っている（対照）', () {
      expect(_view.printingsOf('LL-bp1-001'), hasLength(1));
    });
  });

  group('★ 書式（決定 D67）', () {
    test('1 行 1 カード。並びは cardNumber 昇順', () {
      final export = encodeDeckShare(
        _deck(const [
          DeckEntry(printingId: parallelMemberNormal, count: 2),
          DeckEntry(printingId: trioMemberPrinting, count: 1),
        ]),
        _catalog.printings,
      );

      expect(export.text, 'LL-bp1-001 x1\nPL!HS-bp1-002 x2\n');
      expect(export.isComplete, isTrue);
    });

    test('タイトルは # の行で書く', () {
      final export = encodeDeckShare(
        _deck(const [DeckEntry(printingId: trioMemberPrinting, count: 1)]),
        _catalog.printings,
        title: 'ぼくらのクォリア',
      );

      expect(export.text, '# ぼくらのクォリア\nLL-bp1-001 x1\n');
    });

    test('★★ 出力を読み戻すと一致する（往復）★★', () {
      final export = encodeDeckShare(
        _deck(const [
          DeckEntry(printingId: trioMemberPrinting, count: 4),
          DeckEntry(printingId: energyPrinting, count: 12),
          DeckEntry(printingId: multiNormalFirst, count: 3),
        ]),
        _catalog.printings,
        title: 'タイトルは無視される',
      );

      final parsed = parseDeckShare(export.text);

      expect(parsed.unparsedLines, isEmpty,
          reason: '★出力と入力が別々に育つと往復が壊れる');
      expect(parsed.counts, {
        'LL-bp1-001': 4,
        'PL!-bp1-000': 12,
        multiNormalCardNumber: 3,
      });
    });

    test('# の行と空行は無視する', () {
      final parsed = parseDeckShare(
        '# デッキ名\n\n  \nLL-bp1-001 x1\n   # 途中のコメント\n',
      );
      expect(parsed.counts, {'LL-bp1-001': 1});
      expect(parsed.unparsedLines, isEmpty);
    });

    test('★枚数は x4 / X4 / 4 のどれでも読める', () {
      expect(parseDeckShare('LL-bp1-001 x4').counts, {'LL-bp1-001': 4});
      expect(parseDeckShare('LL-bp1-001 X4').counts, {'LL-bp1-001': 4});
      expect(parseDeckShare('LL-bp1-001 4').counts, {'LL-bp1-001': 4});
    });

    test('★全角で貼られても読める（NFKC 相当 + 前後空白除去）', () {
      // ★実データの cardNumber は ASCII のみだが、貼り付けで全角になりうる。
      expect(parseDeckShare('ＬＬ－ｂｐ１－００１　ｘ４').counts,
          {'LL-bp1-001': 4});
    });

    test('★★ cardNumber の大文字小文字は区別する ★★', () {
      // ★緩めると戻せない。いま実データに衝突は無いが、それは保証ではない。
      final result = _resolve('ll-BP1-001 x1');
      expect(result.resolved, isEmpty);
      expect(result.unknown, [('ll-BP1-001', 1)]);
    });

    test('同じ cardNumber が 2 行あれば足す', () {
      expect(parseDeckShare('LL-bp1-001 x1\nLL-bp1-001 x2').counts,
          {'LL-bp1-001': 3});
    });
  });

  group('★★ 読めない行を黙って捨てない（決定 D67）★★', () {
    test('★書式に合わない行は unparsed に残る', () {
      final parsed = parseDeckShare(
        'LL-bp1-001 x1\nこれは行ではない\nLL-bp1-001だけ\n',
      );

      expect(parsed.counts, {'LL-bp1-001': 1}, reason: '読めた行は取り込む');
      expect(parsed.unparsedLines, ['これは行ではない', 'LL-bp1-001だけ']);
    });

    test('★0 枚は書き間違いとして見せる（「入っている」にしない）', () {
      final parsed = parseDeckShare('LL-bp1-001 x0');
      expect(parsed.counts, isEmpty);
      expect(parsed.unparsedLines, ['LL-bp1-001 x0']);
    });

    test('★全部読める入力では unparsed が空（出ない側）', () {
      final parsed = parseDeckShare('LL-bp1-001 x1\nPL!HS-bp1-002 x2\n');
      expect(parsed.unparsedLines, isEmpty,
          reason: '出る側だけ見ると、常に何か返す実装でも通ってしまう');
    });

    test('★★ 未解釈の行と未知 cardNumber は別枠である ★★', () {
      // ★どちらも「取り込めなかった行」だが利用者の対処が違う——
      //   前者は書き直す、後者はデータを更新する。
      final result = _resolve('よめない行\nZZ-none-001 x2\nLL-bp1-001 x1');

      expect(result.unparsedLines, ['よめない行']);
      expect(result.unknown, [('ZZ-none-001', 2)]);
      expect(result.resolved.map((r) => r.cardNumber), ['LL-bp1-001']);
    });
  });

  group('★★ 未知 cardNumber を黙って捨てない（§2-5(b) / A-3）★★', () {
    test('★マスタに無い cardNumber は unknown に枚数つきで残る', () {
      final result = _resolve('ZZ-none-001 x2\nLL-bp1-001 x1');

      expect(result.unknown, [('ZZ-none-001', 2)]);
      expect(result.needsConfirmation, isTrue,
          reason: '「N 件が見つからない。取り込むか中止するか」を選ばせる');
      // ★入れられないので入れない。しかし残りは取り込める。
      //   ★DeckEntry は == を持たないので、値で比べる。
      expect(
        {for (final e in result.toEntries()) e.printingId: e.count},
        {trioMemberPrinting: 1},
      );
    });

    test('★全部既知なら unknown は空（出ない側）', () {
      final result = _resolve('LL-bp1-001 x1\nPL!HS-bp1-002 x2');

      expect(result.unknown, isEmpty,
          reason: '出る側だけ見ると、常に未知を返す実装でも通ってしまう');
      expect(result.needsConfirmation, isFalse);
    });
  });

  group('★★ 既定の刷り（決定 D68 / 未決 U7 の解消）★★', () {
    test('★★ 非パラレルのうち printingId 昇順の先頭を採る ★★', () {
      final result = _resolve('$multiNormalCardNumber x4');

      final card = result.resolved.single;
      expect(card.printingId, multiNormalFirst,
          reason: '-SD < -SD2。パラレルの -P は非パラレルより先に来ない');
      expect(card.count, 4);
    });

    test('★★ 非パラレルが複数あることを開示する（実データで 19 種）★★', () {
      final result = _resolve('$multiNormalCardNumber x4');

      expect(result.ambiguous.map((r) => r.cardNumber),
          [multiNormalCardNumber]);
      expect(result.resolved.single.candidates, hasLength(3),
          reason: '差し替えの候補はパラレルも含めて全部出す');
    });

    test('★★ 非パラレルが 1 つなら開示しない（出ない側）★★', () {
      // ★PL!HS-bp1-002 は 3 刷りあるが非パラレルは 1 つだけ。
      //   「刷りが複数」（実データ 600 件）と「非パラレルが複数」（19 件）は別。
      //   毎回 600 件の警告を出すと 19 件の意味が消える。
      final result = _resolve('PL!HS-bp1-002 x1');

      expect(result.ambiguous, isEmpty,
          reason: '差し替えの可否と、開示すべき曖昧さは別');
      expect(result.resolved.single.printingId, parallelMemberNormal);
      expect(result.resolved.single.candidates.length, greaterThan(1),
          reason: '★それでも差し替えはできる');
    });

    test('★刷りを差し替えられる', () {
      final result = _resolve('$multiNormalCardNumber x4');
      final swapped = result.resolved.single.withPrinting(multiNormalSecond);

      expect(swapped.printingId, multiNormalSecond);
      expect(swapped.count, 4, reason: '枚数は変わらない');
      expect(swapped.toEntry().printingId, multiNormalSecond);
    });

    test('★非パラレルが 1 件も無ければパラレルを採る（実データでは起きない）', () {
      // ★実データでは非パラレル 0 件の cardNumber は 0 件だが、
      //   落とすと何も返せなくなるので規則として残してある。
      const parallelOnly = Printing(
        printingId: 'X-1-P',
        cardNumber: 'X-1',
        expansion: 'BP01',
        rarity: 'P',
        isParallel: true,
      );
      expect(defaultPrintingOf(const [parallelOnly])?.printingId, 'X-1-P');
    });

    test('刷りが 1 つも無ければ null', () {
      expect(defaultPrintingOf(const []), isNull);
    });
  });

  group('★★ 4 枚制限を超える共有文字列（決定 D69）★★', () {
    test('★★ 弾かない。入れたうえで超過を見せる ★★', () {
      final result = _resolve('LL-bp1-001 x5');

      expect(result.overLimit, [('LL-bp1-001', 5)]);
      expect(result.needsConfirmation, isTrue);
      // ★丸めない。丸めるのは A-3 と同じ型。判定は DeckValidator が唯一（D28）。
      expect(result.toEntries().single.count, 5,
          reason: '取り込んだあと P1 の検証に違反として出る');
    });

    test('★4 枚以下なら出ない（出ない側）', () {
      final result = _resolve('LL-bp1-001 x4');
      expect(result.overLimit, isEmpty);
      expect(result.needsConfirmation, isFalse);
    });

    test('★★ エネルギーには 4 枚制限が無い（6.1.1.3）★★', () {
      // ★DeckValidator が既にそう実装しているので、開示もそれに合わせる。
      //   ここで独自に弾くと、判定が 2 つになる。
      final result = _resolve('PL!-bp1-000 x12');

      expect(result.overLimit, isEmpty,
          reason: '同じエネルギーカードを 12 枚入れることは認められている');
      expect(result.toEntries().single.count, 12);
    });

    test('★上限は RuleConfig から来る（6.1.2 で置換されうる）', () {
      // ★定数にしない。構築条件を変えるカードが存在しうる。
      final result = _resolve('LL-bp1-001 x5', maxCopies: 5);
      expect(result.overLimit, isEmpty);
    });
  });

  group('★★ 書き出しで未知の刷りを黙って落とさない（決定 D35）★★', () {
    test('★★ toShareFormat が捨てた刷りを数えて返す ★★', () {
      // ★`Deck.toShareFormat` は `if (printing == null) continue;`
      //   （loveca-core/lib/src/entities/deck.dart:145）で無言で落とす。
      //   cardNumber が引けないので落とすこと自体は正しいが、
      //   **落としたことを言わないのは A-3 と同じ型。**
      final export = encodeDeckShare(
        _deck(const [
          DeckEntry(printingId: trioMemberPrinting, count: 1),
          DeckEntry(printingId: 'UNKNOWN-1', count: 3),
        ]),
        _catalog.printings,
      );

      expect(export.text, 'LL-bp1-001 x1\n');
      expect(export.droppedUnknownPrintingIds, [('UNKNOWN-1', 3)]);
      expect(export.droppedCopies, 3,
          reason: '★「1 種類」と「3 枚」を取り違えない');
      expect(export.isComplete, isFalse);
    });

    test('★全部既知なら落ちない（出ない側）', () {
      final export = encodeDeckShare(
        _deck(const [DeckEntry(printingId: trioMemberPrinting, count: 1)]),
        _catalog.printings,
      );

      expect(export.droppedUnknownPrintingIds, isEmpty,
          reason: '出る側だけ見ると、常に何か落ちたと言う実装でも通る');
      expect(export.isComplete, isTrue);
    });
  });

  group('★★ 往復すると刷りの違いが潰れる（決定 D67 の性質）★★', () {
    test('★★ 同じ cardNumber の別の刷りは 1 行に合算される ★★', () {
      final export = encodeDeckShare(
        _deck(const [
          DeckEntry(printingId: multiNormalFirst, count: 3),
          DeckEntry(printingId: multiNormalSecond, count: 1),
        ]),
        _catalog.printings,
      );

      // ★これは書式の性質であって不具合ではない。だが往復で刷りが変わるので
      //   画面で必ず言う。刷りを保ちたいなら複製（決定 D71）。
      expect(export.text, '$multiNormalCardNumber x4\n');

      final back = _resolve(export.text);
      expect(back.resolved.single.printingId, multiNormalFirst,
          reason: '★既定の刷りに寄る。-SD2 の 1 枚は残らない');
      expect(back.resolved.single.count, 4);
    });
  });

  group('★ 書式で表せない cardNumber を検出する', () {
    test('空白や # を含むと表せない', () {
      expect(isEncodableCardNumber('LL-bp1-001'), isTrue);
      expect(isEncodableCardNumber('LL bp1 001'), isFalse);
      expect(isEncodableCardNumber('#LL-bp1-001'), isFalse);
      expect(isEncodableCardNumber(''), isFalse);
      // ★全角が混じるものは、正規化すると別物になるので表せない扱いにする。
      expect(isEncodableCardNumber('ＬＬ-bp1-001'), isFalse);
    });
  });
}
