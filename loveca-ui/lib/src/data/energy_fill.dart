/// ★★ エネルギーデッキ 0 枚の補完（決定 D96 / D97）★★
///
/// ★★ 補完は「盤面の開始時」にだけ行う。保存時には行わない ★★
/// 総合ルール **6.1.1** が縛るのは「ゲームの**開始前に**用意されたエネルギーデッキ」であって、
/// **アプリが保存する記録ではない。**だから保存されたデッキには一切触らない。
///
/// ★**(a) 保存時を却下した決め手**（決定 D96-4）——
/// 補完した `printingId` を DB に焼き込むと、その刷りが配信から落ちた時点で
/// `hasUnknownCards` が立ち、**盤面を開始できなくなる。**
/// 「必ず開始できた 0 枚デッキ」が「開始できないデッキ」に変わる ——
/// **要望を叶える実装が要望の前提を壊す**（**D35** と同型）。
///
/// ★★ 黙って足さない ★★
/// 補完したときは呼び出し側が `BoardNotice` を出す。
/// **何を何枚足したかを見せる**こと自体に 2 つの意味がある ——
/// (1) DB と盤面で中身が違うことの開示 (2) ★**再現情報**（下記）。
///
/// ★★ seed だけでは盤面が決まらなくなる ★★
/// エネルギー 0 枚は `drawEnergyRandomly` が `break` するので**乱数を 1 つも消費しない**が、
/// 12 枚なら 6.2.1.7 で 3 回消費する。`dealInitialEnergy` は
/// **先攻から順に両プレイヤーを回す**ので、★**自分側の補完の有無で相手の抽出位置がずれる。**
/// **D-17 とまったく同じ形である。**
///
/// ★★ 枚数を数え直さない（D28）★★
/// エネルギーの枚数は `DeckValidator` が唯一の実装なので、
/// [planEnergyFill] は `energyCount` を**受け取る**。ここで数えると検証が二重になる。
library;

import 'package:loveca_core/loveca_core.dart';

/// 補完しなかった理由。
///
/// ★★ 1 行にまとめないこと（決定 D97-5 / D95-2 と同じ形）★★
/// **原因も次の一手も違う。**まとめると「直せる問題」が「直せない問題」の文面に埋もれる。
enum EnergyFillSkip {
  /// エネルギーが 0 枚ではない。★**補完は 0 枚のときだけ行う。**
  notNeeded,

  /// 設定が空。★**異常ではない** —— 0 枚のまま開始できる（**D81** / **D-A**）。
  unset,

  /// ★**cardNumber ごとカタログに無い**（データの問題 / 復旧は取り込み直し）。
  unknownCardNumber,

  /// ★★ cardNumber は在るが、**その刷りだけ**が無い ★★
  /// （データの問題。ただし**同じカードの別の刷りを選べる**ので復旧が軽い）。
  ///
  /// ★**`LL-E-002` は D68 が開示対象にした 19 種の 1 つ**なので、
  /// 「cardNumber は在るのに printingId だけ落ちる」は実際に起こりうる。
  /// ★**`printings[id] == null` だけで判定すると #1 と取り違える。**
  unknownPrinting,

  /// 引けるが**種別がエネルギーではない**（設定の問題）。
  /// ★これを補うと 6.1.1.3 を満たさない補完になる。
  notEnergy,
}

/// 補完の計画。★**決めるだけで、まだ何も作らない。**
class EnergyFillPlan {
  const EnergyFillPlan._({
    required this.count,
    this.printingId,
    this.cardNumber,
    this.skip,
  });

  /// 補う。
  const EnergyFillPlan.fill({
    required String printingId,
    required int count,
  }) : this._(printingId: printingId, count: count);

  /// 補わない。★理由を必ず持つ。
  const EnergyFillPlan.skipped(
    EnergyFillSkip skip, {
    String? printingId,
    String? cardNumber,
  }) : this._(
          count: 0,
          skip: skip,
          printingId: printingId,
          cardNumber: cardNumber,
        );

