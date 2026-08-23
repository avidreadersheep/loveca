/// 秘匿（redact）.
///
/// 総合ルール 4.1.2 / 4.3.3 に対応。
/// CLAUDE.md §1 (D-D)「Phase 6 の権威サーバが同じ `reduce` / `redact` を
/// コピーゼロで再利用する」を満たすための関数。
///
/// 権威サーバは完全な [GameState] を保持し、各クライアントへは
/// `redact(state, viewerId)` の結果だけを配る。
///
/// ★★ 枚数は必ず残す ★★
///   4.1.2.2「領域が公開であるか非公開であるかにかかわらず、
///   それぞれの領域にあるカードの枚数は、すべてのプレイヤーがいつでも
///   確認することができます」
///   → カードの器は消さず、中身だけ差し替える。
///
/// ★★ 秘匿した盤面で集計を走らせないこと ★★
///   `LiveAggregator` はカードマスタを `cardNumber` で引くため、
///   秘匿されたカードは**すべて未知カードとして除外**される。
///   集計は必ず秘匿**前**の [GameState] に対して行い、数値だけを配る。
///   （これは権威サーバの設計としても正しい。クライアントに相手の
///   ブレード合計を計算させる根拠が無い。）

library;

import 'card_instance.dart';
import 'game_state.dart';

/// [viewerId] から見える形に [state] を秘匿する。
///
/// ★冪等。`redact(redact(s, v), v) == redact(s, v)`。
///
/// ## 秘匿の範囲
///
/// | 領域 | 秘匿 | 根拠 |
/// |---|---|---|
/// | 4.8 メインデッキ置き場 | **全員から** | 4.8.2「すべてのプレイヤーに対して非公開領域」 |
/// | 4.9 エネルギーデッキ置き場 | **全員から** | 4.9.2 同上 |
/// | 4.11 手札 | 他プレイヤーからのみ | 4.11.2「自分の手札のカードは自分のみが自由に確認することができます」 |
/// | 4.6 ライブカード置き場 | 裏向きを他プレイヤーから | 4.6.2 / 8.2.2 |
/// | 4.13 除外領域 | 裏向きを**全員から** | 4.3.3.2 / 4.13.2 |
/// | 6.2.1.6 脇置き（ルール外） | 他プレイヤーからのみ | 裏向きだが本人が選んだ |
/// | フリーエリア（ルール外） | 裏向きを他プレイヤーから | ルール外。ライブカード置き場に揃える |
/// | 4.5 / 4.7 / 4.10 / 4.12 / 4.14 | 秘匿しない | いずれも公開領域 |
///
/// ### ★ ライブカード置き場と除外領域で扱いが割れる理由（決定 D37）
///
/// 4.3.3.2 は「**原則として**、裏向きのカードの情報はどのプレイヤーも
/// 見ることができません」と書く。「原則として」の留保が例外を許している。
///
/// - **ライブカード置き場**は 8.2.2 / 8.2.4 により**本人が手札から選んで置く**行為であり、
///   本人が内容を知っていることは条文上自明。よってオーナーからは隠さない。
/// - **除外領域**の裏向きは効果由来であり、4.13.2 は「特に指示がないかぎり
///   取り除かれたカードは表向きに置かれます」と定める。裏向きになるのは効果が
///   そう指示したときだけで、**誰が内容を知るかを条文は定めていない**。
///   よって既定の 4.3.3.2 に従い全員から隠す。
///
/// この非対称は**条文の構造に由来する**ものであって実装の都合ではない。
/// メンバーエリア (4.5.3) は公開領域なので、下に重ねられたカード (4.5.5) も隠さない。
GameState redact(GameState state, String viewerId) {
  final players = [
    for (final player in state.players) _redactPlayer(player, viewerId),
  ];

  // 4.14.2: 解決領域は公開領域。4.14.1 により両プレイヤー共有で 1 つだけ。
  // 中身も順序も隠さない。
  return state.copyWith(players: players);
}

