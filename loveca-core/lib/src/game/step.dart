/// ステップの型.
///
/// 総合ルール 7 章・8 章に対応。確定の根拠は `docs/PhaseEngine設計メモ.md` の B-1。
///
/// ★★ ステップ ID は条番号そのもの ★★
///   節番号を持たない定義条 (8.3.1 / 8.3.2 など) はステップにしない。
///
/// ★★ StepId 単体では一意にならない ★★
///   7.4〜7.7 は先攻通常フェイズと後攻通常フェイズの 2 インスタンス、
///   8.3.3〜8.3.17 は先攻・後攻パフォーマンスフェイズの 2 インスタンスある。
///   一意になるのは (PhaseId, StepId) の組 = [StepCursor]。
///
/// ★★ ステップ列は単純な配列ではなく有向グラフ ★★
///   8.4.12 が 8.4.9 へ戻るループを持つため。分岐は 8.3.6 と 8.4.12 の 2 箇所だけ。

library;

import 'phase.dart';

/// 分岐条件を誰が判定するか。
///
/// 判定に**効果テキストの解釈が要るか**が境界になる (CLAUDE.md §1)。
enum StepDecision {
  /// 盤面の観測だけで決まる。アプリが自動判定してよい。
  automatic,

  /// 自動能力の誘発有無を含むため、プレイヤーが宣言する。
  ///
  /// ★アプリが判定してはいけない。カードテキストの解釈そのものになる。
  playerDeclared,
}

/// ステップ。ID は総合ルールの条番号そのもの。
enum StepId {
  // ==== 7.4 アクティブフェイズ ====

  /// 手番プレイヤーは自身のエネルギー置き場とメンバーエリアのウェイトのカードを
  /// すべてアクティブにする。
  ///
  /// ★7.4 だけ誘発が先頭ではない。アクティブ化 (7.4.1) が誘発 (7.4.2) より前にある。
  ///   7.5 / 7.6 / 7.7 はいずれも誘発が先頭。ここを揃えて実装すると 7.4 で順序が狂う。
  s7_4_1('7.4.1'),

  /// 「ターンの始めに」「アクティブフェイズの始めに」誘発。
  /// 最初のターンなら「ゲームの始めに」も。
  s7_4_2('7.4.2'),

  /// チェックタイミング (9.5.1 / 9.5.3) → フェイズ終了。
  s7_4_3('7.4.3'),

  // ==== 7.5 エネルギーフェイズ ====

  /// 「エネルギーフェイズの始めに」誘発 + チェックタイミング。
  s7_5_1('7.5.1'),

  /// 手番プレイヤーは自身のエネルギーデッキ置き場の一番上のカードをエネルギー置き場へ移動。
  s7_5_2('7.5.2'),

  /// チェックタイミング → フェイズ終了。
  s7_5_3('7.5.3'),

  // ==== 7.6 ドローフェイズ ====

  /// 「ドローフェイズの始めに」誘発 + チェックタイミング。
  s7_6_1('7.6.1'),

  /// 手番プレイヤーはカードを 1 枚引く (5.6.1)。
  s7_6_2('7.6.2'),

  /// チェックタイミング → フェイズ終了。
  s7_6_3('7.6.3'),

  // ==== 7.7 メインフェイズ ====

  /// 「メインフェイズの始めに」誘発 + チェックタイミング。
  s7_7_1('7.7.1'),

  /// 手番プレイヤーにプレイタイミング (9.5.2)。
  /// 7.7.2.1 起動能力を 1 つ / 7.7.2.2 手札のメンバーカードを 1 枚。
  s7_7_2('7.7.2'),

  /// フェイズ終了。
  ///
  /// ★7.7 には終了時チェックタイミングの記述が無い。7.4.3 / 7.5.3 / 7.6.3 と非対称。
  ///   9.5.4.3 (プレイタイミングを与えられたプレイヤーが何もしないことを選んだ場合、
  ///   プレイタイミングが終了しフェイズが進行する) で閉じる。CT を足さないこと。
  s7_7_3('7.7.3'),

  // ==== 8.2 ライブカードセットフェイズ ====

  /// 「ライブフェイズの始めに」「ライブカードセットフェイズの始めに」誘発 + チェックタイミング。
  s8_2_1('8.2.1'),

  /// ★先攻プレイヤーが手札を 3 枚まで裏向きにライブカード置き場へ置き、置いた枚数と同数引く。
  ///
  /// ★「手札のカード」であってライブカードに限定していない。
  ///   ライブ以外を裏向きに置くブラフは正規戦術 (8.3.4 で表向きにされ控え室へ)。
  s8_2_2('8.2.2'),

