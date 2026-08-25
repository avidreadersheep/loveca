/// R2 から R7 へ入る 1 本道（決定 D81 / 盤面設計メモ §9）.
///
/// ★★ 6.2.1 を走らせるのはここ 1 箇所である ★★
/// `GameSetup.begin` → （★6.2.1.6 マリガンが入る場所 / M-B5）→ `dealInitialEnergy`。
/// **2 箇所で走らせない。** 走らせる場所が増えると
/// 「seed をどこで作ったか」「マリガンをどこに挟むか」が分岐する。
///
/// ★★ 押したデッキが自分側になる（決定 D81）★★
/// `viewerId` の既定が自明になり、「どちらが自分側か」をダイアログで決めずに済む。
/// D75 が `viewerId` を 1 つだけ持つと定めた形と素直に噛み合う。
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
import 'board_page.dart';
import 'board_start_dialog.dart';

/// 一人回しを開始する。★[deck] が自分側。
Future<void> startSoloBoard(
  BuildContext context, {
  required Deck deck,
  required List<Deck> candidates,
}) async {
  final scope = AppScope.of(context);
  final env = scope.environment;

  final request = await showBoardStartDialog(
    context,
    deck: deck,
    candidates: candidates,
    // ★検証は `DeckRepository` 経由（UI から DAO を直接呼ばない / D55）。
    validate: env.decks.validate,
  );
  if (request == null || !context.mounted) return;

  // ★★ 乱数列は 1 本（決定 D79 / D80）★★
  //   begin と dealInitialEnergy に同じインスタンスを渡す。
  final rng = SeededRng(request.seed);

  final GameState initialState;
  try {
    final setup = GameSetup.begin(
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

    // ★★ ここに 6.2.1.6（マリガン）が入る（M-B5）★★
    //   setup = setup.mulligan(...);
    //   ★順を入れ替えないこと。入れ替えると乱数の消費順が条文と変わる。
    initialState = setup.dealInitialEnergy(rng: rng);
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
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => BoardPage(
        initialState: initialState,
        // ★押したデッキが自分側（決定 D81）。
        viewerId: kSelfPlayerId,
        // ★★ D88 以前の「一人回し」はローカル対戦を指す（D88-1）★★
        //   ソロの入口は次のコミットで足す。
        mode: BoardMode.localVersus,
        seed: request.seed,
        notices: _noticesFor(
          selfResult: env.decks.validate(deck),
          opponentResult: env.decks.validate(request.opponentDeck),
        ),
      ),
    ),
  );
}

/// 盤面に常設する注記（盤面設計メモ §10-3）。
List<BoardNotice> _noticesFor({
  required DeckValidationResult selfResult,
  required DeckValidationResult opponentResult,
}) =>
    [
      // ★★ M-B1 の盤面は 6.2.1.6 を経ていない。暫定であることを盤面に出す ★★
      //   中途半端に動くものが「完成」と誤認される形にしない。M-B5 で消す。
      const MulliganNotImplemented(),
      if (!selfResult.isValid)
        DeckNotValid(playerLabel: '自分', issues: selfResult.issues),
      if (!opponentResult.isValid)
        DeckNotValid(playerLabel: '相手', issues: opponentResult.issues),
    ];
