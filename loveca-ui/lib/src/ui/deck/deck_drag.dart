/// デッキ編集で運ぶ値（M4）.
///
/// ★★ `sealed` にして、落下先で網羅的に扱う ★★
/// 「一覧から来た」と「デッキの行から来た」で**意味が違う**（足す / 動かす）。
/// 1 つの型に `bool fromDeck` を持たせると、片方の分岐を書き忘れても
/// コンパイルが通ってしまう。決定 D53 と同じ理由。
library;

sealed class DeckDrag {
  const DeckDrag(this.printingId);

  final String printingId;
}

/// 一覧ペインのセルから。落とすと**足す**。
final class CatalogCardDrag extends DeckDrag {
  const CatalogCardDrag(super.printingId);
}

/// デッキの行から。落とすと**動く**（行の上）か**外れる**（ゴミ箱）。
final class DeckEntryDrag extends DeckDrag {
  const DeckEntryDrag(super.printingId);
}
