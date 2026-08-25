/// R2 から R7 へ入る道（決定 D81 / D88 / 盤面設計メモ §9 / §14）.
///
/// ★★ 6.2.1 を走らせるのはここ 1 箇所である ★★
/// `GameSetup.begin` → `mulligan`（6.2.1.6）→ `dealInitialEnergy`。
/// **2 箇所で走らせない。** 走らせる場所が増えると
/// 「seed をどこで作ったか」「マリガンをどこに挟むか」が分岐する。
///
/// ★★ 押したデッキが自分側になる（決定 D81）★★
/// `viewerId` の既定が自明になり、「どちらが自分側か」をダイアログで決めずに済む。
/// D75 が `viewerId` を 1 つだけ持つと定めた形と素直に噛み合う。
///
/// ★★ 入口は R2 のデッキメニュー 2 本（決定 D88 / D81 の訂正）★★
/// 「ソロ」と「ローカル対戦」。D81 は 1 本と書いていたが、**モードは開始時に選ぶ**
/// （あとから切り替えると 6.2.1 をやり直すことになり「同じ seed で同じ盤面」が崩れる）。
///
/// ★★ 入口を R3 に作らない ★★
/// R3 は未保存の編集がありうるので、その上に R7 を積むと
/// 「保存していない構築で回っている」状態が生まれる
/// （R6 の入口を R2 だけにしたのと同じ理由）。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/app_scope.dart';
import '../../state/board_mode.dart';
import '../../state/board_notice.dart';
import 'board_mulligan_dialog.dart';
import 'board_page.dart';
import 'board_start_dialog.dart';

/// 盤面を開始する。★[deck] が自分側。
Future<void> startBoard(
  BuildContext context, {
  required Deck deck,
  required List<Deck> candidates,
  required BoardMode mode,
}) async {
  final scope = AppScope.of(context);
  final env = scope.environment;

  final request = await showBoardStartDialog(
    context,
    deck: deck,
    candidates: candidates,
    mode: mode,
    // ★検証は `DeckRepository` 経由（UI から DAO を直接呼ばない / D55）。
    validate: env.decks.validate,
  );
  if (request == null || !context.mounted) return;

  // ★★ 乱数列は 1 本（決定 D79 / D80）★★
  //   begin と dealInitialEnergy に同じインスタンスを渡す。
  final rng = SeededRng(request.seed);

  final GameSetup setup;
  try {
    setup = GameSetup.begin(
      players: [
        PlayerDeck(playerId: kSelfPlayerId, deck: deck),
        PlayerDeck(playerId: kOpponentPlayerId, deck: request.opponentDeck),
      ],
      cards: env.cards,
      printings: env.printings,
      rng: rng,
      firstPlayerId: request.firstPlayerId,
      // ★6.1.2 により置換されうるので配信された値を使う（定数にしない）。
      config: env.ruleConfig,
    );
  } on GameSetupException catch (e) {
    // ★ダイアログが未知の刷りで止めているので普通は来ない。
    //   ★それでも黙って落とさない（来たら理由を出す）。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('盤面を作れませんでした: $e')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  // ★★ 6.2.1.6（決定 D93 / M-B6）★★
  //   ★手札は `handsForMulligan` で**受け取る**。`GameSetup` の途中の盤面を読まない
  //   （`test/board/board_player_access_test.dart` が走査で塞いでいる）。
  final choices = await showMulliganDialog(
    context,
    hands: setup.handsForMulligan,
    mode: mode,
    catalog: env.catalog,
    imageSource: env.imageSource,
  );
  // ★★ 「やめる」は「0 枚」ではない ★★ 盤面を開かない。
  if (choices == null || !context.mounted) return;

  // ★★ 順を入れ替えないこと ★★ 入れ替えると乱数の消費順が条文と変わる（D80）。
  final initialState =
      setup.mulligan(choices: choices, rng: rng).dealInitialEnergy(rng: rng);

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BoardPage(
        initialState: initialState,
        // ★押したデッキが自分側（決定 D81）。
        viewerId: kSelfPlayerId,
        mode: mode,
        seed: request.seed,
        notices: _noticesFor(
          mode: mode,
          selfResult: env.decks.validate(deck),
          opponentResult: env.decks.validate(request.opponentDeck),
        ),
      ),
    ),
  );
}

/// 盤面に常設する注記（盤面設計メモ §10-3）。
///
/// ★★ ソロでは相手の 6.1 違反を出さない（決定 D88 / §14-5）★★
/// 相手側には自分と同じデッキが入っているので、出すと**同じ違反が 2 回**並ぶ。
/// それは幽霊の 6.1 違反であって、盤面から読み取れる事実ではない。
List<BoardNotice> _noticesFor({
  required BoardMode mode,
  required DeckValidationResult selfResult,
  required DeckValidationResult opponentResult,
}) =>
    [
      if (!selfResult.isValid)
        DeckNotValid(playerLabel: '自分', issues: selfResult.issues),
      if (mode.hasOpponent && !opponentResult.isValid)
        DeckNotValid(playerLabel: '相手', issues: opponentResult.issues),
    ];
