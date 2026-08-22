/// ライブの集計.
///
/// 総合ルール 8.3.10 / 8.3.12.1 / 8.3.14 / 8.4.2 に対応。
///
/// ★★ 決定 D18: ライブ成功判定は自動で行わない ★★
///   このファイルが行うのは**数値を出すところまで**。
///   8.3.15（現在のライブ所有ハートで必要ハートを満たせるかの確認）と
///   8.3.16（満たせなかった場合にライブカードを控え室へ）は実装しない。
///
///   総合ルール 2.11.3 には充足判定の完全な手順が条文として存在するが、
///   D18 により**意図的に実装していない**。取りこぼしではない。
///   D-A（カード効果の自動処理は実装しない / CLAUDE.md §1）の具体化にあたる。
///   詳細は `docs/決定事項一覧.md`。
///
/// ★★ 参照範囲が 4 つとも違う ★★
///   | 集計 | 対象 | 所有者で絞るか |
///   |---|---|---|
///   | 8.3.10   | 自分の**アクティブ状態の**メンバー | — |
///   | 8.3.12.1 | 解決領域の**すべてのカード**       | ★**絞らない** |
///   | 8.3.14   | 自分の**すべての**メンバー + 解決領域 | 解決領域は絞る |
///   | 8.4.2    | 自分のライブカード置き場 + 解決領域   | 解決領域は絞る |

library;

import '../entities/card.dart';
import 'card_instance.dart';
import 'game_state.dart';
import 'member_area.dart';

/// 集計結果に共通する除外情報。
///
/// ★★ 未知の cardNumber で例外を投げない ★★
///   `HeartColor.fromKey` の厳格さは**ビルド時**に `verify_contract.py` が守れるが、
///   集計は**実行時**に走る。ここで落ちると対戦が続行不能になる
///   (`ルール整合性チェック_v1.06.md` D-1 と同じ理由)。
///
///   ただし黙って捨てるのは A-3（数字なし表記を 59 種で無言に捨てていた）と
///   同じ失敗になるため、除外した事実を返り値に載せて UI に出せるようにする。
abstract interface class AggregationResult {
  /// 集計から除外した**枚数**。
  int get excludedCount;

  /// 除外の原因になった cardNumber（重複排除・昇順）。
  List<String> get unknownCardNumbers;

  /// 除外が 1 枚でもあったか。UI の警告表示に使う。
  bool get hasExclusions;
}

/// 総合ルール 8.3.10 のブレード合計。
///
/// 8.3.10「手番プレイヤーは、自身の**アクティブ状態な**メンバーのすべての
/// ブレードの数を合計します」
///
/// この数値がそのまま 8.3.11 のエールで解決領域へ移動する枚数になる。
class BladeTotal implements AggregationResult {
  const BladeTotal({
    required this.total,
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
  });

  /// 合計ブレード数。
  final int total;

  @override
  final int excludedCount;

  @override
  final List<String> unknownCardNumbers;

  @override
  bool get hasExclusions => excludedCount > 0;
}

/// 総合ルール 8.3.12.1 のドロー枚数。
///
/// 8.3.12「手番プレイヤーは解決領域に置かれている**すべてのカード**の
/// ブレードハートを確認します」
/// 8.3.12.1「アイコン 1 つにつき、手番プレイヤーはカードを 1 枚引きます」
class YellDrawCount implements AggregationResult {
  const YellDrawCount({
    required this.count,
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
  });

  /// 手番プレイヤーが引く枚数。
  final int count;

  @override
  final int excludedCount;

  @override
  final List<String> unknownCardNumbers;

  @override
  bool get hasExclusions => excludedCount > 0;
}

/// 総合ルール 8.3.14 のライブ所有ハート。
///
/// 8.3.14「手番プレイヤーは自身のすべてのメンバーのハートアイコンと、
/// 解決領域の自分のカードが持つブレードハートのハートアイコンを合計します。
/// この合計した一連のハートアイコンをライブ所有ハートと呼びます」
///
/// ★色ごとの内訳を保つ。スカラーに潰さないこと。
///   8.3.15 の必要ハート判定 (2.11.3) は色ごとの本数と総数の両方を見る。
class OwnedHearts implements AggregationResult {
  const OwnedHearts({
    required this.hearts,
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
  });

