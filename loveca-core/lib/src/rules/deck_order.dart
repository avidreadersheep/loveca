/// デッキの並びの規則（決定 D99）.
///
/// ★★ これは条文由来ではない ★★
/// 総合ルールはデッキの中の**並び順を規定していない**。6.1.1 / 6.1.1.3 が定めるのは
/// 枚数であって順序ではなく、10.2.3 のシャッフルは「順番を無作為にする」ものである。
/// したがってここに書かれている降順・昇順・区分の順は**すべて表示の都合**であり、
/// **条番号を付けてはならない**（CLAUDE.md §1「根拠のない数値・条件をコードに書かない」）。
/// 唯一条文に触れているのは**区分そのもの**（メンバー / ライブ / エネルギー）で、
/// これは **総合ルール 2.2.2**（`CardType` の doc が持つ条番号）である。
/// ★区分を `card_type` から導出することは決定 D41。
/// ★**6.1 ではない。**6.1 はデッキ構成（枚数）の条であって区分の定義ではない
///   （2026-08-27 の自己検査で 6.1 と書いていたのを直した）。
///
/// ★★ ただし「区分の順序」は 2.2.2 由来ではない ★★
/// 2.2.2 が定めているのは**3 つの区分が存在すること**であって、並べる順ではない。
/// ★条文が 3 つを挙げる順は「ライブ」「メンバー」「エネルギー」で、
///   下の [_sectionRank]（メンバー → ライブ → エネルギー）とは**違う**。
///   ★**条文順に見えるように書き換えないこと。**条文順に揃える根拠が無いのと同じだけ、
///   条文順から外れていることを不整合と読む根拠も無い。
/// 実装がメンバーを先頭に置くのは**表示の判断**である —— メインデッキ 60 枚のうち
/// 48 枚がメンバーなので（6.1.1.1）、いちばん長い列を先頭に置いている。
/// ★区分を「デッキの区画」として見るなら 6.1.1.1 / 6.1.1.3 が該当するが、
///   **これも順序を与えない**（上のとおり枚数の条である）。
/// ★これは `docs/相談役への引き継ぎ.md` §4-7（条文の記述と実装判断を混ぜない）の型である。
///
/// ★★ なぜ `loveca_core` に置くか ★★
/// 呼ぶのは 2 つある。
/// 1. `loveca-ui` —— 新規デッキ・「規則順に戻す」・カード追加の挿入位置
/// 2. `loveca-db` —— `schemaVersion` 3 の backfill（決定 D65 / D99）
///
/// 決定 D99 は backfill を SQL ではなく Dart で書くと定めた。SQL で書くと
/// **規則が「Dart の比較器」と「移行の SQL」の 2 箇所に載る**からである。
/// 2 箇所から呼ばれる以上、置き場は両者が依存する `loveca_core` しかない（D-D / 決定 D28）。
///
/// ★★ マスタを引く責務はここに持たせない ★★
/// `loveca_core` は `printingId -> Card` の索引を持たない（持つのは `MasterData` の
/// 利用側であり、UI は `MasterCatalog`、DB は `cards` / `printings` テーブルである）。
/// 引き方が違うだけで規則は同じなので、**引いた結果**（[DeckOrderKey]）を受け取る。
library;

import '../entities/card.dart';
import '../entities/deck.dart';

/// 並びを決めるのに要る値だけを取り出したもの（決定 D99）.
///
/// ★[cardType] が null なのは「マスタに無い刷り」である（決定 D35）。
/// 黙って捨てないので、並びの上でも居場所が要る。→ **末尾の区分**に置く。
class DeckOrderKey {
  const DeckOrderKey({required this.cardType, this.cost, this.score});

  /// マスタに無ければ null（決定 D35）。
  final CardType? cardType;

  /// メンバーの並びに使う。★`int?` なので null がありうる（`Card.cost`）。
  final int? cost;

  /// ライブの並びに使う。★同上（`Card.score`）。
  final int? score;

  /// マスタに無い刷りのための鍵。
  static const unknown = DeckOrderKey(cardType: null);
}

