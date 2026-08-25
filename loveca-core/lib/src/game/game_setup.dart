/// ゲーム開始手順 6.2.1（決定 D79 / D80）.
///
/// ★★ 置き場は loveca_core である ★★
///   Phase 6 の権威サーバが同じ関数で初期状態を作る（CLAUDE.md §1 / D-D）。
///   UI 側に書くとサーバが二重実装することになる（`DeckValidator` と同じ理由 / D28）。
///
/// ## ★★ 3 段に割ってある。順序を型で守る（決定 D80 / D93）★★
///
/// ```
///   GameSetup.begin(...)            6.2.1.1 〜 6.2.1.5
///        ↓
///   setup.mulligan(...)             6.2.1.6   ★M-B6 で実装した
///        ↓
///   setup.dealInitialEnergy(...)    6.2.1.7   → GameState
/// ```
///
/// ★**順を入れ替えてはならない。** 6.2.1.6 はメインデッキをシャッフルするので、
///   6.2.1.7 を先に走らせると**乱数の消費順が条文と変わる**。
///
/// ★**入れ替えようがない形にしてある。** [GameSetup] のコンストラクタは private で、
///   得る道は [GameSetup.begin] だけ。遊べる [GameState] を得る道は
///   [GameSetup.dealInitialEnergy] だけ。[GameSetup.mulligan] は
///   `GameSetup -> GameSetup` なので、**構造上この 2 つの間にしか入らない**。
///   ★2 回目の [GameSetup.mulligan] は [GameSetupException] で弾く
///   （6.2.1.6 は 1 回だけの手順。型では表せないので実行時に見る）。
///
/// ★★ 1 本の乱数列を通すこと ★★
///   [GameSetup.begin] と [GameSetup.dealInitialEnergy] には
///   **同じ [DeterministicRng] インスタンスを渡す**。別のものを渡すと
///   同じ seed からの再現が成立しない。
///
/// ## ★ 検証はここでしない（D28）
///
/// 6.1 のデッキ構築条件（枚数）は `DeckValidator` の仕事で、**呼び出し側が
/// 先に通す**。ここで再実装すると検証が二重になる。
///
/// ★ただし「カードマスタから引けない printingId」は別で、
///   [CardInstance.cardNumber] すら決められないため [GameSetupException] を投げる。
///   **黙って落とさない**（決定 D35）。
library;

import '../entities/card.dart';
import '../entities/deck.dart';
import 'card_instance.dart';
import 'card_move.dart';
import 'energy_deck.dart';
import 'game_action.dart';
import 'game_state.dart';
import 'member_area.dart';
import 'phase.dart';
import 'reduce.dart';
import 'rng.dart';
import 'step.dart';
import 'zone.dart';

/// どのプレイヤーがどのデッキを使うか。総合ルール 6.2.1.1。
///
/// ★[Deck] は playerId を持たない（デッキ構築の産物であってゲームの産物ではない）。
/// ★ソロでは相手側にも**同じ [Deck] を渡す**（決定 D81 / D88）。instanceId は playerId を含むので
///   衝突しない（`game_setup_test.dart` が固定している）。
class PlayerDeck {
  const PlayerDeck({required this.playerId, required this.deck});

  final String playerId;
  final Deck deck;
}

/// 開始手順に必要な材料が揃わなかった。
///
/// ★★ 6.1 の枚数違反では投げない ★★
///   それは `DeckValidator` の担当で、呼び出し側が判断する（D28）。
///   ここで投げるのは**カードを盤面に置けない**場合だけ。
class GameSetupException implements Exception {
  const GameSetupException(this.message, {this.unknownPrintingIds = const []});

  final String message;

  /// ★カードマスタから引けなかった printingId。
  ///   「未取得のカードがある」だけでは利用者が直せないので中身を運ぶ（D35）。
  final List<String> unknownPrintingIds;

  @override
  String toString() => unknownPrintingIds.isEmpty
      ? message
      : '$message: ${unknownPrintingIds.join(', ')}';
}

/// 6.2.1.6 で選ばせる 1 人ぶんの手札（決定 D93）。
///
/// ★★ UI に [GameState] からプレイヤーを引き直させないための型である ★★
///   盤面側は `BoardView.drawnPlayers` を受け取る形で同じ拘束を持っており
///   （決定 D88 / `board_player_access_test.dart`）、開始手順にも同じ形を通す。
class MulliganHand {
  const MulliganHand({required this.playerId, required this.hand});

  final String playerId;

  /// 総合ルール 6.2.1.5 で配られた手札。★並びは [GameSetup.mulligan] が
  ///   脇に置く順そのものである（下記）。
  final List<CardInstance> hand;
}