  /// 補う刷り。★補わない場合も**設定値を持ち回る**（何が解決できなかったかを見せるため）。
  final String? printingId;

  /// [printingId] から導いた cardNumber。★[EnergyFillSkip.unknownPrinting] の案内に使う。
  final String? cardNumber;

  final int count;
  final EnergyFillSkip? skip;

  bool get willFill => skip == null;
}

/// `printingId` から cardNumber を切り出す（CLAUDE.md §5-(6)）。
///
/// ★★ ホワイトリスト化しない ★★
/// `PRproteinbar` のような公式レアリティ一覧に無い接尾が実在するため、
/// パイプラインと同じく**機械的な `rsplit`** に徹する。
///
/// ★**入力は printingId である。**cardNumber（`LL-E-002`）に掛けると
/// `LL-E` になり、そんなカードは実在しない（`docs/UI設計メモ.md` §12-4）。
String cardNumberOfPrinting(String printingId) {
  final at = printingId.lastIndexOf('-');
  return at <= 0 ? printingId : printingId.substring(0, at);
}

/// 補完するかどうかを決める。★純関数。
///
/// [energyCount] は `DeckValidator` が数えた値を渡すこと（**D28**）。
EnergyFillPlan planEnergyFill({
  required int energyCount,
  required String? printingId,
  required Map<String, Card> cards,
  required Map<String, Printing> printings,
  required RuleConfig config,
}) {
  // 総合ルール 6.1.1.3: エネルギーデッキは 12 枚ちょうど。
  // ★期待値は `RuleConfig` から取る（6.1.2 で置換されうるので定数にしない）。
  if (energyCount != 0) {
    return const EnergyFillPlan.skipped(EnergyFillSkip.notNeeded);
  }
  if (printingId == null || printingId.isEmpty) {
    return const EnergyFillPlan.skipped(EnergyFillSkip.unset);
  }

  final printing = printings[printingId];
  if (printing == null) {
    // ★★ ここを 1 段で済ませない ★★
    //   cardNumber ごと無いのか、その刷りだけが無いのかで**次の一手が違う。**
    final cardNumber = cardNumberOfPrinting(printingId);
    return EnergyFillPlan.skipped(
      cards.containsKey(cardNumber)
          ? EnergyFillSkip.unknownPrinting
          : EnergyFillSkip.unknownCardNumber,
      printingId: printingId,
      cardNumber: cardNumber,
    );
  }

  final card = cards[printing.cardNumber];
  if (card == null || card.cardType != CardType.energy) {
    // ★刷りは引けるのに種別が違う / カードが引けない。どちらも設定として不正。
    return EnergyFillPlan.skipped(
      EnergyFillSkip.notEnergy,
      printingId: printingId,
      cardNumber: printing.cardNumber,
    );
  }

  return EnergyFillPlan.fill(
    printingId: printingId,
    count: config.energyDeckSize,
  );
}

/// [plan] を [deck] に適用した**一時的な** `Deck` を返す。
///
/// ★★ 保存しない。`Deck.copyWith` を通さない ★★
/// `copyWith` は `revision` を +1 し `updatedAt` を `DateTime.now()` にする
/// （**D-14** の既知の違反箇所）。盤面を開くだけで同期の差分が立つのを避ける。
/// `DeckRepository._draftView` と同じ流儀で組み直す。
Deck applyEnergyFill(Deck deck, EnergyFillPlan plan) {
  if (!plan.willFill) return deck;
  return Deck(
    deckId: deck.deckId,
    name: deck.name,
    entries: [
      ...deck.entries,
      DeckEntry(printingId: plan.printingId!, count: plan.count),
    ],
    memo: deck.memo,
    tags: deck.tags,
    coverPrintingId: deck.coverPrintingId,
    createdAt: deck.createdAt,
    // ★動かさない。保存しないので時刻も版も変わらない。
    updatedAt: deck.updatedAt,
    deletedAt: deck.deletedAt,
    revision: deck.revision,
    lastDeviceId: deck.lastDeviceId,
    masterDataVersion: deck.masterDataVersion,
  );
}
