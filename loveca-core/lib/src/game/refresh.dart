/// リフレッシュ.
///
/// 総合ルール 10.2 に対応。
///
/// ★★ リフレッシュだけはチェックタイミングを待たない ★★
///   10.1.2「ルール処理は、**リフレッシュ (10.2) を除き**、チェックタイミングに
///   おいてのみ条件を満たしているかを確認し、満たされている場合に実行されます」
///
///   10.2.1「リフレッシュはチェックタイミングにかぎらず、ゲーム中の任意の時点で
///   いずれかのプレイヤーが条件を満たしている場合に実行します。
///   それがなんらかの処理の途中である場合、**その処理を一時中断し、リフレッシュを
///   実行した後に、その処理の続きを実行します**」
///
///   → 他のルール処理 (10.3〜10.6) とは実装場所を分ける。
///     整理コマンドは `rule_process.dart`、こちらは処理の途中から割り込む。

library;

import 'card_instance.dart';
import 'card_move.dart';
import 'game_state.dart';
import 'rng.dart';
import 'zone.dart';

/// リフレッシュの実行。総合ルール 10.2。
class Refresher {
  const Refresher({required this.rng});

  /// シャッフル (10.2.3) に使う乱数源。★実装は注入する。
  final DeterministicRng rng;

  /// 総合ルール 10.2.2.1: メインデッキ置き場にカードが無く、控え室にカードがある。
  bool needsRefresh(GameState state, String playerId) =>
      cardsIn(state, playerId, Zone.mainDeck).isEmpty &&
      cardsIn(state, playerId, Zone.waitingRoom).isNotEmpty;

  /// 総合ルール 10.2.2.2: メインデッキ置き場を上から見る指示があり、
  /// 枚数が指示された数値未満である。
  bool needsRefreshForLook(GameState state, String playerId, int count) =>
      cardsIn(state, playerId, Zone.mainDeck).length < count &&
      cardsIn(state, playerId, Zone.waitingRoom).isNotEmpty;

  /// 1 人分のリフレッシュを実行する。総合ルール 10.2.3。
  ///
  /// 「リフレッシュを行うプレイヤーは、自身の控え室のカードを**非公開状態にして
  /// シャッフル**し、すべて自身のメインデッキ置き場に移動します。このとき、
  /// メインデッキ置き場にカードがある場合、それらのカードの**下**に移動します」
  ///
  /// ★条件を満たしていなくても呼べば実行する。判定は [needsRefresh] 側の責務。
  GameState refreshPlayer(GameState state, String playerId) {
    final waitingRoom = cardsIn(state, playerId, Zone.waitingRoom);
    if (waitingRoom.isEmpty) return state;

    // 非公開状態にする (4.8.2 によりメインデッキ置き場は非公開領域)。
    // ★あわせて向きを落とす。4.3.1 により配置状態が指定されるのは一部の領域だけで、
    //   メインデッキ置き場は含まれない。
    final hidden = [
      for (final card in waitingRoom)
        card.copyWith(face: FaceState.faceDown, clearOrientation: true),
    ];

    final shuffled = rng.shuffled(hidden);

    // ★「それらのカードの下に移動します」= 既存の末尾へ追加。
    final mainDeck = cardsIn(state, playerId, Zone.mainDeck);
    final next = replaceZone(
      state,
      playerId,
      Zone.mainDeck,
      insertInto(mainDeck, shuffled, ZonePosition.bottom),
    );
    return replaceZone(next, playerId, Zone.waitingRoom, const []);
  }

  /// 条件を満たすすべてのプレイヤーのリフレッシュを実行する。
  ///
  /// ★総合ルール 10.2.4「両方のプレイヤーが同時にリフレッシュを行う条件を
  ///   満たしている場合、**現在のターンの先攻プレイヤーが先に**リフレッシュを
  ///   実行します」→ `GameState.firstPlayerId` を参照する。
  GameState refreshIfNeeded(GameState state) {
    var next = state;
    for (final playerId in _refreshOrder(state)) {
      if (needsRefresh(next, playerId)) {
        next = refreshPlayer(next, playerId);
      }
    }
    return next;
  }

  /// 10.2.4 の順序。先攻プレイヤーが先。
  List<String> _refreshOrder(GameState state) {
    final first = state.firstPlayerId;
    return [
      first,
      for (final player in state.players)
        if (player.playerId != first) player.playerId,
    ];
  }

  /// メインデッキ置き場の一番上から [count] 枚取り出す。
  ///
  /// ★★ 途中でデッキが尽きたらその場でリフレッシュして残り回数を続行する ★★
  ///   10.2.1 の「その処理を一時中断し、リフレッシュを実行した後に、
  ///   その処理の続きを実行します」がここ。
  ///
  ///   8.3.11 のエール (合計ブレード数と同じ回数の繰り返し) と
  ///   7.6.2 のドローが共有する原始操作。チェックタイミングを待たない。
  ///
  /// ★控え室も空でリフレッシュできない場合は、取れた分だけを返して終了する。
  ///   無限ループを避けるため。取れた枚数は [Taken.drawn] の長さで分かる。
  Taken takeFromMainDeck(GameState state, String playerId, int count) {
    var next = state;
    final drawn = <CardInstance>[];
    var refreshCount = 0;

    for (var i = 0; i < count; i++) {
      var deck = cardsIn(next, playerId, Zone.mainDeck);

      if (deck.isEmpty) {
        // ★10.2.1: 処理を一時中断してリフレッシュし、続きを実行する。
        if (!needsRefresh(next, playerId)) break; // 控え室も空。続行できない
        next = refreshPlayer(next, playerId);
        refreshCount++;
        deck = cardsIn(next, playerId, Zone.mainDeck);
        if (deck.isEmpty) break;
      }

      // 4.8.2 / index 0 が一番上。
      drawn.add(deck.first);
      next = replaceZone(next, playerId, Zone.mainDeck, deck.sublist(1));
    }

    return Taken(state: next, drawn: drawn, refreshCount: refreshCount);
  }
}

/// [Refresher.takeFromMainDeck] の結果。
class Taken {
  const Taken({
    required this.state,
    required this.drawn,
    this.refreshCount = 0,
  });

  final GameState state;

  /// 取り出せたカード。上から順。
  final List<CardInstance> drawn;

  /// この処理の途中で割り込んだリフレッシュの回数 (10.2.1)。
  final int refreshCount;

  /// 指示された枚数を取り切れたか。
  bool wasInterrupted(int requested) => drawn.length < requested;
}
