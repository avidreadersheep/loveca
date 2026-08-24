/// 共有形式の入出力（`docs/UI設計メモ.md` §2-5 / 決定 D67 / D68 / D69）.
///
/// ★★ Flutter に依存しない純粋な関数だけを置く ★★
/// 画面が無くても試せる形にしておく。判断（既定の刷り・4 枚超過の扱い）は
/// すべてここに閉じており、UI は結果を出すだけである。
///
/// ---
///
/// ## 書式（決定 D67）
///
/// ```
/// # ぼくらのクォリア        ← 出力は 1 行だけ書く。入力では無視する
/// LL-bp1-001 x4
/// PL!N-sd1-001 x3
/// ```
///
/// | 項目 | 定義 |
/// |---|---|
/// | 1 行 1 カード | 出力の並びは **cardNumber 昇順**。`toShareFormat` の `Map` は挿入順なので明示的に整える |
/// | 書式 | NFKC + 前後空白除去のあと `^(\S+)\s+[xX]?(\d+)$` に一致すること |
/// | 出力の枚数 | 必ず `x4` の形。★入力は `x4` / `X4` / `4` を受ける |
/// | 大文字小文字 | 区切りの `x` はどちらも受ける。★**cardNumber は区別する**（緩めると戻せない） |
/// | 空行 | 無視する |
/// | `#` | 前後空白除去後に `#` で始まる行はコメント。無視する |
/// | それ以外 | ★**`unparsed` として持ち帰る。黙って捨てない** |
///
/// ★★ JSON を採らない理由 ★★
/// 手で貼り付ける前提なので、**1 文字壊れると全体が読めなくなる**形は
/// 用途に合わない。行指向なら壊れた行だけを報告して残りを取り込める。
///
/// ★★ 「出力は行指向・入力は両方受ける」も採らない ★★
/// 入力経路が 2 本になると「どちらとして読まれたか」で不具合の切り分けが要る。
/// D43 が経路を 1 本に保つ理由と同じ形である。
library;

import 'dart:convert';

import 'package:loveca_core/loveca_core.dart';

import 'card_detail.dart';

/// 1 行の書式。★NFKC + 前後空白除去のあとに当てる。
final RegExp _lineFormat = RegExp(r'^(\S+)[ \t]+[xX]?(\d+)$');

/// ★この書式で表せない cardNumber かどうか。
///
/// 実データの cardNumber は ASCII のみ（`!-0123456789EHIKLMNPRSYZbcdlps`）で、
/// NFKC でも変化しないことを確認してある（2026-08-24 / 1,708 件）。
/// **ただしそれは現時点の実データの性質であって保証ではない。**
/// 新商品で空白や `#` を含む番号が出れば、行指向の書式では表せなくなる。
/// → 出力側で検出して呼び出し側へ返す（`test/data/deck_share_real_data_test.dart`
/// が実 dist の全件でこれが起きないことを見張っている）。
bool isEncodableCardNumber(String cardNumber) {
  final normalized = normalizeShareToken(cardNumber);
  if (normalized != cardNumber) return false;
  if (normalized.isEmpty) return false;
  if (normalized.startsWith('#')) return false;
  // ★1 行に書いて読み戻せることが条件そのものなので、そう書いて確かめる。
  return _lineFormat.firstMatch('$normalized x1')?.group(1) == normalized;
}

/// 入力の揺れを吸収する唯一の規則（決定 D67）。
///
/// ★NFKC + 前後空白除去だけ。**これ以上は許容しない。**
/// 大文字小文字を畳んだり記号を読み替えたりすると、
/// 「取り込めたが別のカードだった」が無言で起こりうる。
String normalizeShareToken(String raw) {
  // ★dart:convert に NFKC は無い。実データの cardNumber は ASCII のみなので、
  //   実際に効く範囲（全角英数と全角記号）だけを機械的に畳む。
  //   ★範囲を限った静的規則にしてあるのは決定 D40（fold）と同じ考え方で、
  //   「未知の文字を勝手に変えない」ため。
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    // 全角 ASCII（！ から ～）→ 半角。
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      // 全角空白 → 半角空白。
      buffer.write(' ');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim();
}

// ---------------------------------------------------------------------------
// 書き出し
// ---------------------------------------------------------------------------

/// 書き出した結果。
class DeckShareExport {
  const DeckShareExport({
    required this.text,
    required this.droppedUnknownPrintingIds,
    required this.unencodableCardNumbers,
  });

  final String text;

  /// ★★ 共有形式に載せられなかった刷り（決定 D35）★★
  /// `Deck.toShareFormat` は `if (printing == null) continue;`
  /// （`loveca-core/lib/src/entities/deck.dart:145`）で
  /// **マスタに無い刷りを無言で落とす。** cardNumber が引けないので
  /// 落とすこと自体は正しいが、**落としたことを言わないのは A-3 と同じ型**。
  final List<String> droppedUnknownPrintingIds;

  /// ★この書式で表せなかった cardNumber（実データでは 0 件）。
  final List<String> unencodableCardNumbers;