  /// チェックタイミング。
  s8_2_3('8.2.3'),

  /// ★後攻プレイヤーが 8.2.2 と同様に行う。
  s8_2_4('8.2.4'),

  /// チェックタイミング → フェイズ終了。
  s8_2_5('8.2.5'),

  // ==== 8.3 パフォーマンスフェイズ (先攻・後攻で 2 回実行) ====

  /// 手番プレイヤーの「パフォーマンスフェイズの始めに」誘発 + チェックタイミング。
  s8_3_3('8.3.3'),

  /// ライブカード置き場のカードをすべて表向きにし、ライブカードでないカードを控え室へ。
  /// 8.3.4.1「ライブできない」なら全部控え室へ。
  s8_3_4('8.3.4'),

  /// チェックタイミング。
  s8_3_5('8.3.5'),

  /// ★分岐: ライブカード置き場にカードが無ければパフォーマンスフェイズを終了する。
  ///
  /// 盤面の観測だけで決まるため [StepDecision.automatic]。
  ///
  /// ★早期終了では 8.3.7〜8.3.17 を丸ごと飛ばす。
  ///   このとき 11.5.2.1 により「ライブ開始時」(8.3.8) の事象は発生しない。
  ///   8.3.17 へジャンプさせると 8.3.17 のチェックタイミングが余分に走るため、
  ///   フェイズ終了へ直接遷移させる (後続候補の target が null)。
  s8_3_6('8.3.6', decision: StepDecision.automatic),

  /// ライブカードがある場合、ライブを行う。
  s8_3_7('8.3.7'),

  /// 「ライブ開始時」の事象が発生 (11.5)。
  s8_3_8('8.3.8'),

  /// チェックタイミング。
  s8_3_9('8.3.9'),

  /// ★**アクティブ状態のメンバー**のブレードを合計する。
  ///
  /// ★ウェイト状態のメンバーからブレードは参照しない。8.3.14 と参照範囲が違う。
  s8_3_10('8.3.10'),

  /// メインデッキの一番上を解決領域へ、合計ブレード数と同じ回数繰り返す (＝エール)。
  ///
  /// ★10.2.1 により、途中でメインデッキが尽きた場合はその場でリフレッシュし、
  ///   残り回数を続行する。チェックタイミングを待たない。
  s8_3_11('8.3.11'),

  /// 解決領域のすべてのカードのブレードハートを確認。
  /// 8.3.12.1 ドローアイコン 1 つにつきカードを 1 枚引く。
  ///
  /// ★ドロー (8.3.12) はハート合計 (8.3.14) より**前**。
  ///   逆にすると引いたカードが同じ回の集計に影響しうる実装になる。
  s8_3_12('8.3.12'),

  /// チェックタイミング。
  s8_3_13('8.3.13'),

  /// ★**全メンバー (ウェイトを含む)** のハート
  ///   ＋ 解決領域の**自分の**カードのブレードハートのハートを合計する (＝ライブ所有ハート)。
  ///
  /// ★解決領域は両プレイヤー共有で 1 つだけ (4.14.1) なので `ownerId` で絞る。
  /// ★合算するのは色のハートだけ。ドロー / スコアのアイコンは合算しない。
  s8_3_14('8.3.14'),

  /// 各ライブカードの必要ハートを満たすか確認。
  /// 8.3.15.1.1 ALL は任意の 1 色として扱う。8.3.15.1.2 満たしたら所有ハートから減算。
  s8_3_15('8.3.15'),

  /// いずれかが満たせなかった場合、ライブカード置き場のすべてのライブカードを控え室へ。
  s8_3_16('8.3.16'),

  /// チェックタイミング → フェイズ終了。
  s8_3_17('8.3.17'),

  // ==== 8.4 ライブ勝敗判定フェイズ ====

  /// 「ライブ判定フェイズの始めに」誘発 + チェックタイミング。
  s8_4_1('8.4.1'),

  /// ライブカード置き場にカードがあるプレイヤーはスコアを合計。
  /// 8.4.2.1 自身のエールのスコアアイコン 1 つにつき +1。
  s8_4_2('8.4.2'),

  /// 合計スコアの比較手順の規約。
  /// 8.4.3.1 両者カード無し＝等しい / 8.4.3.2 片方だけカードあり＝そちらが大 /
  /// 8.4.3.3 両者あり＝比較。
  ///
  /// ★8.4.2 (合計) と 8.4.3 (比較の規約定義) と 8.4.6 (実際の比較と勝者決定) は別物。
  s8_4_3('8.4.3'),

