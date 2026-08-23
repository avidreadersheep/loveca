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

/// 絞り込み条件。★メモリ上で絞る（決定 D48）。SQL を再実行しない。
///
/// 実測で 100〜200 倍速い（`docs/UI技術検証メモ.md` §3-6）。
/// 全 2,527 行はすでにメモリにあるので、絞り込みで DB へ行く理由がない。
class CardListFilter {
  const CardListFilter({
    this.expansion,
    this.cardType,
    this.maxCost,
    this.showParallel = true,
  });

  final String? expansion;
  final CardType? cardType;

  /// ★★ [cardType] が [CardType.member] のときだけ効く ★★
  /// `cost` はメンバーにしか値が無いため、素朴に絞ると
  /// **ライブとエネルギーが全部消える。**
  /// `docs/UI技術検証メモ.md` §3-6 の「コスト 2 以下 = 208 件」は
  /// **メンバーだけの件数**だった。
  /// UI もコスト絞り込みを出すのはメンバー選択時だけにする（§4-2 の案 (a)）。
  final int? maxCost;

  /// ★false のとき `isParallel == false` の刷りを「すべて」残す。
  /// cardNumber ごとに 1 枚へ畳まない（CLAUDE.md §5-(4)）。
  final bool showParallel;

  bool get isEmpty =>
      expansion == null && cardType == null && maxCost == null && showParallel;

  /// [maxCost] が実際に適用されるか。UI の出し分けもこれを見る。
  bool get appliesCost => maxCost != null && cardType == CardType.member;

  CardListFilter copyWith({
    String? expansion,
    CardType? cardType,
    int? maxCost,
    bool? showParallel,
    bool clearExpansion = false,
    bool clearCardType = false,
    bool clearMaxCost = false,
  }) =>
      CardListFilter(
        expansion: clearExpansion ? null : (expansion ?? this.expansion),
        cardType: clearCardType ? null : (cardType ?? this.cardType),
        maxCost: clearMaxCost ? null : (maxCost ?? this.maxCost),
        showParallel: showParallel ?? this.showParallel,
      );

  bool matches(CardListRow row) {
    if (!showParallel && row.isParallel) return false;
    if (expansion != null && row.expansion != expansion) return false;
    if (cardType != null && row.cardType != cardType) return false;
    if (appliesCost) {
      final cost = row.cost;
      if (cost == null || cost > maxCost!) return false;
    }
    return true;
  }

  List<CardListRow> apply(List<CardListRow> rows) =>
      isEmpty ? rows : rows.where(matches).toList(growable: false);
}