  bool get isComplete =>
      droppedUnknownPrintingIds.isEmpty && unencodableCardNumbers.isEmpty;
}

/// デッキを共有形式の文字列にする（決定 D67）。
///
/// ★★ 刷りの違いは残らない ★★
/// `toShareFormat` は cardNumber ごとに合算するので、同じ cardNumber の
/// `-SD` 3 枚と `-SD2` 1 枚は `x4` の 1 行になる。
/// **これは書式の性質であって不具合ではない**が、往復すると刷りが変わるので
/// 画面で必ず言う。刷りを保ったまま写したいなら複製（決定 D71）を使う。
DeckShareExport encodeDeckShare(
  Deck deck,
  Map<String, Printing> printings, {
  String? title,
}) {
  final counts = deck.toShareFormat(printings);

  // ★落ちた刷りを自分で数える。toShareFormat は教えてくれない。
  final dropped = [
    for (final entry in deck.entries)
      if (!printings.containsKey(entry.printingId)) entry.printingId,
  ];

  final unencodable = [
    for (final cardNumber in counts.keys)
      if (!isEncodableCardNumber(cardNumber)) cardNumber,
  ];

  final lines = <String>[
    if (title != null && title.trim().isNotEmpty) '# ${title.trim()}',
    // ★並びを決定的にする。Map の反復順に依存させない。
    for (final cardNumber in counts.keys.toList()..sort())
      if (isEncodableCardNumber(cardNumber)) '$cardNumber x${counts[cardNumber]}',
  ];

  return DeckShareExport(
    text: '${lines.join('\n')}\n',
    droppedUnknownPrintingIds: dropped,
    unencodableCardNumbers: unencodable,
  );
}

// ---------------------------------------------------------------------------
// 読み取り
// ---------------------------------------------------------------------------

/// 文字列を読んだ結果。
class DeckShareParse {
  const DeckShareParse({required this.counts, required this.unparsedLines});

  /// cardNumber -> 枚数。★同じ cardNumber が 2 行あれば足す。
  final Map<String, int> counts;

  /// ★★ 書式として読めなかった行（決定 D67）★★
  /// **未知の cardNumber とは別枠にしてある。**
  /// どちらも「取り込めなかった行」だが**利用者の対処が違う**——
  /// こちらは書き直す、あちらはデータを更新する。
  /// M3 で縮退 3 種を分けたのと同じ理由。
  final List<String> unparsedLines;

  bool get isEmpty => counts.isEmpty;
}

/// 共有形式の文字列を読む（決定 D67）。★黙って行を捨てない。
DeckShareParse parseDeckShare(String source) {
  final counts = <String, int>{};
  final unparsed = <String>[];

  for (final raw in const LineSplitter().convert(source)) {
    final line = normalizeShareToken(raw);
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;

    final match = _lineFormat.firstMatch(line);
    if (match == null) {
      unparsed.add(raw.trim());
      continue;
    }
    final count = int.parse(match.group(2)!);
    // ★0 枚を「入っている」と扱わない。書き間違いとして見せる。
    if (count <= 0) {
      unparsed.add(raw.trim());
      continue;
    }
    final cardNumber = match.group(1)!;
    counts[cardNumber] = (counts[cardNumber] ?? 0) + count;
  }

  return DeckShareParse(counts: counts, unparsedLines: unparsed);
}

// ---------------------------------------------------------------------------
// カタログへの解決
// ---------------------------------------------------------------------------

/// 1 件の cardNumber をどう解決したか。
class ResolvedShareCard {
  const ResolvedShareCard({
    required this.cardNumber,
    required this.printingId,
    required this.count,
    required this.candidates,
    required this.hasMultipleNormalPrintings,
  });

  final String cardNumber;

  /// ★取り込み時の既定の刷り（決定 D68）。**UI で差し替えられる。**
  final String printingId;

  final int count;

  /// 選べる刷り（`printingId` 昇順）。★1 件なら差し替えようがない。
  final List<Printing> candidates;

  /// ★★ 非パラレル刷りが複数ある cardNumber か（実データで 19 件）★★
  /// **既定がコイントスになる唯一の場所**なので、ここだけ件数を明示して開示する。
  /// 「刷りが複数ある」（実データで 600 件）とは別。それは差し替えの可否であって
  /// 開示の対象ではない——毎回 600 件の警告を出すと 19 件の意味が消える。
  final bool hasMultipleNormalPrintings;

  ResolvedShareCard withPrinting(String next) => ResolvedShareCard(
        cardNumber: cardNumber,
        printingId: next,
        count: count,
        candidates: candidates,
        hasMultipleNormalPrintings: hasMultipleNormalPrintings,
      );

  DeckEntry toEntry() => DeckEntry(printingId: printingId, count: count);
}

