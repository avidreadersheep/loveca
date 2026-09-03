/// 一覧の投影行と絞り込み（決定 D48 / `docs/UI設計メモ.md` §4-2）.
///
/// ★`spike/common/card_grid_data.dart` を写していない（決定 D51）。
/// 一覧が何を要るかから起こしてある。
///
/// 一覧の単位は**刷り（printing）**であって cardNumber ではない。
/// パラレル表示 OFF は `isParallel == false` の刷りを「すべて」出す
/// （CLAUDE.md §5-(4)）。代表 1 枚に畳む概念は誤りとして廃止済み。
library;

import 'package:loveca_core/loveca_core.dart';

/// グリッドのセル 1 つ分。**表示と絞り込みに要る列だけ**を持つ（決定 D48）。
///
/// 既存 DAO で `Card` / `Printing` を全件実体化すると 40〜60ms かかるのに対し、
/// この投影は 11〜15ms（`docs/UI技術検証メモ.md` §2）。
class CardListRow {
  const CardListRow({
    required this.printingId,
    required this.cardNumber,
    required this.name,
    required this.cardType,
    required this.expansion,
    required this.rarity,
    required this.isParallel,
    required this.imageHash,
    required this.cost,
  });

  /// 一覧の一意キー。**デッキが保持する単位**（決定 D11）。
  final String printingId;

  /// **4 枚制限の単位**（決定 D11 / 総合ルール 6.1.1.2）。カード詳細への鍵。
  final String cardNumber;

  final String name;

  /// ★`String` にしない。
  /// `spike` は `String` で持っており `cardType == 'energy'` という文字列比較が
  /// あった。綴りを間違えても**コンパイルは通り、静かに false になる。**
  final CardType cardType;

  final String expansion;
  final String rarity;

  /// パラレル表示 OFF の判定（CLAUDE.md §5-(4)）。
  final bool isParallel;

  /// ★空文字がありうる（`build --skip-images` 由来の dist）。
  /// そのときは `CardImageSource` が null を返し、プレースホルダのままになる。
  final String imageHash;

  /// ★★ メンバーにしか値が無い ★★
  /// `loveca-data/loveca_data/normalize.py:362-363` は `card.cost` を
  /// **`KIND_MEMBER` の分岐でしか設定していない。**
  /// ライブは `cost` フィールドを**ブレードハートの供給元として使う**
  /// （同 375-377 / CLAUDE.md §5-(1)「API のフィールド名を信用しない」）。
  final int? cost;
}

/// 数値の範囲。★★`null` は「未指定」である★★（§3-7 の絵）。
///
/// ★★ ここに置く理由（**D-15** の規約 3 —— ★★同じ型を 2 か所に持たない★★）★★
/// ★**フォーム（`ui/browse/number_range_picker.dart`）と★絞り込み（[CardListFilter]）の
/// ★★両方が要る★★**が、★★フォームの側は Flutter に依存する★★。
/// → ★**依存の少ない側（★このデータ層）に置き、★フォームが引く。**
typedef NumberRange = ({int? min, int? max});

/// [range] が [value] を通すか。
///
/// ★★ 値が無い行は★★範囲が指定されているときだけ落ちる★★ ★★
/// ★**例: ★スコアの範囲を指定したら★★スコアを持たないメンバーは落ちる★★**
/// （★★これは §3-6 の帰結であって★この関数の判断ではない★★ —— ★軸を外せばまた出る）。
bool numberRangeAllows(NumberRange range, int? value) {
  if (range.min == null && range.max == null) return true;
  if (value == null) return false;
  if (range.min != null && value < range.min!) return false;
  if (range.max != null && value > range.max!) return false;
  return true;
}

/// 範囲が 1 つも指定されていないか。
bool numberRangeIsEmpty(NumberRange range) =>
    range.min == null && range.max == null;

/// 色ごとの範囲が 1 つも指定されていないか。
bool heartRangesAreEmpty(Map<HeartColor, NumberRange> ranges) =>
    ranges.values.every(numberRangeIsEmpty);

/// 絞り込み条件。★メモリ上で絞る（決定 D48）。SQL を再実行しない。
///
/// ★★ 2026-09-03: 種別依存の軸（コスト）を常に効かせるようにした ★★
/// `docs/Android UI 決定.md` §1-4（★**§4-2 の案 (a) を覆す** / ★Windows も）。
///
/// 実測で 100〜200 倍速い（`docs/UI技術検証メモ.md` §3-6）。
/// 全 2,527 行はすでにメモリにあるので、絞り込みで DB へ行く理由がない。
class CardListFilter {
  const CardListFilter({
    this.expansion,
    this.cardType,
    this.maxCost,
    this.showParallel = true,
    this.groupName,
    this.unitName,
    this.blade = const (min: null, max: null),
    this.score = const (min: null, max: null),
    this.heartTotal = const (min: null, max: null),
    this.hearts = const {},
    this.requiredHeartTotal = const (min: null, max: null),
    this.requiredHearts = const {},
    this.bladeHearts = const {},
  });