  /// 色ごとのハートアイコン数。
  ///
  /// ★[HeartColor.all] と [HeartColor.gray] はそのまま残す。
  ///   2.1.1.3 の ALL は「桃赤黄緑青紫のいずれか 1 つの色として任意に扱える」
  ///   アイコンであり、どの色として扱うかは 8.3.15.1.1 で決まる。
  ///   その解決は決定 D18 により手動なので、**集計側で色に変換してはいけない**。
  ///
  ///   2.1.1.2 の GRAY (色を指定しないハートアイコン) もブレードハートに実在する
  ///   (配信データで 3 種)。`docs/決定事項一覧.md` §4 を参照。
  final Map<HeartColor, int> hearts;

  /// ハートアイコンの総数。2.11.3 の 2 つ目の条件が使う数。
  int get total => hearts.values.fold(0, (sum, value) => sum + value);

  @override
  final int excludedCount;

  @override
  final List<String> unknownCardNumbers;

  @override
  bool get hasExclusions => excludedCount > 0;
}

/// 総合ルール 8.4.2 のスコア合計。
///
/// 8.4.2「ライブカード置き場に**カードがあるプレイヤーは**、自身のライブカード
/// 置き場のカードのスコアを合計します」
class ScoreTotal implements AggregationResult {
  const ScoreTotal({
    required this.total,
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
  });

  /// 合計スコア。
  ///
  /// ★★ null は「ライブカード置き場が空」を表す。0 ではない ★★
  ///   8.4.2 はスコアを合計する対象を「カードがあるプレイヤー」に限っており、
  ///   空のプレイヤーには合計スコアがそもそも存在しない。
  ///
  ///   8.4.3.2「一方のプレイヤーのライブカード置き場にカードがあり、もう一方の
  ///   ライブカード置き場にカードが無い場合、カードがあるプレイヤーの合計スコアの
  ///   方が大きいものとします」
  ///
  ///   → 空を 0 で代用すると、スコア 0 のライブを持つプレイヤーと空のプレイヤーが
  ///     同点になってしまい 8.4.3.2 に反する。スコア 0 のライブは実在する
  ///     (`PL!N-bp7-030` Cheer Mode)。
  final int? total;

  /// ライブカード置き場にカードがあったか。8.4.3 の比較手順が分岐する条件。
  bool get hasLiveCards => total != null;

  @override
  final int excludedCount;

  @override
  final List<String> unknownCardNumbers;

  @override
  bool get hasExclusions => excludedCount > 0;
}

/// ライブの集計。
///
/// カードマスタを保持する点で `DeckValidator` と同じ形。
/// [CardInstance] は識別子しか持たないため、数値はマスタから引く (決定 D11)。
class LiveAggregator {
  const LiveAggregator({required this.cards});

  /// cardNumber -> Card。
  final Map<String, Card> cards;

  /// 総合ルール 8.3.10: アクティブ状態のメンバーのブレード合計。
  ///
  /// ★★ 対象は [MemberStack.member] だけ ★★
  ///   [MemberStack.beneath]（下に重ねられたカード）と [MemberArea.orphans]
  ///   （上にメンバーが居なくなったカード）は見ない。
  ///   4.5.5.2 によりこれらは向きを示す配置状態を持たず、
  ///   **アクティブ状態になりえない**ため。
  ///
  /// ★`bladeCount` が null のメンバーは 0 として合算する。
  ///   ブレードアイコンを持たないメンバーが実在する（配信データで 73 種）。
  ///   これは未知カードではないので [BladeTotal.excludedCount] に数えない。
  BladeTotal bladeTotal(GameState state, String playerId) {
    final player = state.playerOf(playerId);
    final excluded = _Excluded();
    var total = 0;

    for (final area in player.memberAreas) {
      for (final stack in area.stacks) {
        // ★stack.beneath は見ない (4.5.5.2)。
        if (stack.member.orientation != CardOrientation.active) continue;
        final card = _lookup(stack.member, excluded);
        if (card == null) continue;
        total += card.bladeCount ?? 0;
      }
      // ★area.orphans も見ない。4.5.5.2 により向きを持たないため
      //   アクティブ状態になりえない。
    }

    return BladeTotal(
      total: total,
      excludedCount: excluded.count,
      unknownCardNumbers: excluded.sorted,
    );
  }