/// 6.2.1.6 で 1 人のプレイヤーが選んだカード（決定 D93）。
///
/// ★★ 選んだ**順**は結果に影響しない ★★
///   [GameSetup.mulligan] は手札のリスト順で脇に置く。クリック順に依らせると
///   同じ seed でもシャッフルの入力列が変わり、盤面が再現できなくなる。
class MulliganChoice {
  const MulliganChoice({required this.playerId, required this.instanceIds});

  final String playerId;

  /// 脇に置くカード。★空でよい（6.2.1.6「任意の枚数」）。
  final List<String> instanceIds;
}

/// ★★ 6.2.1.7 を経ていない、開始手順の途中の状態 ★★
///
/// ★[pendingState] を盤面に出さないこと。**まだ開始手順の途中である**。
///   6.2.1.7 を経ていないのでエネルギー置き場が空で、
///   その盤面は 6.2.1 のどの時点とも一致しない。
///
/// ★★ 「マリガン前」という名前にしない（決定 D93）★★
///   [mulligan] は `GameSetup -> GameSetup` なので、この値は
///   **6.2.1.5 まで**のときと**6.2.1.6 まで**のときの 2 通りを持つ。
///   片方だけを指す名前にすると、語と実体が食い違う（D88 で廃止した語と同じ形）。
class GameSetup {
  const GameSetup._(this.pendingState, this._cards, this._mulliganDone);

  /// ★開始手順の途中の盤面。6.2.1.7 を経ていない。
  final GameState pendingState;

  /// cardNumber -> Card。★[mulligan] が `reduce` を回すのに要る。
  final Map<String, Card> _cards;

  /// 6.2.1.6 を通ったか。★2 回目の [mulligan] を弾くためだけに持つ。
  final bool _mulliganDone;

  /// 6.2.1.6 で選ばせる手札。★先攻から順（[begin] が並べ替えてある）。
  ///
  /// ★★ UI はこれを**受け取る**。[pendingState] から引き直さない ★★
  ///   `loveca-ui` の走査テストが `lib/src/ui/board/` での引き直しを塞いでいる
  ///   （決定 D88 / §14-5）。開始手順にも同じ形を通す。
  List<MulliganHand> get handsForMulligan => [
        for (final player in pendingState.players)
          MulliganHand(playerId: player.playerId, hand: player.hand),
      ];

  /// 総合ルール 6.2.1.1 〜 6.2.1.5。
  ///
  /// | 手順 | 条 | すること |
  /// |---|---|---|
  /// | デッキの提示 | 6.2.1.1 | [players] の [Deck] を種別で 2 つの山に分ける |
  /// | メインデッキ | 6.2.1.2 | 置いて [rng] でシャッフル |
  /// | エネルギーデッキ | 6.2.1.3 | ★**置くだけ。シャッフルしない**（決定 D73） |
  /// | 先攻 | 6.2.1.4 | [firstPlayerId]。★2 段の決め方は呼び出し側（UI）の担当 |
  /// | 手札 | 6.2.1.5 | [RuleConfig.initialHandSize] 枚を上から。★先攻から順に |
  ///
  /// ★★ instanceId は決定的に採番する ★★
  ///   `{playerId}:{printingId}:{連番}`。`Random` を使わない。
  ///   Phase 6 で両プレイヤーが同じ id を持つ必要がある（サーバとクライアントで
  ///   採番が食い違うと、同じカードを指せない）。
  ///
  /// ★カーソルは 7.1.2 / 7.3.3 により先攻アクティブフェイズの 7.4.1。
  static GameSetup begin({
    required List<PlayerDeck> players,
    required Map<String, Card> cards,
    required Map<String, Printing> printings,
    required DeterministicRng rng,
    required String firstPlayerId,
    RuleConfig config = RuleConfig.standard,
  }) {
    if (players.length != 2) {
      throw GameSetupException(
          'プレイヤーは 2 人でなければならない (${players.length} 人)');
    }
    if (players[0].playerId == players[1].playerId) {
      throw GameSetupException('playerId が重複している: ${players[0].playerId}');
    }
    if (players.every((p) => p.playerId != firstPlayerId)) {
      throw GameSetupException('先攻 "$firstPlayerId" が参加プレイヤーに居ない');
    }

    // ★先攻から順に処理する（6.2.1.5 / 6.2.1.6 / 6.2.1.7 が「先攻から順に」）。
    final ordered = [
      players.firstWhere((p) => p.playerId == firstPlayerId),
      players.firstWhere((p) => p.playerId != firstPlayerId),
    ];

    // ★未知の刷りは 2 人分をまとめて集めてから投げる。
    //   1 人目で投げると 2 人目の不足が見えず、直すのに 2 往復要る。
    final unknown = <String>[
      for (final entry in ordered)
        ..._unknownPrintingsOf(entry.deck, cards, printings),
    ];
    if (unknown.isNotEmpty) {
      throw GameSetupException(
        'カードデータが未取得の刷りがあるため盤面に置けません',
        unknownPrintingIds: unknown,
      );
    }

    final states = <PlayerState>[];
    for (final entry in ordered) {
      final piles = _buildPiles(entry, cards, printings);

      // 6.2.1.2: メインデッキ置き場に置き、それをシャッフルします。
      var mainDeck = rng.shuffled(piles.main);

      // 6.2.1.5: メインデッキ置き場の上から initialHandSize 枚を手札へ。
      // ★足りなければあるだけ。6.1.1.1 の検証は呼び出し側の担当（D28）。
      final handSize = mainDeck.length < config.initialHandSize
          ? mainDeck.length
          : config.initialHandSize;
      final hand = mainDeck.sublist(0, handSize);
      mainDeck = mainDeck.sublist(handSize);

      states.add(PlayerState(
        playerId: entry.playerId,
        // 4.5.2.1: 左サイド / センター / 右サイドの 3 つ。
        memberAreas: [
          for (final slot in MemberAreaSlot.values) MemberArea(slot: slot),
        ],
        hand: hand,
        mainDeck: mainDeck,
        // 6.2.1.3: ★置くだけ。シャッフルしない（決定 D73 / 4.9.2）。
        energyDeck: piles.energy,
      ));
    }

    return GameSetup._(
      GameState(
        // ★この並びは「先攻が先」。★UI はこの並びに依存しないこと。
        //   8.4.13 で先攻が入れ替わっても並びは変わらない（D75: 視点は viewerId で決める）。
        players: states,
        firstPlayerId: firstPlayerId,
        cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
        config: config,
      ),
      cards,
      false,
    );
  }