  final String? expansion;
  final CardType? cardType;

  /// ★★ 2026-09-03: 種別に依らず常に効く（`docs/Android UI 決定.md` §1-4）★★
  ///
  /// ★以前は [cardType] が [CardType.member] のときだけ効いた（§4-2 の案 (a)）。
  /// `cost` はメンバーにしか値が無いため、素朴に絞ると
  /// **ライブとエネルギーが全部消える。**
  /// `docs/UI技術検証メモ.md` §3-6 の「コスト 2 以下 = 208 件」は
  /// **メンバーだけの件数**だった。
  ///
  /// ★★ 上の害は 1 ミリも消えていない。★受け入れた ★★
  /// 利用者が「常に出す」を選び、消えることを承知した（★§2 の穴 1）。
  /// → ★**警告も注記も出さない**（★申し送りは出すと書いていない）。
  /// ★**§4-2 の表と `docs/UI技術検証メモ.md` §3-6 の字面は 1 文字も書き換えない**（**D-35**）。
  final int? maxCost;

  /// ★false のとき `isParallel == false` の刷りを「すべて」残す。
  /// cardNumber ごとに 1 枚へ畳まない（CLAUDE.md §5-(4)）。
  final bool showParallel;

  // ---------------------------------------------------------------------------
  // ★★ 段 B —— ★`Card` から引く軸（§3-6 / ★U21 の論点 1）★★
  //
  // ★★ 投影（[CardListRow]）に 1 つも入っていない ★★
  //   ★**[CardListRow] が持つのは★★表示と絞り込みに要る 11 欄だけ★★**（決定 **D48**）。
  //   ★**下の 9 軸は★★どれも `Card` の欄である★★**（★2026-09-04 実読）。
  //   → ★**引くのは★★呼ぶ側が渡す `Map<String, Card>` である★★**
  //     （★★道 3 —— ★決定の正は `docs/Android UI 決定.md` §27★★）。
  // ---------------------------------------------------------------------------

  /// 登場作品（総合ルール 2.4 のグループ名称）。★★1 つでも一致すれば通す★★。
  final String? groupName;

  /// ユニット（総合ルール 2.5）。★同上。
  final String? unitName;

  /// ブレード（総合ルール 2.8）。★★メンバーにしか値が無い★★。
  final NumberRange blade;

  /// スコア（総合ルール 2.10）。★★ライブにしか値が無い★★。
  final NumberRange score;

  /// 所持ハートの合計（総合ルール 2.9）。
  final NumberRange heartTotal;

  /// 所持ハートの色ごと。★★指定した色だけを見る★★（★指定していない色は通す）。
  final Map<HeartColor, NumberRange> hearts;

  /// 必要ハートの合計（総合ルール 2.11）。
  final NumberRange requiredHeartTotal;

  /// 必要ハートの色ごと。
  final Map<HeartColor, NumberRange> requiredHearts;

  /// ブレードハートの色（総合ルール 2.7）。
  ///
  /// ★★ 色だけである。★ドロー / スコアのアイコンでは絞らない ★★
  /// ★**§3-6 が明示している。**★**総合ルール 8.3.14 に合算するのは★★色だけ★★で、
  /// ★ドローは 8.3.12.1、★スコアは 8.4.2.1 と★★処理する時点が違う★★**（`CLAUDE.md` §6）。
  final Map<HeartColor, NumberRange> bladeHearts;

  /// ★★ 段 B の軸が 1 つでも立っているか ★★
  ///
  /// ★**立っていなければ★★`Card` を 1 度も引かない★★**（★Windows の経路が 1 ビットも変わらない）。
  bool get needsCard =>
      groupName != null ||
      unitName != null ||
      !numberRangeIsEmpty(blade) ||
      !numberRangeIsEmpty(score) ||
      !numberRangeIsEmpty(heartTotal) ||
      !heartRangesAreEmpty(hearts) ||
      !numberRangeIsEmpty(requiredHeartTotal) ||
      !heartRangesAreEmpty(requiredHearts) ||
      !heartRangesAreEmpty(bladeHearts);

  bool get isEmpty =>
      expansion == null &&
      cardType == null &&
      maxCost == null &&
      showParallel &&
      !needsCard;

  /// [maxCost] が実際に適用されるか。
  ///
  /// ★★ 2026-09-03: 種別を見なくなった（`docs/Android UI 決定.md` §1-4）★★
  /// ★**UI の出し分けはもうこれを見ない** —— ★コスト欄は常に出る。
  bool get appliesCost => maxCost != null;

