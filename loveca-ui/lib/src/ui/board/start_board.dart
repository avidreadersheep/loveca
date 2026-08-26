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

import '../../boot/boot_steps.dart';
import '../../data/energy_fill.dart';
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

  // ★★ 設定は `env.settings` から読まない（決定 D97-4）★★
  //   あれは起動段 3 のスナップショットなので、R6 で変えても次の起動まで古いままである。
  //   ★この項目は補完の 1 回にしか効かないので、いま読んでよい
  //     （`distDir` のように起動ゲートを要求する理由が無い / D56 との違い）。
  final settings = (await env.settingsStore.load()).settings;
  if (!context.mounted) return;

  final request = await showBoardStartDialog(
    context,
    deck: deck,
    candidates: candidates,
    mode: mode,
    // ★検証は `DeckRepository` 経由（UI から DAO を直接呼ばない / D55）。
    validate: env.decks.validate,
    energyFillPrintingId: settings.energyFillPrintingId,
    rows: env.rows,
    imageSource: env.imageSource,
  );
  if (request == null || !context.mounted) return;

  // ★★ ダイアログで変えたなら覚える（次回も同じカードで補う）★★
  //   ★変えていなければ書かない —— 盤面を開くたびに設定ファイルへ書く理由が無い。
  if (request.energyFillPrintingId != settings.energyFillPrintingId) {
    await env.settingsStore.save(
      request.energyFillPrintingId == null
          ? settings.copyWith(clearEnergyFill: true)
          : settings.copyWith(
              energyFillPrintingId: request.energyFillPrintingId,
            ),
    );
    if (!context.mounted) return;
  }

  // ★★ エネルギーデッキ 0 枚の補完（決定 D96 / D97）★★
  //   ★ここでしか行わない。保存されたデッキには触れない
  //     （6.1.1 が縛るのは「開始前に用意されたエネルギーデッキ」であって記録ではない）。
  //   ★★ 相手側にも同じ補完を掛ける ★★
  //     ソロでは `request.opponentDeck` に自分と同じデッキが入る（§14-5 / D81）ので、
  //     片側だけ補うと盤面上で自他の中身が食い違う。
  final selfFill = _planFill(env, deck, request.energyFillPrintingId);
  final opponentFill =
      _planFill(env, request.opponentDeck, request.energyFillPrintingId);

  // ★★ 乱数列は 1 本（決定 D79 / D80）★★
  //   begin と dealInitialEnergy に同じインスタンスを渡す。
  final rng = SeededRng(request.seed);

  final GameSetup setup;
  try {
    setup = GameSetup.begin(
      players: [
        PlayerDeck(
          playerId: kSelfPlayerId,
          deck: applyEnergyFill(deck, selfFill),
        ),
        PlayerDeck(
          playerId: kOpponentPlayerId,
          deck: applyEnergyFill(request.opponentDeck, opponentFill),
        ),
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
          // ★★ 検証は補完前のデッキに対して走らせる ★★
          //   ここを補完後にすると 6.1 の判定が嘘になる。
          //   保存されているのはあくまで 0 枚のデッキである。
          selfResult: env.decks.validate(deck),
          opponentResult: env.decks.validate(request.opponentDeck),
          selfFill: selfFill,
          opponentFill: opponentFill,
          // ★引けなければ番号だけで通す（ここで落とさない）。
          nameOf: (n) => env.cards[n]?.name ?? 'エネルギーカード',
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
  required EnergyFillPlan selfFill,
  required EnergyFillPlan opponentFill,
  // ★`Map<String, Card>` を受け取らない —— `Card` は Flutter の
  //   マテリアルウィジェットと名前が衝突する。★名前だけが要るので関数で渡す。
  required String Function(String cardNumber) nameOf,
}) =>
    [
      if (!selfResult.isValid)
        DeckNotValid(playerLabel: '自分', issues: selfResult.issues),
      if (mode.hasOpponent && !opponentResult.isValid)
        DeckNotValid(playerLabel: '相手', issues: opponentResult.issues),
      // ★★ 黙って足さない（決定 D96）★★
      ...?_fillNotice(playerLabel: '自分', plan: selfFill, nameOf: nameOf),
      // ★ソロでは相手側の補完を出さない（同じデッキなので同じ行が 2 回並ぶ / §14-5）。
      if (mode.hasOpponent)
        ...?_fillNotice(playerLabel: '相手', plan: opponentFill, nameOf: nameOf),
    ];

/// 補完 1 件ぶんの注記。★何も言うことが無ければ `null`。
///
/// ★**`notNeeded` と `unset` では何も出さない** —— どちらも正常な状態である。
/// `unset` は「補完しない」という利用者の選択、`notNeeded` はそもそも 0 枚ではない。
List<BoardNotice>? _fillNotice({
  required String playerLabel,
  required EnergyFillPlan plan,
  required String Function(String cardNumber) nameOf,
}) {
  if (plan.willFill) {
    final cardNumber = cardNumberOfPrinting(plan.printingId!);
    return [
      EnergyDeckFilled(
        playerLabel: playerLabel,
        // ★名前はカタログから。引けなければ番号だけで通す（ここで落とさない）。
        cardName: nameOf(cardNumber),
        cardNumber: cardNumber,
        count: plan.count,
      ),
    ];
  }
  return switch (plan.skip!) {
    EnergyFillSkip.notNeeded || EnergyFillSkip.unset => null,
    final reason => [
        EnergyFillUnavailable(
          reason: reason,
          cardNumber: plan.cardNumber ?? '',
        ),
      ],
  };
}

/// 補完の計画を立てる。★枚数は `DeckValidator` から取る（**D28**: 数え直さない）。
EnergyFillPlan _planFill(
  AppEnvironment env,
  Deck deck,
  String? energyFillPrintingId,
) =>
    planEnergyFill(
      energyCount: env.decks.validate(deck).energyCount,
      printingId: energyFillPrintingId,
      cards: env.cards,
      printings: env.printings,
      config: env.ruleConfig,
    );
