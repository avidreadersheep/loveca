/// 起動時に 1 回だけ組む不変のカタログ（決定 D55 / D56）.
///
/// ★★ 無効化処理を書かなくて済む形にしてある ★★
/// カタログが変わるのは取り込みが起きたときだけで、取り込みは
/// **起動ゲートでしか走らない**（決定 D56）。よって**セッション中ずっと不変**であり、
/// 無効化そのものが要らない。
///
/// これは決定 D49 が案A（`{fold(cardNumber): cardNumber}` の写像をメモリに保持）を
/// 却下したのと同じ考え方である。無効化を 1 箇所でも漏らすと
/// 「取り込んだ新しいカードが引けない」という無言の欠落になり、
/// **それは A-3 と同じ失敗の型**だから、**漏れうる構造を作らない。**
library;

import 'package:loveca_core/loveca_core.dart';

import 'card_list_row.dart';

class MasterCatalog {
  const MasterCatalog({
    required this.cards,
    required this.printings,
    required this.config,
    required this.rows,
    required this.dataVersion,
  });

  /// cardNumber -> Card。`DeckValidator` に渡す形（M2 以降が使う）。
  ///
  /// ★ここで 1 回だけ実体化する。`DeckDao.validate` / `canAdd` は呼ぶたびに
  /// `cardsByNumber()` + `printingsById()` を引き直すため、UI からセルごとに
  /// 呼ぶと 40〜60ms × 呼び出し回数が UI isolate で走る（決定 D55）。
  final Map<String, Card> cards;

  /// printingId -> Printing。同上。
  final Map<String, Printing> printings;

  /// 配信された構築条件（総合ルール 6.1.2 により置換されうるので定数にしない）。
  final RuleConfig config;

  /// 一覧の投影行（決定 D48）。
  final List<CardListRow> rows;

  final int dataVersion;

  int get cardCount => cards.length;
  int get printingCount => printings.length;

  bool get isEmpty => rows.isEmpty && cards.isEmpty;

  /// ★`imageHash` が空文字の刷りの数（`docs/UI設計メモ.md` §5-2(4)）。
  /// `build --skip-images` で作った dist だとすべて空になる。
  /// 起動サマリに出して「画像が出ないのはデータ側の事情」だと分かるようにする。
  int get rowsWithoutImage =>
      rows.where((row) => row.imageHash.isEmpty).length;
}