  CardListFilter copyWith({
    String? expansion,
    CardType? cardType,
    int? maxCost,
    bool? showParallel,
    String? groupName,
    String? unitName,
    NumberRange? blade,
    NumberRange? score,
    NumberRange? heartTotal,
    Map<HeartColor, NumberRange>? hearts,
    NumberRange? requiredHeartTotal,
    Map<HeartColor, NumberRange>? requiredHearts,
    Map<HeartColor, NumberRange>? bladeHearts,
    bool clearExpansion = false,
    bool clearCardType = false,
    bool clearMaxCost = false,
    bool clearGroupName = false,
    bool clearUnitName = false,
  }) =>
      CardListFilter(
        expansion: clearExpansion ? null : (expansion ?? this.expansion),
        cardType: clearCardType ? null : (cardType ?? this.cardType),
        maxCost: clearMaxCost ? null : (maxCost ?? this.maxCost),
        showParallel: showParallel ?? this.showParallel,
        groupName: clearGroupName ? null : (groupName ?? this.groupName),
        unitName: clearUnitName ? null : (unitName ?? this.unitName),
        blade: blade ?? this.blade,
        score: score ?? this.score,
        heartTotal: heartTotal ?? this.heartTotal,
        hearts: hearts ?? this.hearts,
        requiredHeartTotal: requiredHeartTotal ?? this.requiredHeartTotal,
        requiredHearts: requiredHearts ?? this.requiredHearts,
        bladeHearts: bladeHearts ?? this.bladeHearts,
      );

  /// ★★ 1 行を通すか ★★
  ///
  /// ★★ [card] が要るのは★段 B の軸が立っているときだけである ★★
  /// ★**立っていて [card] が無ければ★★通さない★★** —— ★これは★★決めた既定値である★★。
  /// ★**理由**: ★★「桃のハートを 3 個以上持つ」を★中身を知らない行が満たすとは言えない★★。
  /// ★**通すと★★条件を満たさない行が混ざる ＝ 絞り込みの意味が消える★★。**
  /// ★★**差し替え点はこの 1 行である。**★★
  ///
  /// ★★ 決定 **D35**（黙って削除しない）には当たらない ★★
  /// ★**あれは★★取り込みと保存★★の話である**（★マスタから消えたカードを★デッキから消さない）。
  /// ★**絞り込みは★★条件を満たす行を選ぶことであり、★軸を外せばその行はまた出る★★。**
  bool matches(CardListRow row, {Card? card}) {
    if (!showParallel && row.isParallel) return false;
    if (expansion != null && row.expansion != expansion) return false;
    if (cardType != null && row.cardType != cardType) return false;
    if (appliesCost) {
      final cost = row.cost;
      if (cost == null || cost > maxCost!) return false;
    }
    if (!needsCard) return true;
    if (card == null) return false;
    if (groupName != null && !card.groupNames.contains(groupName)) return false;
    if (unitName != null && !card.unitNames.contains(unitName)) return false;
    if (!numberRangeAllows(blade, card.bladeCount)) return false;
    if (!numberRangeAllows(score, card.score)) return false;
    if (!numberRangeAllows(heartTotal, card.heartTotal)) return false;
    if (!numberRangeAllows(requiredHeartTotal, card.requiredHeartTotal)) {
      return false;
    }
    if (!_heartsAllow(hearts, card.hearts)) return false;
    if (!_heartsAllow(requiredHearts, card.requiredHearts)) return false;
    if (!_heartsAllow(bladeHearts, card.bladeHearts)) return false;
    return true;
  }

  /// 色ごとの範囲を当てる。
  ///
  /// ★★ 持っていない色は 0 として見る ★★
  /// ★**`hearts` は★★持っている色だけを鍵に持つ★★**（★2026-09-04 実読）ので、
  /// ★`null` のまま渡すと★★「0 個以上」まで落ちる★★。
  static bool _heartsAllow(
    Map<HeartColor, NumberRange> ranges,
    Map<HeartColor, int> actual,
  ) {
    for (final entry in ranges.entries) {
      if (numberRangeIsEmpty(entry.value)) continue;
      if (!numberRangeAllows(entry.value, actual[entry.key] ?? 0)) return false;
    }
    return true;
  }

  /// ★★ [cards] は★段 B の軸が立っているときだけ引かれる ★★
  ///
  /// ★**Windows は 1 つも立てないので★★渡さなくてよい★★**（★経路が 1 ビットも変わらない）。
  List<CardListRow> apply(
    List<CardListRow> rows, {
    Map<String, Card> cards = const {},
  }) =>
      isEmpty
          ? rows
          : rows
              .where((row) => matches(row, card: cards[row.cardNumber]))
              .toList(growable: false);
}