  /// 総合ルール 6.2.1.6（決定 D93 / M-B6）。
  ///
  /// > 6.2.1.6 先攻プレイヤーから順に、各プレイヤーは自身の手札のカードを
  /// > 任意の枚数選んで裏向きに脇に置き、置いた枚数と同じ枚数のカードを
  /// > 自身のメインデッキ置き場の上から自身の手札に移動し、
  /// > 脇に置いたカードをメインデッキ置き場に移動し、
  /// > 1 枚以上移動した場合はシャッフルします。
  ///
  /// ## ★★ 実装は `reduce` を回す ★★
  ///
  /// [dealInitialEnergy] が `drawEnergyRandomly` を呼ぶのと同じ格で、
  /// **移動の実装を 2 つにしない**。4.1.2.1（`placedIn` / 決定 D91）の扱いが
  /// 盤面と 1 文字も違わないことが、同じ関数を通ることで保証される。
  ///
  /// | # | 条文の該当部 | アクション |
  /// |---|---|---|
  /// | 1 | 「自身の手札のカードを任意の枚数選んで裏向きに脇に置き」 | [MoveOutOfRule] × N |
  /// | 2 | ★「置いた枚数と同じ枚数のカードを…上から自身の手札に移動し」 | [MoveCard] × N |
  /// | 3 | 「脇に置いたカードをメインデッキ置き場に移動し」 | [MoveFromOutOfRule] × N |
  /// | 4 | 「1 枚以上移動した場合はシャッフルします」 | [ShuffleZone]（★N ≥ 1 のときだけ） |
  ///
  /// ★★ 手順 2 と 3 の順を入れ替えてはならない ★★
  ///   入れ替えると**脇に置いた札をそのまま引き直せてしまう**。
  ///   `game_setup_test.dart` が「新しい手札は旧手札と互いに素」で固定している。
  ///
  /// ★★ 0 枚なら乱数を 1 つも消費しない ★★
  ///   条文が「1 枚以上移動した場合は」と限っているため。
  ///   ★これは観測できる性質なので、テストが `nextInt` の回数で固定している
  ///   （決定 D90-1 と同じく、列挙ではなく実測で見る）。
  ///
  /// ★★ 脇に置く順は「手札のリスト順」である ★★
  ///   [MulliganChoice.instanceIds] の並びに依らせない。依らせると
  ///   手順 4 のシャッフルの入力列が変わり、**同じ seed でも盤面が再現できない**。
  ///
  /// ★★ 手順 3 の戻し先は一番下に固定する ★★
  ///   条文は位置を定めていない。**戻すのは N ≥ 1 のときだけで、その直後に必ず
  ///   シャッフルする**ので観測できる差は出ないが、再現性のために 1 つに決める。
  ///
  /// ★メインデッキが足りなければ**あるだけ**引く。投げない
  ///   （6.1 の検証は呼び出し側 / D28。[begin] の 6.2.1.5 と同じ扱い）。
  /// ★[rng] は [begin] に渡したものと**同じインスタンス**を渡すこと。
  GameSetup mulligan({
    required List<MulliganChoice> choices,
    required DeterministicRng rng,
  }) {
    if (_mulliganDone) {
      throw const GameSetupException('6.2.1.6 は 1 回だけの手順である（2 回目の呼び出し）');
    }

    final known = {for (final player in pendingState.players) player.playerId};
    final unknown = [
      for (final choice in choices)
        if (!known.contains(choice.playerId)) choice.playerId,
    ];
    if (unknown.isNotEmpty) {
      throw GameSetupException(
          'この盤面に居ないプレイヤーの選択がある: ${unknown.join(', ')}');
    }

    final byPlayer = <String, List<String>>{};
    for (final choice in choices) {
      if (byPlayer.containsKey(choice.playerId)) {
        throw GameSetupException('同じプレイヤーの選択が 2 つある: ${choice.playerId}');
      }
      byPlayer[choice.playerId] = choice.instanceIds;
    }

    // ★乱数を持つのは context だけ（決定 D79）。GameState にも GameAction にも入れない。
    final context = ReduceContext(cards: _cards, rng: rng);

    var state = pendingState;
    // ★★ 先攻から順に（6.2.1.6）★★
    //   [begin] が players を先攻先頭に並べてあるので、この並びがそのまま条文の順。
    //   ★引数 [choices] の並びには依存しない。
    for (final player in pendingState.players) {
      state = _mulliganOne(
        state,
        player.playerId,
        byPlayer[player.playerId] ?? const [],
        context,
      );
    }
    return GameSetup._(state, _cards, true);
  }