  /// ライブカード置き場にカードがあるプレイヤーに「ライブが成功した」事象が発生 (11.6)。
  ///
  /// ★8.4.4 は 8.4.6 (勝敗決定) より**前**にある。
  ///   「ライブ成功」はライブカード置き場にカードが残っていれば発生し、
  ///   ライブに勝ったかどうかとは独立。11.6.2 も 8.4.4 を参照している。
  s8_4_4('8.4.4'),

  /// チェックタイミング。
  s8_4_5('8.4.5'),

  /// 合計スコアを比較しライブに勝利したプレイヤーを決定。
  /// 8.4.6.1 両者カード無し＝勝者なし / 8.4.6.2 大きい方が勝利、同点なら**両者勝利**。
  s8_4_6('8.4.6'),

  /// ライブに勝利したプレイヤーはライブカード置き場のカードを 1 枚選び成功ライブカード置き場へ。
  ///
  /// ★8.4.7.1 両者勝利の場合、ライブ置き場に 2 枚あるプレイヤーは移動しない。
  ///   したがって「勝敗」と「移動」は一致しない。
  ///   このステップの**移動実績**を記録し、8.4.13 がそれを参照する。
  s8_4_7('8.4.7'),

  /// 各プレイヤーはライブ置き場に残ったカードと、
  /// 解決領域のエールで公開したカードをすべて自身の控え室へ。
  s8_4_8('8.4.8'),

  /// チェックタイミング。★8.4.12 のループの戻り先。
  s8_4_9('8.4.9'),

  /// 「ターンの終わりに」でこのターンまだ誘発していない自動能力の誘発条件が発生。
  s8_4_10('8.4.10'),

  /// チェックタイミング。処理終了後、「ターンの終わりまで」「ライブ終了時まで」
  /// 「そのターン中」を期限とする効果が消滅。
  s8_4_11('8.4.11'),

  /// ★分岐: 条件を満たす場合 8.4.9 に戻る (ループ)。
  ///
  /// ★条件は「まだ誘発すべき自動能力が残っているか」であり、
  ///   カードテキストの解釈そのもの。アプリが判定してはいけない。
  ///   「まだ処理がある / 無い」をプレイヤーが選ぶ 2 択として提示する
  ///   ([StepDecision.playerDeclared])。
  s8_4_12('8.4.12', decision: StepDecision.playerDeclared),

  /// ★8.4.7 において一方のプレイヤーのみが成功ライブカード置き場にカードを移動していた場合、
  ///   そのプレイヤーが先攻プレイヤーとなる。そうでなければ現在の先攻が継続。
  ///
  /// ★★ `GameState.firstPlayerId` を書き換える唯一のステップ ★★
  ///   参照するのは 8.4.6 の勝敗ではなく 8.4.7 の移動実績。
  s8_4_13('8.4.13'),

  /// このターンを終了する。
  s8_4_14('8.4.14');

  const StepId(this.ruleRef, {this.decision});

  /// このステップの条番号。ステップ ID そのもの。
  final String ruleRef;

  /// 分岐点の判定主体。
  ///
  /// ★分岐を持つステップ (後続候補が 2 つ) のみ非 null。
  ///   [StepId.s8_3_6] と [StepId.s8_4_12] の 2 つだけ。
  final StepDecision? decision;
}

/// ステップの後続候補。
class StepTransition {
  const StepTransition(this.target, {required this.ruleRef, this.label = ''});

  /// 遷移先のステップ。
  ///
  /// ★null は**フェイズの終了**を表す。
  ///   8.3.6 の早期終了を「8.3.17 へジャンプ」にすると
  ///   8.3.17 のチェックタイミングが余分に走るため、終了へ直接遷移させる。
  final StepId? target;

  /// この遷移の根拠となる条番号。
  final String ruleRef;

  /// 分岐をプレイヤーに提示するときの選択肢名。
  /// 分岐でないステップでは空。
  final String label;

  /// フェイズを終了する遷移か。
  bool get endsPhase => target == null;
}