/// 取り込みの計画（`docs/UI設計メモ.md` §2-5(b)）。
///
/// ★★ 未知 cardNumber を無言で捨てない ★★
/// `DeckEntry` は printingId しか持てないため、マスタに無い cardNumber は
/// **そもそも DB に入れられない。** 入れられないので入れないが、
/// **入れなかったことを必ず見せる。** 黙って落とすのは A-3 と同じ失敗の型。
class DeckShareImportResult {
  const DeckShareImportResult({
    required this.resolved,
    required this.unknown,
    required this.unparsedLines,
    required this.overLimit,
  });

  /// 取り込める行。★既定の刷りが入っている（決定 D68）。
  final List<ResolvedShareCard> resolved;

  /// ★マスタに無い cardNumber と枚数。
  final List<(String cardNumber, int count)> unknown;

  /// ★書式として読めなかった行（原因も対処も `unknown` と違う）。
  final List<String> unparsedLines;

  /// ★★ 4 枚制限（6.1.1.2）を超える cardNumber（決定 D69）★★
  /// **弾かないし丸めもしない。**判定は `DeckValidator` が唯一（決定 D28）で、
  /// 取り込み側に 2 つ目の判定を置かない。丸めるのは A-3 と同じ型。
  /// → 取り込む前に見せ、取り込んだあとは P1 の検証に違反として出る。
  final List<(String cardNumber, int count)> overLimit;

  /// ★非パラレル刷りが複数あって、既定を選ぶしかなかったもの（決定 D68 / U7）。
  List<ResolvedShareCard> get ambiguous =>
      [for (final r in resolved) if (r.hasMultipleNormalPrintings) r];

  bool get isEmpty => resolved.isEmpty;

  /// 取り込む前に断りが要るか。
  bool get needsConfirmation =>
      unknown.isNotEmpty || unparsedLines.isNotEmpty || overLimit.isNotEmpty;

  List<DeckEntry> toEntries() => [for (final r in resolved) r.toEntry()];
}

/// ★★ 取り込み時の既定の刷りを選ぶ（決定 D68 / 未決 U7 の解消）★★
///
/// | 順 | 規則 |
/// |---:|---|
/// | 1 | `isParallel == false` の刷りのうち `printingId` 昇順の先頭 |
/// | 2 | 非パラレルが 1 件も無ければ、全刷りの `printingId` 昇順の先頭 |
///
/// ★★ 「代表を選ぶ」ではない ★★
/// `isBasePrinting`（cardNumber ごとの代表 1 枚）という概念は
/// **誤りとして廃止済み**（CLAUDE.md §5-(4)）。同じカードが複数商品に
/// 再録されると通常刷りが複数になるのが実データの姿である。
/// ここで決めているのは**取り込みという 1 回の操作の既定**にすぎず、
/// UI で差し替えられる。
///
/// ★規則 2 は実データでは起きない（非パラレル 0 件の cardNumber は 0 件）が、
/// 落とさない。将来ありうるし、落とすと**何も返せなくなる。**
Printing? defaultPrintingOf(List<Printing> printings) {
  if (printings.isEmpty) return null;
  final sorted = [...printings]
    ..sort((a, b) => a.printingId.compareTo(b.printingId));
  for (final printing in sorted) {
    if (!printing.isParallel) return printing;
  }
  return sorted.first;
}

/// 読んだ枚数をカタログへ当てる。
///
/// [maxCopies] は `RuleConfig.maxCopiesPerCardNumber`（総合ルール 6.1.1.2）。
/// ★定数にしない。6.1.2 により構築条件を変えるカードが存在しうる。
DeckShareImportResult resolveDeckShare(
  DeckShareParse parsed,
  CardDetailView catalog, {
  required int maxCopies,
}) {
  final resolved = <ResolvedShareCard>[];
  final unknown = <(String, int)>[];
  final overLimit = <(String, int)>[];

  // ★並びを決定的にする。読み取り順に依存させない。
  final cardNumbers = parsed.counts.keys.toList()..sort();

  for (final cardNumber in cardNumbers) {
    final count = parsed.counts[cardNumber]!;
    final candidates = catalog.printingsOf(cardNumber);
    final chosen = defaultPrintingOf(candidates);

    if (chosen == null) {
      // ★入れられないので入れない。**入れなかったことは必ず返す。**
      unknown.add((cardNumber, count));
      continue;
    }

    // ★4 枚制限が効くのはメインデッキだけ（6.1.1.2）。
    //   6.1.1.3 のエネルギーデッキには枚数制限の規定が無い。
    //   この非対称は DeckValidator が実装済みなので、開示もそれに合わせる。
    final card = catalog.cardOf(cardNumber);
    final limited = card != null && card.cardType != CardType.energy;
    if (limited && count > maxCopies) {
      overLimit.add((cardNumber, count));
    }

    resolved.add(
      ResolvedShareCard(
        cardNumber: cardNumber,
        printingId: chosen.printingId,
        count: count,
        candidates: candidates,
        hasMultipleNormalPrintings:
            candidates.where((p) => !p.isParallel).length > 1,
      ),
    );
  }

  return DeckShareImportResult(
    resolved: resolved,
    unknown: unknown,
    unparsedLines: parsed.unparsedLines,
    overLimit: overLimit,
  );
}