  /// 総合ルール 8.3.12.1: 解決領域のドローアイコンの数。
  ///
  /// ★★ 所有者で絞らない。だから playerId を引数に取らない ★★
  ///   8.3.12「手番プレイヤーは解決領域に置かれている**すべてのカード**の
  ///   ブレードハートを確認します」
  ///
  ///   3 条以内で書き分けられている点に注意する。
  ///     8.3.12   … 解決領域に置かれている**すべてのカード**  → 絞らない
  ///     8.3.14   … 解決領域の**自分の**カード                → `ownerId` で絞る
  ///     8.4.2.1  … **自身の**エールのアイコン                → `ownerId` で絞る
  ///
  ///   解決領域は両プレイヤー共有で 1 つだけ (4.14.1) であり、
  ///   8.4.8 まで中身は片付かない。したがって後攻パフォーマンスフェイズでは
  ///   先攻のエールカードが残ったままであり、
  ///   **後攻は先攻のドローアイコンの分もカードを引く**ことになる。
  ///
  ///   ★この関数に絞り込みの引数を足さないこと。
  ///     8.3.14 と同じ関数に絞り込みフラグを渡す形にすると必ず取り違える。
  ///
  /// ★合算するのは [BladeHeartEffect.draw] だけ。
  ///   [BladeHeartEffect.score] は 8.4.2.1 で別に数える。
  YellDrawCount yellDrawCount(GameState state) {
    final excluded = _Excluded();
    var count = 0;

    // ★state.resolution をそのまま走査する。ownerId で絞らない (8.3.12)。
    for (final instance in state.resolution) {
      final card = _lookup(instance, excluded);
      if (card == null) continue;
      count += card.bladeHeartEffects[BladeHeartEffect.draw] ?? 0;
    }

    return YellDrawCount(
      count: count,
      excludedCount: excluded.count,
      unknownCardNumbers: excluded.sorted,
    );
  }

  /// 総合ルール 8.3.14: ライブ所有ハート。
  ///
  /// 自分のすべてのメンバーのハート + 解決領域の**自分の**カードのブレードハート。
  ///
  /// ★★ 8.3.10 と参照範囲が違う ★★
  ///   8.3.10 は**アクティブ状態のメンバーのみ**だが、
  ///   8.3.14 は**すべてのメンバー**。ウェイト状態のメンバーのハートも数える。
  ///
  /// ★★ 解決領域は `ownerId` で絞る ★★
  ///   解決領域は両プレイヤー共有で 1 つだけ (4.14.1) であり、
  ///   後攻パフォーマンスフェイズでは先攻のエールカードが残ったままになる。
  ///   マスターの定義 (3.1.2「その領域が属しているプレイヤー」) は共有領域では
  ///   定まらないため、オーナー基準で絞る。
  ///   4.1.7 と 8.4.8 がオーナー基準であることを裏づける。
  ///
  ///   ★8.3.12.1 ([yellDrawCount]) は絞らない。混同しないこと。
  ///
  /// ★★ 合算するのは `bladeHearts`（色）だけ ★★
  ///   `bladeHeartEffects` (DRAW / SCORE) は合算しない。
  ///   処理する時点も対象も違う (8.3.12.1 / 8.4.2.1)。
  ///   色のブレードハートを合算してよい根拠は 2.1.3
  ///   「ブレードハートのハートアイコンはブレードが重なって表記されていますが、
  ///     これはそれぞれブレードアイコンが無いものと同じハートアイコンを意味します」。
  OwnedHearts ownedHearts(GameState state, String playerId) {
    final player = state.playerOf(playerId);
    final excluded = _Excluded();
    final hearts = <HeartColor, int>{};

    void addAll(Map<HeartColor, int> source) {
      for (final entry in source.entries) {
        hearts[entry.key] = (hearts[entry.key] ?? 0) + entry.value;
      }
    }

    // ---- 自分のすべてのメンバーのハート (8.3.14 前半) ----
    for (final area in player.memberAreas) {
      for (final stack in area.stacks) {
        // ★アクティブ / ウェイトを問わない。8.3.10 との違いはここ。
        final card = _lookup(stack.member, excluded);
        if (card == null) continue;
        addAll(card.hearts);
      }

      // ★★ stack.beneath と area.orphans のハートは数えない ★★
      //
      //   主根拠は、条文が「メンバーカード」と「下にあるメンバーカード」を
      //   書き分けている点にある。
      //     4.5.4   「メンバーエリアのメンバーカード**は**向きを示す配置状態を**持ちます**」
      //     4.5.5.2 「メンバーエリアのメンバーカードの下に重ねられているメンバーカードや
      //              エネルギーカード**は**向きを示す配置状態を**持ちません**」
      //   どちらも「メンバーエリアにあるメンバーカード」でありながら、条文は
      //   この 2 つに正反対の規定を与えている。すなわち別のものとして扱っている。
      //   4.5.6 の「メンバー」に下のカードを含めて読むと、この書き分けが無意味になる。
      //
      //   補強として、数えると 8.3.10 と非対称になる。下のカードは 4.5.5.2 により
      //   アクティブ状態になりえないため、8.3.10 のブレードは構造的に数えようがない。
      //   ブレードは数えられないがハートだけ数えるのは条文の構造に反する。
      //
      //   【要確認】4.5.6 の字面 (メンバーエリアにある、カードタイプがメンバーで
      //   あるカード) だけを読むと下のカードも該当しうる。上記は条文の構造からの
      //   解釈であり、公式 Q&A で裏が取れたら再確認する。
      //   docs/PhaseEngine設計メモ.md §7 / §10 を参照。
    }

    // ---- 解決領域の自分のカードのブレードハート (8.3.14 後半) ----
    for (final instance in state.resolution) {
      // ★ownerId で絞る (4.14.1)。8.3.12.1 との違いはここ。
      if (instance.ownerId != playerId) continue;
      final card = _lookup(instance, excluded);
      if (card == null) continue;
      // ★色のみ。bladeHeartEffects は合算しない。
      addAll(card.bladeHearts);
    }

    return OwnedHearts(
      hearts: hearts,
      excludedCount: excluded.count,
      unknownCardNumbers: excluded.sorted,
    );
  }