/// ステップの有向グラフ。総合ルール 7 章・8 章。
///
/// ★★ 後続候補が 2 つあるのは 8.3.6 と 8.4.12 の 2 箇所だけ ★★
///
/// 終端ステップ (7.4.3 / 7.5.3 / 7.6.3 / 7.7.3 / 8.2.5 / 8.3.17 / 8.4.14) は
/// `target` が null の遷移を 1 つ持つ。
const Map<StepId, List<StepTransition>> stepGraph = {
  // ---- 7.4 アクティブフェイズ ----
  StepId.s7_4_1: [StepTransition(StepId.s7_4_2, ruleRef: '7.4')],
  StepId.s7_4_2: [StepTransition(StepId.s7_4_3, ruleRef: '7.4')],
  StepId.s7_4_3: [StepTransition(null, ruleRef: '7.4.3')],

  // ---- 7.5 エネルギーフェイズ ----
  StepId.s7_5_1: [StepTransition(StepId.s7_5_2, ruleRef: '7.5')],
  StepId.s7_5_2: [StepTransition(StepId.s7_5_3, ruleRef: '7.5')],
  StepId.s7_5_3: [StepTransition(null, ruleRef: '7.5.3')],

  // ---- 7.6 ドローフェイズ ----
  StepId.s7_6_1: [StepTransition(StepId.s7_6_2, ruleRef: '7.6')],
  StepId.s7_6_2: [StepTransition(StepId.s7_6_3, ruleRef: '7.6')],
  StepId.s7_6_3: [StepTransition(null, ruleRef: '7.6.3')],

  // ---- 7.7 メインフェイズ ----
  StepId.s7_7_1: [StepTransition(StepId.s7_7_2, ruleRef: '7.7')],
  StepId.s7_7_2: [StepTransition(StepId.s7_7_3, ruleRef: '9.5.4.3')],
  StepId.s7_7_3: [StepTransition(null, ruleRef: '7.7.3')],

  // ---- 8.2 ライブカードセットフェイズ ----
  StepId.s8_2_1: [StepTransition(StepId.s8_2_2, ruleRef: '8.2')],
  StepId.s8_2_2: [StepTransition(StepId.s8_2_3, ruleRef: '8.2')],
  StepId.s8_2_3: [StepTransition(StepId.s8_2_4, ruleRef: '8.2')],
  StepId.s8_2_4: [StepTransition(StepId.s8_2_5, ruleRef: '8.2')],
  StepId.s8_2_5: [StepTransition(null, ruleRef: '8.2.5')],

  // ---- 8.3 パフォーマンスフェイズ ----
  StepId.s8_3_3: [StepTransition(StepId.s8_3_4, ruleRef: '8.3')],
  StepId.s8_3_4: [StepTransition(StepId.s8_3_5, ruleRef: '8.3')],
  StepId.s8_3_5: [StepTransition(StepId.s8_3_6, ruleRef: '8.3')],

  // ★分岐 1 / 2: 盤面の観測のみで決まる (StepDecision.automatic)
  StepId.s8_3_6: [
    StepTransition(StepId.s8_3_7, ruleRef: '8.3.6', label: 'ライブカード置き場にカードがある'),
    // ★8.3.17 へジャンプさせない。8.3.17 の CT が余分に走る。
    //   11.5.2.1 により「ライブ開始時」(8.3.8) の事象も発生しない。
    StepTransition(null, ruleRef: '8.3.6', label: 'ライブカード置き場が空 → フェイズ終了'),
  ],

  StepId.s8_3_7: [StepTransition(StepId.s8_3_8, ruleRef: '8.3')],
  StepId.s8_3_8: [StepTransition(StepId.s8_3_9, ruleRef: '8.3')],
  StepId.s8_3_9: [StepTransition(StepId.s8_3_10, ruleRef: '8.3')],
  StepId.s8_3_10: [StepTransition(StepId.s8_3_11, ruleRef: '8.3')],
  StepId.s8_3_11: [StepTransition(StepId.s8_3_12, ruleRef: '8.3')],
  StepId.s8_3_12: [StepTransition(StepId.s8_3_13, ruleRef: '8.3')],
  StepId.s8_3_13: [StepTransition(StepId.s8_3_14, ruleRef: '8.3')],
  StepId.s8_3_14: [StepTransition(StepId.s8_3_15, ruleRef: '8.3')],
  StepId.s8_3_15: [StepTransition(StepId.s8_3_16, ruleRef: '8.3')],
  StepId.s8_3_16: [StepTransition(StepId.s8_3_17, ruleRef: '8.3')],
  StepId.s8_3_17: [StepTransition(null, ruleRef: '8.3.17')],

  // ---- 8.4 ライブ勝敗判定フェイズ ----
  StepId.s8_4_1: [StepTransition(StepId.s8_4_2, ruleRef: '8.4')],
  StepId.s8_4_2: [StepTransition(StepId.s8_4_3, ruleRef: '8.4')],
  StepId.s8_4_3: [StepTransition(StepId.s8_4_4, ruleRef: '8.4')],
  StepId.s8_4_4: [StepTransition(StepId.s8_4_5, ruleRef: '8.4')],
  StepId.s8_4_5: [StepTransition(StepId.s8_4_6, ruleRef: '8.4')],
  StepId.s8_4_6: [StepTransition(StepId.s8_4_7, ruleRef: '8.4')],
  StepId.s8_4_7: [StepTransition(StepId.s8_4_8, ruleRef: '8.4')],
  StepId.s8_4_8: [StepTransition(StepId.s8_4_9, ruleRef: '8.4')],
  StepId.s8_4_9: [StepTransition(StepId.s8_4_10, ruleRef: '8.4')],
  StepId.s8_4_10: [StepTransition(StepId.s8_4_11, ruleRef: '8.4')],
  StepId.s8_4_11: [StepTransition(StepId.s8_4_12, ruleRef: '8.4')],

  // ★分岐 2 / 2: 自動能力の誘発有無を含むためプレイヤーが宣言する
  StepId.s8_4_12: [
    // ★ループ。静的グラフの逆辺で「1 つ戻る」を実装できない根拠がこれ。
    StepTransition(StepId.s8_4_9, ruleRef: '8.4.12', label: 'まだ処理がある'),
    StepTransition(StepId.s8_4_13, ruleRef: '8.4.12', label: '処理は無い'),
  ],

  StepId.s8_4_13: [StepTransition(StepId.s8_4_14, ruleRef: '8.4')],
  StepId.s8_4_14: [StepTransition(null, ruleRef: '8.4.14')],
};

