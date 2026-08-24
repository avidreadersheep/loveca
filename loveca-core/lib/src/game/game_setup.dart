/// ゲーム開始手順 6.2.1（決定 D79 / D80）.
///
/// ★★ 置き場は loveca_core である ★★
///   Phase 6 の権威サーバが同じ関数で初期状態を作る（CLAUDE.md §1 / D-D）。
///   UI 側に書くとサーバが二重実装することになる（`DeckValidator` と同じ理由 / D28）。
///
/// ## ★★ 2 段に割ってある。順序を型で守る（決定 D80）★★
///
/// ```
///   GameSetup.begin(...)            6.2.1.1 〜 6.2.1.5
///        ↓
///   ★ここに 6.2.1.6（マリガン）が入る★   ← ★M-B5 で実装する。まだ無い★
///        ↓
///   setup.dealInitialEnergy(...)    6.2.1.7   → GameState
/// ```
///
/// ★**順を入れ替えてはならない。** 6.2.1.6 はメインデッキをシャッフルするので、
///   6.2.1.7 を先に走らせると**乱数の消費順が条文と変わる**。
///
/// ★**入れ替えようがない形にしてある。** [GameSetup] のコンストラクタは private で、
///   得る道は [GameSetup.begin] だけ。遊べる [GameState] を得る道は
///   [GameSetup.dealInitialEnergy] だけ。マリガンは
///   `GameSetup -> GameSetup` として足すので、**構造上この 2 つの間にしか入らない**。
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
import 'energy_deck.dart';
import 'game_state.dart';
import 'member_area.dart';
import 'phase.dart';
import 'rng.dart';
import 'step.dart';
import 'zone.dart';

/// どのプレイヤーがどのデッキを使うか。総合ルール 6.2.1.1。
///
/// ★[Deck] は playerId を持たない（デッキ構築の産物であってゲームの産物ではない）。
/// ★一人回しでは**同じ [Deck] を両方に渡せる**。instanceId は playerId を含むので
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

/// ★★ 6.2.1.5 まで終わり、6.2.1.6（マリガン）を待っている状態 ★★
///
/// ★[stateBeforeMulligan] を盤面に出さないこと。**まだ開始手順の途中である**。
///   6.2.1.7 を経ていないのでエネルギー置き場が空で、
///   その盤面は 6.2.1 のどの時点とも一致しない。
class GameSetup {
  const GameSetup._(this.stateBeforeMulligan);

  /// ★マリガン待ちの盤面。M-B5 のマリガン UI が手札を見せるために読む。
  final GameState stateBeforeMulligan;

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

    return GameSetup._(GameState(
      // ★この並びは「先攻が先」。★UI はこの並びに依存しないこと。
      //   8.4.13 で先攻が入れ替わっても並びは変わらない（D75: 視点は viewerId で決める）。
      players: states,
      firstPlayerId: firstPlayerId,
      cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
      config: config,
    ));
  }

  /// 総合ルール 6.2.1.7「各プレイヤーはエネルギーデッキ置き場の上から 3 枚を
  /// エネルギー置き場へ移動します」。
  ///
  /// ★★ この呼び出しの**前**に 6.2.1.6（マリガン）が入る ★★
  ///   M-B5 で `GameSetup mulligan(...)` を足したら
  ///   `begin(...).mulligan(...).dealInitialEnergy(...)` の順になる。
  ///   **順を入れ替えないこと**（乱数の消費順が条文と変わる）。
  ///
  /// ★「上から 3 枚」は決定 D73 により**無作為抽出 × 3**（4.9.3「1 枚ずつ」）。
  /// ★枚数は [RuleConfig.initialEnergyOnField]。定数にしない（6.1.2）。
  /// ★[rng] は [begin] に渡したものと**同じインスタンス**を渡すこと。
  GameState dealInitialEnergy({required DeterministicRng rng}) {
    var state = stateBeforeMulligan;
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
