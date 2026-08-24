/// 盤面の状態（決定 D53 / D75 / D77 / D79 / D81）.
///
/// ★★ [GameStore.dispatch] が `reduce` を呼ぶ唯一の場所である ★★
/// `state/store.dart` の doc が「Phase 3b では `GameStore.dispatch` が `reduce` を
/// 呼ぶ唯一の場所になり、Phase 6 で『サーバへ action を送って state を受け取る』に
/// 差し替える点もそこ 1 箇所になる」と定めている。**画面から `reduce` を呼ばない。**
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない（決定 D55）★★
/// この Store は `Deck` と `MasterCatalog` を**値として受け取る**だけで、
/// リポジトリも DB も持たない。**一人回しは保存も同期もしない**ので、
/// 盤面が DB へ行く用事がそもそも無い。
///
/// ★★ 視点（[BoardState.viewerId]）は `GameAction` ではない ★★
/// 盤面の向きは UI の状態であって、ゲームの状態ではない。
/// `reduce` を通さず [GameStore.setViewer] で変える。
///
/// ★★ seed は [GameState] にも [GameAction] にも持たせない（決定 D79）★★
/// `ReduceContext` にだけ置く。ここが `SeededRng` を 1 つ持ち、
/// 盤面セッションのあいだ**同じインスタンスを使い続ける**。
///
/// ★★ `redact` を掛けない（決定 D77）★★
/// 一人回しは 1 人が両プレイヤーを操作するので、掛けると相手側を操作できなくなる。
/// **4.8 / 4.9 の秘匿は盤面 UI の責務**であり、この Store は隠さない。
/// 隠すのは `ui/board/hidden_pile.dart`（枚数しか受け取らない形）。
library;

import 'package:loveca_core/loveca_core.dart';

import 'board_notice.dart';
import 'store.dart';

/// 盤面 1 セッションぶんの状態。
class BoardState {
  const BoardState({
    required this.session,
    required this.viewerId,
    required this.seed,
    this.notices = const [],
  });

  /// 盤面と履歴（決定 D36）。★M-B1 では履歴を積まない操作しか無い。
  final GameSession session;

  /// ★★ 盤面の向きを決める唯一の値（決定 D75）★★
  /// 下段が常にこのプレイヤー。鏡像も袖の割り当ても手札の帯もここから決まる。
  ///
  /// ★手番（`turnPlayerOf`）とは別物。混ぜると 8.4.13 の入れ替え後に手番が誤る。
  final String viewerId;

  /// この盤面を作った seed（決定 D79）。★画面に出す。
  final int seed;

  /// 盤面セッションのあいだ出し続ける注記。
  final List<BoardNotice> notices;

  GameState get state => session.state;

  /// [viewerId] の相手。★2 人ちょうどなので必ず定まる。
  String get opponentId =>
      state.players.firstWhere((p) => p.playerId != viewerId).playerId;

  BoardState copyWith({GameSession? session, String? viewerId}) => BoardState(
        session: session ?? this.session,
        viewerId: viewerId ?? this.viewerId,
        seed: seed,
        notices: notices,
      );
}

class GameStore extends Store<BoardState> {
  GameStore({
    required GameState initialState,
    required String viewerId,
    required int seed,
    required Map<String, Card> cards,
    required DeterministicRng rng,
    List<BoardNotice> notices = const [],
  })  : _context = ReduceContext(cards: cards, rng: rng),
        super(BoardState(
          session: GameSession(state: initialState),
          viewerId: viewerId,
          seed: seed,
          notices: notices,
        ));

  /// ★乱数はセッションのあいだ同じインスタンスを使い続ける。
  ///   毎回作り直すと同じ札が出続ける。
  final ReduceContext _context;

  /// ★★ `reduce` を呼ぶ唯一の場所 ★★
  ///
  /// ★`GameSession.apply` は現在の状態を履歴に積んでから `reduce` する
  /// （`reduce.dart` の `SessionReduce`）ので、undo（M-B4）がそのまま効く。
  ///
  /// ★複数のアクションを 1 操作として戻したい場合（11.10 / 11.11 の補助コマンド、
  /// ライブカードセット）は、ここではなく `reduce` を N 回回して
  /// `GameSession.record` を 1 回だけ呼ぶ（決定 D78 / M-B5）。
  void dispatch(GameAction action) {
    state = value.copyWith(session: value.session.apply(action, context: _context));
  }

  /// 盤面の向きを変える（決定 D75）。★`GameAction` ではない。
  void setViewer(String playerId) {
    if (playerId == value.viewerId) return;
    state = value.copyWith(viewerId: playerId);
  }

  /// 4.1.2.2「枚数はいつでも全プレイヤーが確認できます」。
  ///
  /// ★★ 非公開領域（4.8 / 4.9）について盤面が答えてよいのはこれだけ ★★
  /// 中身を返す getter をここに足さないこと（決定 D77）。
  int countIn(String playerId, Zone zone) =>
      cardsIn(value.state, playerId, zone).length;

  /// エネルギーデッキから 1 枚出せるか（4.9.2 / 決定 D73）。
  ///
  /// ★★ 出せないときにボタンを消さず、無効にして理由を出すため ★★
  /// エネルギーは控え室を経由しない閉ループ（10.5.4）なので、
  /// メインデッキのようなリフレッシュ（10.2）が無い。6.1.1.3 の 12 枚を
  /// 使い切ると出せなくなる。**黙って何も起きない形にしない。**
  bool canDrawEnergy(String playerId) =>
      countIn(playerId, Zone.energyDeck) > 0;
}