  /// 総合ルール 8.4.2: 合計スコア。
  ///
  /// 自分のライブカード置き場のカードのスコア
  /// + 8.4.2.1 の解決領域の**自分の**エールのスコアアイコン数。
  ///
  /// ★★ ライブカード置き場が空なら [ScoreTotal.total] は null ★★
  ///   0 ではない。理由は [ScoreTotal.total] の doc を参照。
  ///
  /// ★★ 8.4.2.1 は `ownerId` で絞る ★★
  ///   「各プレイヤーは**自身の**エールのアイコン 1 つにつきスコアの合計に
  ///   1 を加算します」。8.3.12.1 ([yellDrawCount]) は絞らないので混同しないこと。
  ///
  /// ★このメソッドは勝敗を決めない (決定 D10 / D18)。
  ///   8.4.3 の比較手順・8.4.6 の勝者決定・8.4.7 の移動は行わない。
  ScoreTotal scoreTotal(GameState state, String playerId) {
    final player = state.playerOf(playerId);

    // ★8.4.2 の対象は「ライブカード置き場にカードがあるプレイヤー」だけ。
    //   空なら合計スコアが存在しない (8.4.3.1 / 8.4.3.2 が別に扱う)。
    if (player.liveStage.isEmpty) {
      return const ScoreTotal(total: null);
    }

    final excluded = _Excluded();
    var total = 0;

    // ---- ライブカード置き場のカードのスコア (8.4.2) ----
    for (final instance in player.liveStage) {
      final card = _lookup(instance, excluded);
      if (card == null) continue;
      // ★score が null になるのはライブ以外のカード。
      //   8.2.2 のブラフで置かれたカードは 8.3.4 で控え室へ送られるため
      //   8.4.2 の時点では残らないが、型としては混ざりうるので 0 として扱う。
      total += card.score ?? 0;
    }

    // ---- 自分のエールのスコアアイコン (8.4.2.1) ----
    for (final instance in state.resolution) {
      // ★ownerId で絞る。8.3.12.1 との違いはここ。
      if (instance.ownerId != playerId) continue;
      final card = _lookup(instance, excluded);
      if (card == null) continue;
      total += card.bladeHeartEffects[BladeHeartEffect.score] ?? 0;
    }

    return ScoreTotal(
      total: total,
      excludedCount: excluded.count,
      unknownCardNumbers: excluded.sorted,
    );
  }

  /// カードマスタからカードを引く。無ければ [excluded] に記録して null を返す。
  Card? _lookup(CardInstance instance, _Excluded excluded) {
    final card = cards[instance.cardNumber];
    if (card == null) {
      excluded.add(instance.cardNumber);
      return null;
    }
    return card;
  }
}

/// 集計から除外したカードの記録。
class _Excluded {
  var count = 0;
  final _numbers = <String>{};

  void add(String cardNumber) {
    count++;
    _numbers.add(cardNumber);
  }

  List<String> get sorted => _numbers.toList()..sort();
}