  /// 総合ルール 6.2.1.7「各プレイヤーはエネルギーデッキ置き場の上から 3 枚を
  /// エネルギー置き場へ移動します」。
  ///
  /// ★★ この呼び出しの**前**に 6.2.1.6（[mulligan]）が入る ★★
  ///   `begin(...).mulligan(...).dealInitialEnergy(...)` の順である。
  ///   **順を入れ替えないこと**（乱数の消費順が条文と変わる）。
  ///
  /// ★「上から 3 枚」は決定 D73 により**無作為抽出 × 3**（4.9.3「1 枚ずつ」）。
  /// ★枚数は [RuleConfig.initialEnergyOnField]。定数にしない（6.1.2）。
  /// ★[rng] は [begin] に渡したものと**同じインスタンス**を渡すこと。
  GameState dealInitialEnergy({required DeterministicRng rng}) {
    var state = pendingState;
    // ★先攻から順に。players の並びが既にその順（begin が並べ替えてある）。
    for (final player in state.players) {
      state = drawEnergyRandomly(
        state,
        player.playerId,
        state.config.initialEnergyOnField,
        rng,
      );
    }
    return state;
  }
}

/// 6.2.1.6 を 1 人ぶん行う（決定 D93）。★条文の語順そのままに並べてある。
GameState _mulliganOne(
  GameState state,
  String playerId,
  List<String> selected,
  ReduceContext context,
) {
  // ★★ 0 枚は「何もしない」である ★★
  //   条文が「1 枚以上移動した場合はシャッフルします」と限っているので、
  //   シャッフルもせず、**乱数を 1 つも消費しない**。
  if (selected.isEmpty) return state;

  final hand = cardsIn(state, playerId, Zone.hand);
  final wanted = selected.toSet();
  if (wanted.length != selected.length) {
    throw GameSetupException('同じカードが 2 回選ばれている ($playerId)');
  }

  // ★★ 脇に置く順は手札のリスト順。選んだ順ではない ★★
  //   選んだ順に依らせると、下のシャッフルの入力列が変わって再現できなくなる。
  final aside = [
    for (final card in hand)
      if (wanted.contains(card.instanceId)) card.instanceId,
  ];
  if (aside.length != wanted.length) {
    final inHand = {for (final card in hand) card.instanceId};
    final missing = wanted.difference(inHand);
    throw GameSetupException(
        '手札に無いカードが選ばれている ($playerId): ${missing.join(', ')}');
  }

  var next = state;

  // 1) 「自身の手札のカードを任意の枚数選んで裏向きに脇に置き」
  //    ★4.11.2 は非公開領域なので手札の札は既に裏向きである（4.1.2.1 / D91）。
  //      脇置きは 4 章の領域ではないので表示面を触らない。
  for (final instanceId in aside) {
    next = reduce(
      next,
      MoveOutOfRule(
        instanceId: instanceId,
        playerId: playerId,
        from: Zone.hand,
        to: OutOfRuleZone.mulliganAside,
      ),
      context: context,
    );
  }

  // 2) ★★「置いた枚数と同じ枚数のカードを自身のメインデッキ置き場の上から
  //       自身の手札に移動し」★★
  //    ★この手順が 3) より**前**にあることが条文の要点である。
  //      入れ替えると脇に置いた札をそのまま引き直せてしまう。
  //    ★5.6.1 の「引く」ではなく 6.2.1.6 の「移動」なので [DrawCards] を使わない
  //      （10.2.1 の割り込みリフレッシュを呼ばない）。
  for (var i = 0; i < aside.length; i++) {
    final deck = cardsIn(next, playerId, Zone.mainDeck);
    // ★足りなければあるだけ（6.1 の検証は呼び出し側 / D28）。
    if (deck.isEmpty) break;
    next = reduce(
      next,
      MoveCard(
        instanceId: deck.first.instanceId,
        fromPlayerId: playerId,
        from: Zone.mainDeck,
        toPlayerId: playerId,
        to: Zone.hand,
      ),
      context: context,
    );
  }

  // 3) 「脇に置いたカードをメインデッキ置き場に移動し」
  //    ★位置は条文が定めていない。直後に必ず 4) が走るので観測差は出ないが、
  //      再現性のために一番下に固定する。
  for (final instanceId in aside) {
    next = reduce(
      next,
      MoveFromOutOfRule(
        instanceId: instanceId,
        playerId: playerId,
        from: OutOfRuleZone.mulliganAside,
        to: Zone.mainDeck,
        position: ZonePosition.bottom,
      ),
      context: context,
    );
  }

  // 4) 「1 枚以上移動した場合はシャッフルします」
  //    ★ここへ来るのは aside が空でないときだけ（上の早期 return）。
  return reduce(
    next,
    ShuffleZone(playerId: playerId, zone: Zone.mainDeck),
    context: context,
  );
}

