/// 盤面上のカード実体.
///
/// 総合ルール 4.3 (カードの配置状態) に対応。
///
/// ★ マスタ ([Card] / [Printing]) を複製しない ★
///   盤面には識別子だけを持ち、実データはカードマスタから引く。
///   デッキと同じく保持は printingId 単位 (決定 D11)。

library;

/// 向きを示す配置状態。総合ルール 4.3.2。
///
/// ★名前を `Orientation` にしないこと★
/// `package:loveca_core/loveca_core.dart` を丸ごと import するアプリ層で
/// Flutter の `Orientation` (portrait / landscape) と衝突する。
/// loveca_core は Flutter 非依存だが、利用側の名前空間まで壊してはいけない (CLAUDE.md §1)。
///
/// - [active] … 4.3.2.1 マスターから見て縦向き正位置
/// - [wait]   … 4.3.2.2 マスターから見て横向き
///
/// 4.3.2.3: 配置状態が指定される領域にカードが置かれる場合、既定は [active]。
enum CardOrientation { active, wait }

/// 表示面を表す状態。総合ルール 4.3.3。
///
/// - [faceUp]   … 4.3.3.1 情報が書かれている面が見える
/// - [faceDown] … 4.3.3.2 情報が書かれている面が見えない
enum FaceState { faceUp, faceDown }

/// 盤面に存在する 1 枚のカード。
class CardInstance {
  const CardInstance({
    required this.instanceId,
    required this.printingId,
    required this.cardNumber,
    required this.ownerId,
    this.orientation,
    this.face = FaceState.faceUp,
  });

  /// 盤面上でこの 1 枚を指す識別子。
  /// 同じ printingId のカードが複数枚同時に存在するため、printingId では一意にならない。
  final String instanceId;

  /// カードマスタの刷りへの参照 (決定 D11)。画像・レアリティはこちらで引く。
  final String printingId;

  /// カードマスタのカードへの参照 (総合ルール 6.1.1.2)。効果・ハート等はこちらで引く。
  final String cardNumber;

  /// ★このカードのオーナー。
  ///
  /// ★★ マスター (3.1.2「そのカードが置かれている領域が属しているプレイヤー」) は持たない ★★
  ///   マスターは所在領域から導出できるため、フィールドに持つと二重管理になる。
  ///
  ///   さらに解決領域は両プレイヤー共有で 1 つだけ (4.14.1) なので、
  ///   そこではマスターがそもそも定まらない。
  ///   8.3.14 の「解決領域の自分のカード」の絞り込みは必ずこの [ownerId] で行う。
  ///   4.1.7 (メンバーエリアやライブカード置き場以外へ移動する場合はオーナーの領域へ) と
  ///   8.4.8 (各プレイヤーが自分の分を自身の控え室へ) がオーナー基準であることを裏づける。
  final String ownerId;

  /// 向きを示す配置状態。総合ルール 4.3.2。
  ///
  /// ★★ null を許す ★★
  ///   4.3.1 は配置状態が指定されるのを「**一部の領域において**」と限定しており、
  ///   4.5.5.2 は「メンバーエリアのメンバーカードの下に重ねられているメンバーカードや
  ///   エネルギーカードは向きを示す配置状態を持ちません」と明示する。
  ///
  ///   4.3.2 の「どの状態も持たなかったりすることはありません」は、
  ///   配置状態が指定される領域の中での話であって、全カードの話ではない。
  ///
  ///   帰結として、下に重ねられたカードは
  ///     - 8.3.10 のブレード合計の対象外 (アクティブ状態になりえない)
  ///     - UI で縦向き / 横向きの回転操作を出してはいけない
  final CardOrientation? orientation;

  /// 表示面を表す状態。総合ルール 4.3.3。
  final FaceState face;

  CardInstance copyWith({
    CardOrientation? orientation,
    FaceState? face,
    bool clearOrientation = false,
  }) =>
      CardInstance(
        instanceId: instanceId,
        printingId: printingId,
        cardNumber: cardNumber,
        ownerId: ownerId,
        orientation: clearOrientation ? null : (orientation ?? this.orientation),
        face: face ?? this.face,
      );
}