PlayerState _redactPlayer(PlayerState player, String viewerId) {
  final isViewer = player.playerId == viewerId;
  final id = player.playerId;

  return player.copyWith(
    // 4.11.2: 自分の手札は自分のみが自由に確認できる。
    hand: isViewer ? player.hand : _hideAll(player.hand, id, 'hand'),

    // ★4.8.2 / 4.9.2: すべてのプレイヤーに対して非公開。オーナーからも隠す。
    mainDeck: _hideAll(player.mainDeck, id, 'mainDeck'),
    energyDeck: _hideAll(player.energyDeck, id, 'energyDeck'),

    // 4.6.2: 公開領域だが一時的に裏向きに置かれることがある (8.2.2 / 8.2.4)。
    // 8.3.4 で表向きにされるまで、他プレイヤーからは隠す。
    liveStage: isViewer
        ? player.liveStage
        : _hideFaceDown(player.liveStage, id, 'liveStage'),

    // ★4.13.2 / 4.3.3.2: 裏向きは全員から隠す（上記 D37 の理由）。
    exile: _hideFaceDown(player.exile, id, 'exile'),

    // 6.2.1.6: 裏向きに脇に置く。本人は選んで置いたので知っている。
    mulliganAside: isViewer
        ? player.mulliganAside
        : _hideAll(player.mulliganAside, id, 'mulliganAside'),

    // ルール外のフリーエリア。ライブカード置き場と同じ扱いに揃える。
    freeArea: isViewer
        ? player.freeArea
        : _hideFaceDown(player.freeArea, id, 'freeArea'),

    // ---- 以下は秘匿しない ----
    // 4.5.3  メンバーエリア      … 公開領域。下に重ねられたカードも含めて隠さない
    // 4.7.2  エネルギー置き場    … 公開領域
    // 4.10.2 成功ライブカード置き場 … 公開領域
    // 4.12.2 控え室              … 公開領域
  );
}

List<CardInstance> _hideAll(
  List<CardInstance> cards,
  String playerId,
  String zoneKey,
) =>
    [
      for (var i = 0; i < cards.length; i++)
        _hide(cards[i], playerId, zoneKey, i),
    ];

List<CardInstance> _hideFaceDown(
  List<CardInstance> cards,
  String playerId,
  String zoneKey,
) =>
    [
      for (var i = 0; i < cards.length; i++)
        if (cards[i].face == FaceState.faceDown)
          _hide(cards[i], playerId, zoneKey, i)
        else
          cards[i],
    ];

/// 1 枚を秘匿する。
///
/// ★★ [CardInstance.instanceId] も差し替える ★★
///   元の instanceId を残すと、相手は**領域を跨いでカードを追跡できる**。
///   4.8.2 によりメインデッキ置き場は順番が管理されるため、
///   「手札に入った 1 枚がデッキの何番目に戻ったか」まで分かってしまい、
///   後で公開された時点で遡って推定できる。
///   位置由来のプレースホルダに差し替えることで追跡を断ち、
///   同時に [redact] の冪等性も保つ（同じ入力なら同じ id になる）。
///
/// ★[CardInstance.ownerId] は残す。どの領域が誰のものかは公開情報であり、
///   共有の解決領域 (4.14.1) では絞り込みに要る。
///
/// ★向き (4.3.2) と表示面 (4.3.3) も残す。どちらも物理的に見える情報で、
///   縦向きか横向きか、表か裏かは秘匿の対象ではない。
CardInstance _hide(
  CardInstance card,
  String playerId,
  String zoneKey,
  int index,
) =>
    CardInstance(
      instanceId: 'redacted:$playerId:$zoneKey:$index',
      printingId: '',
      cardNumber: '',
      ownerId: card.ownerId,
      orientation: card.orientation,
      face: card.face,
      isRedacted: true,
    );
