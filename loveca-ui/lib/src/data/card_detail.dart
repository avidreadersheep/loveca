/// カード詳細の材料（R5 / 決定 D55 / `docs/UI設計メモ.md` §2-2）.
///
/// ★★ このクラスは `LovecaDatabase` を知らない ★★
/// 材料は起動時に組んだ `MasterCatalog` の中にすべてある。
/// `DeckCatalogView`（`deck_repository.dart`）と同じ考え方で、
/// **「DB へ行かない」を規約ではなく型で示すために分けてある。**
///
/// ★★ 索引はセッション中ずっと不変（決定 D56）★★
/// 取り込みは起動ゲートでしか走らないので、**無効化処理そのものが要らない。**
/// 起動時に 1 回だけ組み、`AppEnvironment` が配る。
library;

import 'package:loveca_core/loveca_core.dart';

import 'master_catalog.dart';

/// 1 つの刷りについて、詳細画面が要るものを束ねた値。
class CardDetail {
  const CardDetail({
    required this.card,
    required this.printing,
    required this.siblings,
  });

  /// ルール上のカード（cardNumber 単位 / 決定 D11）。
  final Card card;

  /// いま見ている刷り（printingId 単位 / 決定 D11）。
  final Printing printing;

  /// ★**同じ cardNumber の刷り。自分を含み、`printingId` 昇順。**
  ///
  /// 「代表 1 枚」という概念は誤りとして廃止済み（CLAUDE.md §5-(4)）ので、
  /// **通常刷りが複数ありうる**。実データの分布は 1 刷り 1,108 種 / 2 刷り 465 種 /
  /// 3 刷り 51 種 / **4 刷り 84 種**。
  final List<Printing> siblings;

  /// ほかの刷りがあるか（切替を出すかの判断）。
  bool get hasOtherPrintings => siblings.length > 1;
}

/// カタログから [CardDetail] を引く。★DB へ行かない（決定 D55）。
class CardDetailView {
  CardDetailView(MasterCatalog catalog)
      : _cards = catalog.cards,
        _printings = catalog.printings,
        // ★cardNumber -> その刷り。起動時に 1 回だけ組む。
        //   `printings` は 2,527 件なので線形に舐めるのは 1 回で十分。
        _byCardNumber = _indexByCardNumber(catalog.printings);

  final Map<String, Card> _cards;
  final Map<String, Printing> _printings;
  final Map<String, List<Printing>> _byCardNumber;

  static Map<String, List<Printing>> _indexByCardNumber(
    Map<String, Printing> printings,
  ) {
    final out = <String, List<Printing>>{};
    for (final printing in printings.values) {
      (out[printing.cardNumber] ??= []).add(printing);
    }
    // ★並びを決定的にする。Map の反復順に依存させない。
    for (final list in out.values) {
      list.sort((a, b) => a.printingId.compareTo(b.printingId));
    }
    return out;
  }

  /// ★★ 見つからなければ null を返す。空の詳細を作らない ★★
  ///
  /// **いまこの経路は UI から到達しない。** R3 / R4 の一覧セルは
  /// `MasterCatalog.rows`（= `printings JOIN cards`）から作られるので、
  /// 必ずカタログに在る printingId しか渡ってこない。
  ///
  /// ★★ それでも null を返せる形にし、テストで固定してある理由 ★★
  /// **到達させる予定のある経路が 2 つある。**
  ///
  /// | いつ | どこから未知の printingId が来るか |
  /// |---|---|
  /// | **Phase 4（同期）** | 他端末で新しいマスタを使って作ったデッキが同期で降ってくる。`Deck.masterDataVersion`（P5）と決定 D35 は**まさにこれを検出するため**にある。M4 のデッキペインは未知の刷りを「表示できないカード」として読み取り専用で出しており、**そこから詳細を開けるようにした瞬間に到達する** |
  /// | **M6（共有形式インポート / §2-5）** | cardNumber → printingId の逆写像が一意でなく、マスタに無い cardNumber もありうる |
  ///
  /// ★**このメソッドと対応するテストを消してよいのは、上の 2 つが
  /// 「未知の printingId を持ち込まない」と確定したときだけ。**
  /// どちらも未決なので残す（「念のため」ではない）。
  CardDetail? of(String printingId) {
    final printing = _printings[printingId];
    if (printing == null) return null;
    final card = _cards[printing.cardNumber];
    if (card == null) return null;

    return CardDetail(
      card: card,
      printing: printing,
      siblings: _byCardNumber[printing.cardNumber] ?? [printing],
    );
  }
}