/// printingId から [DeckOrderKey] を引く。★引き方は呼び出し側の責務（上記）。
typedef DeckOrderKeyLookup = DeckOrderKey Function(String printingId);

/// 区分の順（決定 D99 の段 1）。★未知は末尾。
int _sectionRank(CardType? type) => switch (type) {
      CardType.member => 0,
      CardType.live => 1,
      CardType.energy => 2,
      null => 3,
    };

/// 数値を**降順**に比べる。★null は末尾（決定 D99）。
///
/// ★★ null を先頭に置かない理由 ★★
/// 降順で素直に書くと null が先頭に来る。`Card.cost` / `Card.score` は `int?` で、
/// 実データでは現在 0 件だが（`docs/UI設計メモ.md` §12-2 事実 2）、
/// **新商品で現れたときに黙って先頭へ来る**のは事故である。
int _descendingNullsLast(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// 2 つの刷りを規則順で比べる（決定 D99）.
///
/// 段 1 区分 → 段 2 区分ごとの軸 → 段 3 `printingId` 昇順。
///
/// ★★ 段 3 を落とさないこと ★★
/// 同値が多い（実データで `cost` 4 が 251 種 / `score` 5 が 39 種）。
/// 副次キーが無いと**同じデッキを 2 回並べたときに順が違いうる**。
///
/// ★★ カード名を副次キーにしない ★★
/// `CLAUDE.md` §5-(5) の表記ゆれ（`みらくらぱーく！` / `みらくらぱーく!`）を
/// 並び順が受ける。`printingId` は正規化済みで一意である。
int compareDeckOrder(String a, String b, DeckOrderKeyLookup keyOf) {
  final ka = keyOf(a);
  final kb = keyOf(b);

  final bySection = _sectionRank(ka.cardType).compareTo(_sectionRank(kb.cardType));
  if (bySection != 0) return bySection;

  // ★段 2 は区分ごとに軸が違う。区分は上で一致しているのでどちらを見てもよい。
  final byAxis = switch (ka.cardType) {
    CardType.member => _descendingNullsLast(ka.cost, kb.cost),
    CardType.live => _descendingNullsLast(ka.score, kb.score),
    // ★エネルギーに軸が無いのは要判断ではなく事実である。
    //   実データ 567 種すべて cost / score / blade_count / hearts / stats が
    //   null または空（`docs/UI設計メモ.md` §12-2 事実 1）。
    CardType.energy => 0,
    // ★マスタに無いので何も引けない（決定 D35）。
    null => 0,
  };
  if (byAxis != 0) return byAxis;

  return a.compareTo(b);
}

/// 規則順に並べ替えた新しいリストを返す（決定 D99）.
///
/// ★元のリストは変更しない。★`sort` は安定ではないので、
/// 段 3 の `printingId` 昇順が結果の一意性を担保している（上記）。
List<DeckEntry> sortedByDeckOrder(
  List<DeckEntry> entries,
  DeckOrderKeyLookup keyOf,
) =>
    [...entries]
      ..sort((a, b) => compareDeckOrder(a.printingId, b.printingId, keyOf));

/// [printingId] を規則順に差し込む位置（決定 D99）.
///
/// 定義は**比較器で自分より後ろに来る最初の札の直前**。見つからなければ末尾。
///
/// ★★ 手動順が混ざったデッキでは「規則順の正しい位置」とは限らない ★★
/// `ord` が保存される以上、利用者が並べ替えた順は永続する。規則順に並んでいない
/// リストに対して、この関数は**挿入位置を 1 つ決めているだけ**である。
/// それでも末尾に足すより良い —— 末尾だと区分をまたいで
/// 「メンバーの列の下にライブが来て、その下にまたメンバー」になる。
/// ★正しい位置が要るなら「規則順に戻す」を押す（決定 D99）。
int deckOrderInsertionIndex(
  List<DeckEntry> entries,
  String printingId,
  DeckOrderKeyLookup keyOf,
) {
  for (var i = 0; i < entries.length; i++) {
    if (compareDeckOrder(printingId, entries[i].printingId, keyOf) < 0) return i;
  }
  return entries.length;
}