/// フェイズが持つステップの並び。
extension PhaseSteps on PhaseId {
  /// このフェイズを構成するステップ。
  ///
  /// ★先攻・後攻で同じ条番号を共有する。
  ///   だから StepId 単体では一意にならず、[StepCursor] が要る。
  List<StepId> get steps => switch (this) {
        PhaseId.firstActive || PhaseId.secondActive => const [
            StepId.s7_4_1,
            StepId.s7_4_2,
            StepId.s7_4_3,
          ],
        PhaseId.firstEnergy || PhaseId.secondEnergy => const [
            StepId.s7_5_1,
            StepId.s7_5_2,
            StepId.s7_5_3,
          ],
        PhaseId.firstDraw || PhaseId.secondDraw => const [
            StepId.s7_6_1,
            StepId.s7_6_2,
            StepId.s7_6_3,
          ],
        PhaseId.firstMain || PhaseId.secondMain => const [
            StepId.s7_7_1,
            StepId.s7_7_2,
            StepId.s7_7_3,
          ],
        PhaseId.liveCardSet => const [
            StepId.s8_2_1,
            StepId.s8_2_2,
            StepId.s8_2_3,
            StepId.s8_2_4,
            StepId.s8_2_5,
          ],
        PhaseId.firstPerformance || PhaseId.secondPerformance => const [
            StepId.s8_3_3,
            StepId.s8_3_4,
            StepId.s8_3_5,
            StepId.s8_3_6,
            StepId.s8_3_7,
            StepId.s8_3_8,
            StepId.s8_3_9,
            StepId.s8_3_10,
            StepId.s8_3_11,
            StepId.s8_3_12,
            StepId.s8_3_13,
            StepId.s8_3_14,
            StepId.s8_3_15,
            StepId.s8_3_16,
            StepId.s8_3_17,
          ],
        PhaseId.liveJudgement => const [
            StepId.s8_4_1,
            StepId.s8_4_2,
            StepId.s8_4_3,
            StepId.s8_4_4,
            StepId.s8_4_5,
            StepId.s8_4_6,
            StepId.s8_4_7,
            StepId.s8_4_8,
            StepId.s8_4_9,
            StepId.s8_4_10,
            StepId.s8_4_11,
            StepId.s8_4_12,
            StepId.s8_4_13,
            StepId.s8_4_14,
          ],
      };
}

/// ゲーム進行の現在地。
///
/// ★★ (PhaseId, StepId) の組でなければ一意にならない ★★
///   7.4〜7.7 と 8.3.3〜8.3.17 は先攻・後攻の 2 インスタンスがあるため、
///   StepId 単体では「どちらのインスタンスか」が決まらない。
class StepCursor {
  const StepCursor(this.phase, this.step);

  final PhaseId phase;
  final StepId step;

  @override
  bool operator ==(Object other) =>
      other is StepCursor && other.phase == phase && other.step == step;

  @override
  int get hashCode => Object.hash(phase, step);

  @override
  String toString() => '${phase.name}@${step.ruleRef}';
}