/// カードマスタから引けない printingId を集める。
List<String> _unknownPrintingsOf(
  Deck deck,
  Map<String, Card> cards,
  Map<String, Printing> printings,
) =>
    [
      for (final entry in deck.entries)
        if (entry.count > 0)
          if (printings[entry.printingId] == null ||
              cards[printings[entry.printingId]!.cardNumber] == null)
            entry.printingId,
    ];

/// 2 つの山。総合ルール 6.1.1.1（メインデッキ）/ 6.1.1.3（エネルギーデッキ）。
typedef _Piles = ({List<CardInstance> main, List<CardInstance> energy});

/// [Deck] を種別で 2 つの山に分け、決定的な instanceId を振る。
///
/// ★6.1.1.1 はメインデッキを「メンバー 48 + ライブ 12」と定め、
///   6.1.1.3 はエネルギーデッキを別に定める。**種別が山を決める。**
_Piles _buildPiles(
  PlayerDeck entry,
  Map<String, Card> cards,
  Map<String, Printing> printings,
) {
  final main = <CardInstance>[];
  final energy = <CardInstance>[];

  // ★printingId ごとの連番。同じ printingId が 2 つの DeckEntry に分かれていても
  //   通し番号が続くので id が衝突しない。
  final serial = <String, int>{};

  for (final deckEntry in entry.deck.entries) {
    if (deckEntry.count <= 0) continue;
    final printing = printings[deckEntry.printingId]!;
    final card = cards[printing.cardNumber]!;

    for (var i = 0; i < deckEntry.count; i++) {
      final n = (serial[deckEntry.printingId] ?? 0) + 1;
      serial[deckEntry.printingId] = n;

      final instance = CardInstance(
        // ★決定的採番（決定 D79）。Random を使わない。
        instanceId: '${entry.playerId}:${deckEntry.printingId}:$n',
        printingId: deckEntry.printingId,
        cardNumber: printing.cardNumber,
        ownerId: entry.playerId,
        // 4.8.2 / 4.9.2 はどちらも非公開領域。表示面の既定は裏向き。
        face: FaceState.faceDown,
      );

      if (card.cardType == CardType.energy) {
        energy.add(instance);
      } else {
        main.add(instance);
      }
    }
  }
  return (main: main, energy: energy);
}
