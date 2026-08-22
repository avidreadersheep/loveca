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
